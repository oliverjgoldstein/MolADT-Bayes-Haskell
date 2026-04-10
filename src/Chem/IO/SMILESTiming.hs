module Chem.IO.SMILESTiming
  ( TimingStageResult(..)
  , measureSmilesCsvTiming
  , renderTimingReport
  ) where

import           Control.DeepSeq (force)
import           Control.Exception (evaluate)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import           Data.Char (isSpace, toLower)
import           Data.List (findIndex, sort)
import           Data.Word (Word64)
import           GHC.Clock (getMonotonicTimeNSec)
import           Numeric (showFFloat)

import           Chem.IO.SMILES (parseSMILES)

data TimingStageResult = TimingStageResult
  { timingStage :: String
  , timingDescription :: String
  , timingSourcePath :: FilePath
  , timingMoleculeCount :: Int
  , timingSuccessCount :: Int
  , timingFailureCount :: Int
  , timingTotalRuntimeSeconds :: Double
  , timingMoleculesPerSecond :: Double
  , timingMedianLatencyUs :: Double
  , timingP95LatencyUs :: Double
  } deriving (Eq, Show)

measureSmilesCsvTiming :: FilePath -> Maybe Int -> IO (Either String [TimingStageResult])
measureSmilesCsvTiming path mLimit = do
  csvBytes <- BS.readFile path
  let rawLines = filter (not . BSC.all isSpace) (BSC.lines csvBytes)
  case rawLines of
    [] -> pure (Left "CSV file is empty")
    (header:rows) ->
      case detectSmilesColumn (splitCsvRow header) of
        Nothing -> pure (Left "Could not detect a SMILES column in the CSV header")
        Just smilesColumn -> do
          let limitedRows = maybe rows (`take` rows) mLimit
          (smilesTexts, csvStage) <- measureCsvStringStage path smilesColumn limitedRows
          adtStage <- measureAdtParseStage path smilesTexts
          pure (Right [csvStage, adtStage])

renderTimingReport :: [TimingStageResult] -> String
renderTimingReport stages =
  unlines $
    [ "Haskell SMILES timing"
    , ""
    ]
      ++ concatMap renderStage stages
  where
    renderStage stage =
      [ "- " ++ timingStage stage ++ ": " ++ timingDescription stage
      , "  source=" ++ timingSourcePath stage
      , "  molecules=" ++ show (timingMoleculeCount stage)
          ++ " success=" ++ show (timingSuccessCount stage)
          ++ " failure=" ++ show (timingFailureCount stage)
      , "  runtime_s=" ++ showFixed 4 (timingTotalRuntimeSeconds stage)
          ++ " mol_per_s=" ++ showFixed 2 (timingMoleculesPerSecond stage)
          ++ " median_us=" ++ showFixed 1 (timingMedianLatencyUs stage)
          ++ " p95_us=" ++ showFixed 1 (timingP95LatencyUs stage)
      , ""
      ]

measureCsvStringStage :: FilePath -> Int -> [BS.ByteString] -> IO ([String], TimingStageResult)
measureCsvStringStage path smilesColumn rows = do
  startTotal <- getMonotonicTimeNSec
  (outputsRev, successCount, failureCount, latenciesRev) <- go rows [] 0 0 []
  endTotal <- getMonotonicTimeNSec
  let outputs = reverse outputsRev
      latencies = reverse latenciesRev
      elapsed = secondsBetween startTotal endTotal
      moleculeCount = length rows
  pure
    ( outputs
    , TimingStageResult
        { timingStage = "smiles_csv_string_parse"
        , timingDescription = "Materialize the SMILES column from the CSV as a plain Haskell String without chemistry parsing."
        , timingSourcePath = path
        , timingMoleculeCount = moleculeCount
        , timingSuccessCount = successCount
        , timingFailureCount = failureCount
        , timingTotalRuntimeSeconds = elapsed
        , timingMoleculesPerSecond = moleculesPerSecond moleculeCount elapsed
        , timingMedianLatencyUs = medianUs latencies
        , timingP95LatencyUs = percentileUs 95 latencies
        }
    )
  where
    go [] outputsRev successCount failureCount latenciesRev =
      pure (outputsRev, successCount, failureCount, latenciesRev)
    go (row:rest) outputsRev successCount failureCount latenciesRev = do
      startItem <- getMonotonicTimeNSec
      result <- materializeSmilesField smilesColumn row
      endItem <- getMonotonicTimeNSec
      let latencyUs = microsBetween startItem endItem
      case result of
        Right smilesText ->
          go rest (smilesText : outputsRev) (successCount + 1) failureCount (latencyUs : latenciesRev)
        Left _ ->
          go rest outputsRev successCount (failureCount + 1) (latencyUs : latenciesRev)

measureAdtParseStage :: FilePath -> [String] -> IO TimingStageResult
measureAdtParseStage path smilesTexts = do
  startTotal <- getMonotonicTimeNSec
  (successCount, failureCount, latenciesRev) <- go smilesTexts 0 0 []
  endTotal <- getMonotonicTimeNSec
  let latencies = reverse latenciesRev
      elapsed = secondsBetween startTotal endTotal
      moleculeCount = length smilesTexts
  pure TimingStageResult
    { timingStage = "smiles_adt_parse"
    , timingDescription = "Parse each SMILES String into the MolADT representation using the local Haskell parser."
    , timingSourcePath = path
    , timingMoleculeCount = moleculeCount
    , timingSuccessCount = successCount
    , timingFailureCount = failureCount
    , timingTotalRuntimeSeconds = elapsed
    , timingMoleculesPerSecond = moleculesPerSecond moleculeCount elapsed
    , timingMedianLatencyUs = medianUs latencies
    , timingP95LatencyUs = percentileUs 95 latencies
    }
  where
    go [] successCount failureCount latenciesRev =
      pure (successCount, failureCount, latenciesRev)
    go (smilesText:rest) successCount failureCount latenciesRev = do
      startItem <- getMonotonicTimeNSec
      parsed <- evaluate (force (parseSMILES smilesText))
      endItem <- getMonotonicTimeNSec
      let latencyUs = microsBetween startItem endItem
      case parsed of
        Right _ -> go rest (successCount + 1) failureCount (latencyUs : latenciesRev)
        Left _  -> go rest successCount (failureCount + 1) (latencyUs : latenciesRev)

materializeSmilesField :: Int -> BS.ByteString -> IO (Either String String)
materializeSmilesField smilesColumn row =
  case extractCsvField smilesColumn row of
    Left err -> pure (Left err)
    Right field -> do
      let smilesText = BSC.unpack (trimCsvField field)
      materialized <- evaluate (force smilesText)
      pure $
        if null materialized
          then Left "Empty SMILES field"
          else Right materialized

detectSmilesColumn :: [BS.ByteString] -> Maybe Int
detectSmilesColumn fields =
  findIndex (`elem` candidates) normalized
  where
    normalized = map (map toLower . BSC.unpack . trimCsvField) fields
    candidates = ["smiles", "smile", "molecule"]

extractCsvField :: Int -> BS.ByteString -> Either String BS.ByteString
extractCsvField smilesColumn row =
  case drop smilesColumn (splitCsvRow row) of
    field : _ -> Right field
    [] -> Left "CSV row does not contain the detected SMILES column"

splitCsvRow :: BS.ByteString -> [BS.ByteString]
splitCsvRow = BSC.split ','

trimCsvField :: BS.ByteString -> BS.ByteString
trimCsvField rawField =
  stripQuotes (BSC.dropWhileEnd isSpace (BSC.dropWhile isSpace rawField))
  where
    stripQuotes field
      | BS.length field >= 2
          && BS.head field == doubleQuote
          && BS.last field == doubleQuote =
          BS.init (BS.tail field)
      | otherwise = field

    doubleQuote = fromIntegral (fromEnum '"')

secondsBetween :: Word64 -> Word64 -> Double
secondsBetween startNs endNs = fromIntegral (endNs - startNs) / 1000000000.0

microsBetween :: Word64 -> Word64 -> Double
microsBetween startNs endNs = fromIntegral (endNs - startNs) / 1000.0

moleculesPerSecond :: Int -> Double -> Double
moleculesPerSecond moleculeCount elapsed
  | elapsed <= 0.0 = 0.0
  | otherwise = fromIntegral moleculeCount / elapsed

medianUs :: [Double] -> Double
medianUs [] = 0.0
medianUs values =
  let ordered = sort values
      count = length ordered
      middle = count `div` 2
  in if odd count
       then ordered !! middle
       else (ordered !! (middle - 1) + ordered !! middle) / 2.0

percentileUs :: Int -> [Double] -> Double
percentileUs _ [] = 0.0
percentileUs percentile values =
  let ordered = sort values
      count = length ordered
      clamped = max 0 (min 100 percentile)
      rank = ceiling ((fromIntegral clamped / 100.0) * fromIntegral count) :: Int
      index = max 0 (min (count - 1) (rank - 1))
  in ordered !! index

showFixed :: Int -> Double -> String
showFixed digits value = showFFloat (Just digits) value ""
