module Chem.IO.SDFTiming
  ( TimingStageResult(..)
  , measureSdfTiming
  , renderTimingReport
  ) where

import           Control.DeepSeq (force)
import           Control.Exception (evaluate)
import           Data.Char (isSpace, toLower)
import           Data.List (sort)
import           Data.Word (Word64)
import           GHC.Clock (getMonotonicTimeNSec)
import           Numeric (showFFloat)
import           System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import           System.FilePath ((</>), takeExtension)

import           Chem.IO.SDF (parseSDF)

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

measureSdfTiming :: FilePath -> Maybe Int -> IO (Either String [TimingStageResult])
measureSdfTiming path mLimit = do
  fileExists <- doesFileExist path
  directoryExists <- doesDirectoryExist path
  if fileExists
    then do
      (blocks, rawStage) <- measureRawSdfFileStage path mLimit
      parseStage <- measureSdfParseStage path blocks
      pure (Right [rawStage, parseStage])
    else if directoryExists
      then do
        rawResult <- measureRawSdfDirectoryStage path mLimit
        case rawResult of
          Left err -> pure (Left err)
          Right (blocks, rawStage) -> do
            parseStage <- measureSdfParseStage path blocks
            pure (Right [rawStage, parseStage])
      else pure (Left ("SDF timing source does not exist: " ++ path))

renderTimingReport :: [TimingStageResult] -> String
renderTimingReport stages =
  unlines $
    [ "Haskell SDF timing"
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

measureRawSdfFileStage :: FilePath -> Maybe Int -> IO ([String], TimingStageResult)
measureRawSdfFileStage path mLimit = do
  startTotal <- getMonotonicTimeNSec
  contents <- readFile path
  forcedBlocks <- evaluate (force (applyLimit mLimit (splitSdfBlocks contents)))
  (successCount, latenciesRev) <- go forcedBlocks 0 []
  endTotal <- getMonotonicTimeNSec
  let latencies = reverse latenciesRev
      elapsed = secondsBetween startTotal endTotal
      moleculeCount = length forcedBlocks
  pure
    ( forcedBlocks
    , TimingStageResult
        { timingStage = "raw_file_read"
        , timingDescription = "Read raw single-record SDF blocks from the source file without chemistry parsing."
        , timingSourcePath = path
        , timingMoleculeCount = moleculeCount
        , timingSuccessCount = successCount
        , timingFailureCount = 0
        , timingTotalRuntimeSeconds = elapsed
        , timingMoleculesPerSecond = moleculesPerSecond moleculeCount elapsed
        , timingMedianLatencyUs = medianUs latencies
        , timingP95LatencyUs = percentileUs 95 latencies
        }
    )
  where
    go [] successCount latenciesRev =
      pure (successCount, latenciesRev)
    go (block:rest) successCount latenciesRev = do
      startItem <- getMonotonicTimeNSec
      forcedBlock <- evaluate (force block)
      endItem <- getMonotonicTimeNSec
      let latencyUs = microsBetween startItem endItem
      if all isSpace forcedBlock
        then go rest successCount (latencyUs : latenciesRev)
        else go rest (successCount + 1) (latencyUs : latenciesRev)

measureRawSdfDirectoryStage :: FilePath -> Maybe Int -> IO (Either String ([String], TimingStageResult))
measureRawSdfDirectoryStage path mLimit = do
  entries <- listDirectory path
  let sdfPaths =
        applyLimit mLimit $
          sort
            [ path </> entry
            | entry <- entries
            , map toLower (takeExtension entry) == ".sdf"
            ]
  if null sdfPaths
    then pure (Left ("No .sdf files found under SDF timing directory: " ++ path))
    else do
      startTotal <- getMonotonicTimeNSec
      (blocksRev, successCount, latenciesRev) <- go sdfPaths [] 0 []
      endTotal <- getMonotonicTimeNSec
      let blocks = reverse blocksRev
          latencies = reverse latenciesRev
          elapsed = secondsBetween startTotal endTotal
          moleculeCount = length blocks
      pure
        (Right
          ( blocks
          , TimingStageResult
              { timingStage = "raw_file_read"
              , timingDescription = "Read raw single-record SDF files from the source directory without chemistry parsing."
              , timingSourcePath = path
              , timingMoleculeCount = moleculeCount
              , timingSuccessCount = successCount
              , timingFailureCount = 0
              , timingTotalRuntimeSeconds = elapsed
              , timingMoleculesPerSecond = moleculesPerSecond moleculeCount elapsed
              , timingMedianLatencyUs = medianUs latencies
              , timingP95LatencyUs = percentileUs 95 latencies
              }
          )
        )
  where
    go [] blocksRev successCount latenciesRev =
      pure (blocksRev, successCount, latenciesRev)
    go (sdfPath:rest) blocksRev successCount latenciesRev = do
      startItem <- getMonotonicTimeNSec
      contents <- readFile sdfPath
      forcedBlock <- evaluate (force contents)
      endItem <- getMonotonicTimeNSec
      let latencyUs = microsBetween startItem endItem
      if all isSpace forcedBlock
        then go rest (forcedBlock : blocksRev) successCount (latencyUs : latenciesRev)
        else go rest (forcedBlock : blocksRev) (successCount + 1) (latencyUs : latenciesRev)

measureSdfParseStage :: FilePath -> [String] -> IO TimingStageResult
measureSdfParseStage path blocks = do
  startTotal <- getMonotonicTimeNSec
  (successCount, failureCount, latenciesRev) <- go blocks 0 0 []
  endTotal <- getMonotonicTimeNSec
  let latencies = reverse latenciesRev
      elapsed = secondsBetween startTotal endTotal
      moleculeCount = length blocks
  pure TimingStageResult
    { timingStage = "sdf_record_parse"
    , timingDescription = "Parse each single-record SDF block into the local MolADT object using the Haskell SDF parser."
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
    go (block:rest) successCount failureCount latenciesRev = do
      startItem <- getMonotonicTimeNSec
      parsed <- evaluate (force (parseSDF block))
      endItem <- getMonotonicTimeNSec
      let latencyUs = microsBetween startItem endItem
      case parsed of
        Right _ -> go rest (successCount + 1) failureCount (latencyUs : latenciesRev)
        Left _  -> go rest successCount (failureCount + 1) (latencyUs : latenciesRev)

applyLimit :: Maybe Int -> [a] -> [a]
applyLimit Nothing xs = xs
applyLimit (Just limitCount) xs = take limitCount xs

splitSdfBlocks :: String -> [String]
splitSdfBlocks = go [] [] . lines
  where
    emit acc blocks =
      let block = unlines (reverse acc)
      in if all isSpace block then blocks else block : blocks

    go acc blocks [] = reverse (emit acc blocks)
    go acc blocks ("$$$$" : rest) = go [] (emit acc blocks) rest
    go acc blocks (line : rest) = go (line : acc) blocks rest

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
