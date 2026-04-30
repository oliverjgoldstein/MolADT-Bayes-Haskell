{-# LANGUAGE OverloadedStrings #-}

module FreeSolvInverseDesign
  ( Prediction(..)
  , Candidate(..)
  , SearchDiagnostics(..)
  , SearchResult(..)
  , SeedMoleculeName(..)
  , InverseDesignConfig(..)
  , defaultInverseDesignConfig
  , parseSeedMoleculeName
  , runFreeSolvInverseDesign
  , runInverseDesignWithPredictor
  , formatDietzMolecule
  , printSearchResult
  ) where

import           BenchmarkModel
  ( BenchmarkDataset(..)
  , BenchmarkObservation(..)
  , loadBenchmarkDataset
  )
import           Chem.Dietz
import           Chem.Molecule
import           Chem.Molecule.Coordinate (Coordinate(..), mkAngstrom, unAngstrom)
import           Chem.Validate (usedElectronsAt, validateMolecule)
import           Constants (elementAttributes, elementShells)
import           Control.Exception (evaluate)
import           Control.Monad (forM, unless)
import           Control.Monad.ST (ST, runST)
import           Data.Aeson (FromJSON(..), eitherDecode, withObject, (.:))
import qualified Data.ByteString.Lazy as BL
import           Data.Char (isSpace, toLower)
import           Data.List (foldl', intercalate, sort, sortOn)
import qualified Data.Map.Strict as M
import           Data.Maybe (fromMaybe, mapMaybe)
import           Data.Ord (Down(..))
import qualified Data.Set as S
import           Data.STRef (newSTRef, readSTRef, writeSTRef)
import           Data.Time.Clock (diffUTCTime, getCurrentTime)
import qualified Data.Vector as V
import qualified Data.Vector.Unboxed as U
import qualified Data.Vector.Unboxed.Mutable as MU
import           System.Directory (createDirectoryIfMissing, doesFileExist)
import           System.FilePath ((</>))
import           System.IO (hFlush, stdout)
import           System.Random (StdGen, mkStdGen, randomR)
import           Text.Printf (printf)
import           Text.Read (readMaybe)

freeSolvDatasetPrefix :: String
freeSolvDatasetPrefix = "freesolv_moladt_featurized"

freeSolvTargetName :: String
freeSolvTargetName = "expt"

modelName :: String
modelName = "bayes_gp_rbf_screened"

methodName :: String
methodName = "laplace"

modelDir :: FilePath
modelDir = "../MolADT-Bayes-Python/results/freesolv/run_20260417_162536"

resultsDir :: FilePath
resultsDir = "results/inverse_design/reference"

nStepsDefault :: Int
nStepsDefault = 2000

nSeedsDefault :: Int
nSeedsDefault = 5

topKDefault :: Int
topKDefault = 10

maxHeavyAtoms :: Int
maxHeavyAtoms = 12

heavyAtomGrowthLimit :: Int
heavyAtomGrowthLimit = maxHeavyAtoms + 2

randomSeedDefault :: Int
randomSeedDefault = 0

temperature :: Double
temperature = 1.0

confidenceNoiseFloor :: Double
confidenceNoiseFloor = 1.0

posteriorDrawCap :: Int
posteriorDrawCap = 128

gpFeatureCap :: Int
gpFeatureCap = 24

kernelJitter :: Double
kernelJitter = 1e-8

minimumVariance :: Double
minimumVariance = 1e-9

data Prediction = Prediction
  { predictionMean :: !Double
  , predictionSd   :: !Double
  } deriving (Eq, Show)

data Candidate = Candidate
  { candidateMolecule      :: !Molecule
  , candidatePredictedMean :: !Double
  , candidatePredictiveSd  :: !Double
  , candidateScore         :: !Double
  } deriving (Eq, Show)

data SearchDiagnostics = SearchDiagnostics
  { totalProposals            :: !Int
  , validProposals            :: !Int
  , invalidProposals          :: !Int
  , acceptedProposals         :: !Int
  , uniqueValidMoleculesSeen  :: !Int
  } deriving (Eq, Show)

emptyDiagnostics :: SearchDiagnostics
emptyDiagnostics = SearchDiagnostics 0 0 0 0 0

data SearchResult = SearchResult
  { resultTarget              :: !Double
  , resultUsedDefaultTarget   :: !Bool
  , resultSeedMolecule        :: !SeedMoleculeName
  , resultTopCandidates       :: ![Candidate]
  , resultDiagnostics         :: !SearchDiagnostics
  , resultMoleculeFilePaths   :: ![FilePath]
  , resultCoefficientSource   :: !(Maybe FilePath)
  , resultDrawSource          :: !(Maybe FilePath)
  , resultPosteriorDrawsUsed  :: !Int
  , resultPosteriorDrawsFound :: !Int
  , resultTrainMolecules      :: !Int
  , resultValidMolecules      :: !Int
  , resultTestMolecules       :: !Int
  , resultSeedCount           :: !Int
  , resultStepsPerSeed        :: !Int
  , resultElapsedSeconds      :: !(Maybe Double)
  } deriving (Eq, Show)

data SeedMoleculeName = SeedWater | SeedMethane
  deriving (Eq, Ord, Show)

data InverseDesignConfig = InverseDesignConfig
  { configTarget       :: !(Maybe Double)
  , configSeedMolecule :: !SeedMoleculeName
  , configSteps        :: !Int
  , configSeeds        :: !Int
  , configTopK         :: !Int
  , configRandomSeed   :: !Int
  , configWriteResults :: !Bool
  , configResultsDir   :: !FilePath
  } deriving (Eq, Show)

defaultInverseDesignConfig :: InverseDesignConfig
defaultInverseDesignConfig = InverseDesignConfig
  { configTarget = Nothing
  , configSeedMolecule = SeedWater
  , configSteps = nStepsDefault
  , configSeeds = nSeedsDefault
  , configTopK = topKDefault
  , configRandomSeed = randomSeedDefault
  , configWriteResults = True
  , configResultsDir = resultsDir
  }

parseSeedMoleculeName :: String -> Maybe SeedMoleculeName
parseSeedMoleculeName raw =
  case map toLower raw of
    "water"   -> Just SeedWater
    "methane" -> Just SeedMethane
    _         -> Nothing

seedMoleculeLabel :: SeedMoleculeName -> String
seedMoleculeLabel SeedWater = "water"
seedMoleculeLabel SeedMethane = "methane"

data FreeSolvMetadata = FreeSolvMetadata
  { metadataDataset     :: !String
  , metadataRepresentation :: !String
  , metadataTargetName  :: !String
  , metadataFeatureNames :: ![String]
  , metadataTrainMean   :: ![Double]
  , metadataTrainStd    :: ![Double]
  } deriving (Eq, Show)

instance FromJSON FreeSolvMetadata where
  parseJSON = withObject "FreeSolvMetadata" $ \obj ->
    FreeSolvMetadata
      <$> obj .: "dataset"
      <*> obj .: "representation"
      <*> obj .: "target_name"
      <*> obj .: "feature_names"
      <*> obj .: "train_mean"
      <*> obj .: "train_std"

data GpDraw = GpDraw
  { drawAlpha       :: !Double
  , drawSignalScale :: !Double
  , drawLengthscale :: !Double
  , drawSigma       :: !Double
  } deriving (Eq, Show)

data FreeSolvPredictor = FreeSolvPredictor
  { predictorFeatureNames      :: ![String]
  , predictorTrainMean         :: ![Double]
  , predictorTrainStd          :: ![Double]
  , predictorSelectedIndices   :: ![Int]
  , predictorTrainInputs       :: !(V.Vector (U.Vector Double))
  , predictorDrawWeights       :: ![(GpDraw, U.Vector Double)]
  , predictorMeanDraw          :: !GpDraw
  , predictorMeanCholesky      :: !(U.Vector Double)
  , predictorCoefficientSource :: !FilePath
  , predictorDrawSource        :: !FilePath
  , predictorDrawsFound        :: !Int
  , predictorTrainMolecules    :: !Int
  , predictorValidMolecules    :: !Int
  , predictorTestMolecules     :: !Int
  } deriving (Show)

runFreeSolvInverseDesign :: FilePath -> InverseDesignConfig -> IO SearchResult
runFreeSolvInverseDesign processedDir config = do
  putStrLn "Loading FreeSolv predictor and MolADT feature matrix."
  putStrLn $ "  processed data directory: " ++ processedDir
  hFlush stdout
  predictor <- loadFreeSolvPredictor processedDir
  defaultTarget <-
    if configTarget config == Nothing
      then Just <$> defaultTargetFromFreeSolv processedDir
      else pure Nothing
  let resolvedTarget = fromMaybe (fromMaybe 0.0 defaultTarget) (configTarget config)
      seedCount = max 1 (configSeeds config)
      stepsPerSeed = max 0 (configSteps config)
      proposalBudget = seedCount * stepsPerSeed
  printInverseDesignPlan predictor config resolvedTarget proposalBudget
  startTime <- getCurrentTime
  let result =
        runInverseDesignWithPredictor
          config { configTarget = Just resolvedTarget }
          (predictWithFreeSolv predictor)
  _ <-
    evaluate
      ( totalProposals (resultDiagnostics result)
          + uniqueValidMoleculesSeen (resultDiagnostics result)
          + length (resultTopCandidates result)
      )
  endTime <- getCurrentTime
  let elapsedSeconds = realToFrac (diffUTCTime endTime startTime) :: Double
      enriched =
        result
          { resultTarget = resolvedTarget
          , resultUsedDefaultTarget = configTarget config == Nothing
          , resultCoefficientSource = Just (predictorCoefficientSource predictor)
          , resultDrawSource = Just (predictorDrawSource predictor)
          , resultPosteriorDrawsUsed = length (predictorDrawWeights predictor)
          , resultPosteriorDrawsFound = predictorDrawsFound predictor
          , resultTrainMolecules = predictorTrainMolecules predictor
          , resultValidMolecules = predictorValidMolecules predictor
          , resultTestMolecules = predictorTestMolecules predictor
          , resultSeedCount = seedCount
          , resultStepsPerSeed = stepsPerSeed
          , resultElapsedSeconds = Just elapsedSeconds
          }
  putStrLn $
    "Inverse-design search complete: "
      ++ show (totalProposals (resultDiagnostics enriched))
      ++ " proposals, "
      ++ show (uniqueValidMoleculesSeen (resultDiagnostics enriched))
      ++ " unique valid molecules, "
      ++ formatSeconds elapsedSeconds ++ "."
  hFlush stdout
  if configWriteResults config
    then writeCandidateFiles (configResultsDir config) enriched
    else pure enriched

runInverseDesignWithPredictor :: InverseDesignConfig -> (Molecule -> Prediction) -> SearchResult
runInverseDesignWithPredictor config predictFn =
  let target = fromMaybe 0.0 (configTarget config)
      seedCount = max 1 (configSeeds config)
      seeds = replicate seedCount (seedMolecule (configSeedMolecule config))
      (candidateMap, diagnostics) =
        foldl'
          (\(accMap, accDiag) (seedIndex, molecule) ->
             runSeedSearch config predictFn target seedIndex molecule accMap accDiag
          )
          (M.empty, emptyDiagnostics)
          (zip [0 ..] seeds)
      finalDiagnostics =
        diagnostics { uniqueValidMoleculesSeen = M.size candidateMap }
      topCandidates =
        take (max 1 (configTopK config)) $
          sortOn (Down . candidateSortKey target) (M.elems candidateMap)
  in SearchResult
       { resultTarget = target
       , resultUsedDefaultTarget = configTarget config == Nothing
       , resultSeedMolecule = configSeedMolecule config
       , resultTopCandidates = topCandidates
       , resultDiagnostics = finalDiagnostics
       , resultMoleculeFilePaths = []
       , resultCoefficientSource = Nothing
       , resultDrawSource = Nothing
       , resultPosteriorDrawsUsed = 0
       , resultPosteriorDrawsFound = 0
       , resultTrainMolecules = 0
       , resultValidMolecules = 0
       , resultTestMolecules = 0
       , resultSeedCount = seedCount
       , resultStepsPerSeed = max 0 (configSteps config)
       , resultElapsedSeconds = Nothing
       }

runSeedSearch
  :: InverseDesignConfig
  -> (Molecule -> Prediction)
  -> Double
  -> Int
  -> Molecule
  -> M.Map String Candidate
  -> SearchDiagnostics
  -> (M.Map String Candidate, SearchDiagnostics)
runSeedSearch config predictFn target seedIndex startingMolecule initialMap initialDiagnostics =
  case validateCandidate startingMolecule of
    Left _ -> (initialMap, initialDiagnostics)
    Right validSeed ->
      let seedCandidate = scoreMolecule predictFn target validSeed
          seedKey = moleculeKey validSeed
          candidateMap = M.insertWith keepBetter seedKey seedCandidate initialMap
          gen = mkStdGen (configRandomSeed config + seedIndex)
      in loop (max 0 (configSteps config)) validSeed seedCandidate gen candidateMap initialDiagnostics
  where
    loop 0 _ _ _ candidateMap diagnostics = (candidateMap, diagnostics)
    loop remaining current currentCandidate gen candidateMap diagnostics =
      let diagnostics1 = diagnostics { totalProposals = totalProposals diagnostics + 1 }
          (proposalMaybe, gen1) = proposeMolecule current gen
      in case proposalMaybe >>= either (const Nothing) Just . validateCandidate of
           Nothing ->
             loop (remaining - 1) current currentCandidate gen1 candidateMap
               diagnostics1 { invalidProposals = invalidProposals diagnostics1 + 1 }
           Just proposal ->
             let diagnostics2 = diagnostics1 { validProposals = validProposals diagnostics1 + 1 }
                 key = moleculeKey proposal
                 (proposalCandidate, candidateMap2) =
                   case M.lookup key candidateMap of
                     Just existing -> (existing, candidateMap)
                     Nothing ->
                       let scored = scoreMolecule predictFn target proposal
                       in (scored, M.insert key scored candidateMap)
                 delta = candidateScore proposalCandidate - candidateScore currentCandidate
                 (threshold, gen2) = randomR (0.0 :: Double, 1.0 :: Double) gen1
                 accept = delta >= 0.0 || threshold < exp (delta / temperature)
                 diagnostics3 =
                   if accept
                     then diagnostics2 { acceptedProposals = acceptedProposals diagnostics2 + 1 }
                     else diagnostics2
                 nextMolecule = if accept then proposal else current
                 nextCandidate = if accept then proposalCandidate else currentCandidate
             in loop (remaining - 1) nextMolecule nextCandidate gen2 candidateMap2 diagnostics3

keepBetter :: Candidate -> Candidate -> Candidate
keepBetter left right
  | candidateScore left >= candidateScore right = left
  | otherwise = right

candidateSortKey :: Double -> Candidate -> (Double, Double, Int, Double, Int)
candidateSortKey target candidate =
  ( candidateScore candidate
  , negate (candidatePredictiveSd candidate)
  , if null (systems (candidateMolecule candidate)) then 0 else 1
  , negate (abs (candidatePredictedMean candidate - target))
  , negate (length (atoms (candidateMolecule candidate)))
  )

scoreMolecule :: (Molecule -> Prediction) -> Double -> Molecule -> Candidate
scoreMolecule predictFn target molecule =
  let Prediction meanValue sdValue = predictFn molecule
      variance = sdValue * sdValue + confidenceNoiseFloor * confidenceNoiseFloor
      targetError = meanValue - target
      baseScore = -0.5 * (targetError * targetError / variance) - 0.5 * log variance
      sizePenalty =
        if heavyAtomCount molecule > maxHeavyAtoms
          then 0.1 * fromIntegral (heavyAtomCount molecule - maxHeavyAtoms)
          else 0.0
  in Candidate molecule meanValue sdValue (baseScore - sizePenalty)

loadFreeSolvPredictor :: FilePath -> IO FreeSolvPredictor
loadFreeSolvPredictor processedDir = do
  dataset <- loadBenchmarkDataset processedDir freeSolvDatasetPrefix Nothing
  metadata <- loadMetadata (processedDir </> (freeSolvDatasetPrefix ++ "_metadata.json"))
  validateMetadata dataset metadata
  coefficientSource <- validateCoefficientSummary
  allDraws <- loadPosteriorDraws drawsPath
  let draws = thinDraws posteriorDrawCap allDraws
      trainRows = map predictorValues (trainObservations dataset)
      trainTargets = map observedTarget (trainObservations dataset)
      selectedIndices =
        screenTopCorrelationFeatures gpFeatureCap trainRows trainTargets
      selectedRows = V.fromList (map (U.fromList . selectIndices selectedIndices) trainRows)
      meanDraw = meanGpDraw draws
  drawWeights <- forM draws $ \draw -> do
    let kernel = kernelTrainMatrix selectedRows draw
    case choleskyDecompose (V.length selectedRows) kernel of
      Nothing -> fail "FreeSolv GP covariance was not positive definite for a posterior draw"
      Just chol ->
        let centeredTargets =
              U.fromList (map (\yValue -> yValue - drawAlpha draw) trainTargets)
            weights =
              solveSymmetricPositiveDefinite
                (V.length selectedRows)
                chol
                centeredTargets
        in pure (draw, weights)
  let meanKernel = kernelTrainMatrix selectedRows meanDraw
  meanCholesky <-
    case choleskyDecompose (V.length selectedRows) meanKernel of
      Nothing -> fail "FreeSolv GP covariance was not positive definite for posterior mean parameters"
      Just chol -> pure chol
  pure FreeSolvPredictor
    { predictorFeatureNames = featureNames dataset
    , predictorTrainMean = metadataTrainMean metadata
    , predictorTrainStd = metadataTrainStd metadata
    , predictorSelectedIndices = selectedIndices
    , predictorTrainInputs = selectedRows
    , predictorDrawWeights = drawWeights
    , predictorMeanDraw = meanDraw
    , predictorMeanCholesky = meanCholesky
    , predictorCoefficientSource = coefficientSource
    , predictorDrawSource = drawsPath
    , predictorDrawsFound = length allDraws
    , predictorTrainMolecules = length (trainObservations dataset)
    , predictorValidMolecules = length (validObservations dataset)
    , predictorTestMolecules = length (testObservations dataset)
    }

loadMetadata :: FilePath -> IO FreeSolvMetadata
loadMetadata path = do
  payload <- BL.readFile path
  case eitherDecode payload of
    Left err -> fail ("Could not parse FreeSolv metadata " ++ path ++ ": " ++ err)
    Right metadata -> pure metadata

validateMetadata :: BenchmarkDataset -> FreeSolvMetadata -> IO ()
validateMetadata dataset metadata = do
  unless (metadataDataset metadata == "freesolv") $
    fail "FreeSolv metadata dataset mismatch"
  unless (metadataRepresentation metadata == "moladt_featurized") $
    fail "FreeSolv metadata representation mismatch"
  unless (metadataTargetName metadata == freeSolvTargetName) $
    fail "FreeSolv metadata target mismatch"
  unless (metadataFeatureNames metadata == featureNames dataset) $
    fail "FreeSolv metadata feature names do not match the processed matrix header"
  let expectedLength = length (featureNames dataset)
  unless (length (metadataTrainMean metadata) == expectedLength) $
    fail "FreeSolv metadata train_mean length does not match feature count"
  unless (length (metadataTrainStd metadata) == expectedLength) $
    fail "FreeSolv metadata train_std length does not match feature count"

validateCoefficientSummary :: IO FilePath
validateCoefficientSummary = do
  let path = modelDir </> "details" </> "model_coefficients.csv"
  exists <- doesFileExist path
  unless exists $
    fail ("Missing committed FreeSolv model coefficient summary: " ++ path)
  rows <- readCsvRows path
  let matching =
        [ row
        | row <- rows
        , lookupCsv "dataset" row == Just "freesolv"
        , lookupCsv "representation" row == Just "moladt_featurized"
        , lookupCsv "target" row == Just freeSolvTargetName
        , lookupCsv "model" row == Just modelName
        , lookupCsv "method" row == Just methodName
        ]
      parameterNames = sort (mapMaybe (lookupCsv "parameter_name") matching)
      expected = sort ["alpha", "lengthscale", "sigma", "signal_scale"]
  unless (parameterNames == expected) $
    fail $
      "FreeSolv coefficient summary does not contain the expected GP rows for "
      ++ "freesolv/moladt_featurized/expt/bayes_gp_rbf_screened/laplace"
  pure path

drawsPath :: FilePath
drawsPath =
  modelDir
    </> "details"
    </> "stan_output"
    </> "freesolv"
    </> "moladt_featurized"
    </> modelName
    </> methodName
    </> "bayes_gp_rbf_screened-20260417162646.csv"

loadPosteriorDraws :: FilePath -> IO [GpDraw]
loadPosteriorDraws path = do
  exists <- doesFileExist path
  unless exists $
    fail ("Missing committed FreeSolv posterior draw CSV: " ++ path)
  content <- readFile path
  let nonComment = filter (not . isCommentLine) (lines content)
  case nonComment of
    [] -> fail ("FreeSolv posterior draw CSV is empty: " ++ path)
    headerLine : rowLines -> do
      let header = splitComma headerLine
          rows = map (M.fromList . zip header . splitComma) rowLines
          draws = mapMaybe parseDraw rows
      if null draws
        then fail ("No finite FreeSolv posterior draws were found in " ++ path)
        else pure draws
  where
    isCommentLine line =
      case dropWhile isSpace line of
        '#' : _ -> True
        _       -> False

    parseDraw row = do
      alpha <- lookupCsv "alpha" row >>= readMaybe
      signal <- lookupCsv "signal_scale" row >>= readMaybe
      lengthscale <- lookupCsv "lengthscale" row >>= readMaybe
      sigma <- lookupCsv "sigma" row >>= readMaybe
      if all finitePositive [signal, lengthscale, sigma] && isFinite alpha
        then Just (GpDraw alpha signal lengthscale sigma)
        else Nothing

    finitePositive value = isFinite value && value > 0.0

readCsvRows :: FilePath -> IO [M.Map String String]
readCsvRows path = do
  content <- readFile path
  case lines content of
    [] -> pure []
    headerLine : rowLines ->
      let header = splitComma headerLine
      in pure (map (M.fromList . zip header . splitComma) rowLines)

lookupCsv :: String -> M.Map String String -> Maybe String
lookupCsv key row = trim <$> M.lookup key row

splitComma :: String -> [String]
splitComma [] = [""]
splitComma text =
  case break (== ',') text of
    (left, [])       -> [trim left]
    (left, _ : rest) -> trim left : splitComma rest

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

isFinite :: Double -> Bool
isFinite value = not (isNaN value) && not (isInfinite value)

thinDraws :: Int -> [GpDraw] -> [GpDraw]
thinDraws cap draws
  | cap <= 0 = []
  | length draws <= cap = draws
  | cap == 1 = [draws !! (length draws `div` 2)]
  | otherwise =
      [ draws !! min (length draws - 1) (round (fromIntegral i * spanSize / fromIntegral (cap - 1)))
      | i <- [0 .. cap - 1]
      ]
  where
    spanSize = fromIntegral (length draws - 1) :: Double

meanGpDraw :: [GpDraw] -> GpDraw
meanGpDraw [] = GpDraw 0.0 1.0 1.0 1.0
meanGpDraw draws =
  GpDraw
    { drawAlpha = mean (map drawAlpha draws)
    , drawSignalScale = mean (map drawSignalScale draws)
    , drawLengthscale = mean (map drawLengthscale draws)
    , drawSigma = mean (map drawSigma draws)
    }

defaultTargetFromFreeSolv :: FilePath -> IO Double
defaultTargetFromFreeSolv processedDir = do
  dataset <- loadBenchmarkDataset processedDir freeSolvDatasetPrefix Nothing
  let values =
        map observedTarget (trainObservations dataset)
          ++ map observedTarget (validObservations dataset)
          ++ map observedTarget (testObservations dataset)
  if null values
    then fail "Cannot choose default target because the FreeSolv target splits are empty"
    else pure (median values)

median :: [Double] -> Double
median values =
  let sortedValues = sort values
      n = length sortedValues
      mid = n `div` 2
  in if odd n
       then sortedValues !! mid
       else (sortedValues !! (mid - 1) + sortedValues !! mid) / 2.0

predictWithFreeSolv :: FreeSolvPredictor -> Molecule -> Prediction
predictWithFreeSolv predictor molecule =
  let raw = descriptorRow (predictorFeatureNames predictor) molecule
      standardized =
        zipWith3
          (\value mu sdValue -> (value - mu) / max 1e-12 sdValue)
          raw
          (predictorTrainMean predictor)
          (predictorTrainStd predictor)
      selected = U.fromList (selectIndices (predictorSelectedIndices predictor) standardized)
      means =
        [ drawAlpha draw + dot (crossKernelVector (predictorTrainInputs predictor) draw selected) weights
        | (draw, weights) <- predictorDrawWeights predictor
        ]
      predictiveMean = mean means
      meanDraw = predictorMeanDraw predictor
      kStar = crossKernelVector (predictorTrainInputs predictor) meanDraw selected
      forwardValue =
        forwardSubstitute
          (V.length (predictorTrainInputs predictor))
          (predictorMeanCholesky predictor)
          kStar
      conditionalVariance =
        max minimumVariance $
          drawSignalScale meanDraw * drawSignalScale meanDraw
            + drawSigma meanDraw * drawSigma meanDraw
            - dot forwardValue forwardValue
      predictiveVariance =
        max minimumVariance (conditionalVariance + variance means)
  in Prediction predictiveMean (sqrt predictiveVariance)

descriptorRow :: [String] -> Molecule -> [Double]
descriptorRow names molecule =
  let featureMap = moladtFeaturizedDescriptors molecule
  in map (\name -> M.findWithDefault 0.0 name featureMap) names

moladtFeaturizedDescriptors :: Molecule -> M.Map String Double
moladtFeaturizedDescriptors molecule =
  M.unionsWith
    (+)
    [ baseMoladtDescriptors molecule
    , typedPairFeatures molecule
    , typedSystemFeatures molecule
    , typedEdgeOrderBucketFeatures molecule
    , typedRadialFeatures molecule
    , typedAngleFeatures molecule
    , typedTorsionFeatures molecule
    ]

baseMoladtDescriptors :: Molecule -> M.Map String Double
baseMoladtDescriptors molecule =
  M.fromList
    [ ("weight", moleculeWeight molecule)
    , ("polar", heteroAtomCount molecule + hydrogenBondDonorCount molecule + hydrogenBondAcceptorCount molecule)
    , ("surface", 4.0 * pi * (fromIntegral (M.size (atoms molecule)) ** (2.0 / 3.0)))
    , ("bond_order", moleculeBondOrder molecule)
    , ("donor_count", hydrogenBondDonorCount molecule)
    , ("acceptor_count", hydrogenBondAcceptorCount molecule)
    , ("heavy_atoms", fromIntegral (heavyAtomCount molecule))
    , ("halogens", fromIntegral (halogenAtomCount molecule))
    , ("atom_count_c", atomCountBySymbol C molecule)
    , ("atom_count_n", atomCountBySymbol N molecule)
    , ("atom_count_o", atomCountBySymbol O molecule)
    , ("atom_count_f", atomCountBySymbol F molecule)
    , ("atom_count_p", atomCountBySymbol P molecule)
    , ("atom_count_s", atomCountBySymbol S molecule)
    , ("atom_count_cl", atomCountBySymbol Cl molecule)
    , ("atom_count_br", atomCountBySymbol Br molecule)
    , ("atom_count_i", atomCountBySymbol I molecule)
    , ("atom_count_h", atomCountBySymbol H molecule)
    , ("formal_charge_sum", fromIntegral (sum (map formalCharge (M.elems (atoms molecule)))))
    , ("abs_formal_charge_sum", fromIntegral (sum (map (abs . formalCharge) (M.elems (atoms molecule)))))
    , ("positive_charge_count", fromIntegral (length (filter ((> 0) . formalCharge) (M.elems (atoms molecule)))))
    , ("negative_charge_count", fromIntegral (length (filter ((< 0) . formalCharge) (M.elems (atoms molecule)))))
    , ("bonding_system_count", fromIntegral (length (systems molecule)))
    , ("multicentre_system_count", fromIntegral (length [() | (_, system) <- systems molecule, S.size (memberEdges system) > 1]))
    , ("pi_ring_system_count", aromaticRingCount molecule)
    , ("zero_electron_system_count", fromIntegral (length [() | (_, system) <- systems molecule, getNN (sharedElectrons system) == 0]))
    , ("sigma_edge_count", fromIntegral (S.size (localBonds molecule)))
    , ("effective_bond_order_sum", sum edgeOrders)
    , ("effective_bond_order_mean", if null edgeOrders then 0.0 else mean edgeOrders)
    , ("effective_bond_order_max", if null edgeOrders then 0.0 else maximum edgeOrders)
    , ("aromatic_rings", aromaticRingCount molecule)
    , ("aromatic_atom_count", fromIntegral (S.size aromaticAtoms))
    , ("aromatic_atom_fraction", if heavy == 0 then 0.0 else fromIntegral (S.size aromaticAtoms) / fromIntegral heavy)
    , ("ring_edge_fraction", ringEdgeFraction molecule)
    , ("rotatable_bonds", rotatableBondCount molecule)
    , ("heavy_atom_degree_mean", if null heavyDegrees then 0.0 else mean heavyDegrees)
    , ("heavy_atom_degree_max", if null heavyDegrees then 0.0 else maximum heavyDegrees)
    ]
  where
    uniqueEdges = allEdges molecule
    edgeOrders = map (effectiveOrder molecule) (S.toList uniqueEdges)
    aromaticAtoms =
      S.unions
        [ memberAtoms system
        | (_, system) <- systems molecule
        , tag system == Just "pi_ring"
        ]
    heavy = heavyAtomCount molecule
    heavyDegrees =
      [ fromIntegral (length [n | n <- neighborsSigma molecule aid, symbolOf (atoms molecule M.! n) /= H])
      | (aid, atom) <- M.toAscList (atoms molecule)
      , symbolOf atom /= H
      ]

typedPairFeatures :: Molecule -> M.Map String Double
typedPairFeatures molecule =
  foldl' addPair initial pairs
  where
    initial =
      M.fromList
        [ (pairFeatureName prefix left right, 0.0)
        | prefix <- ["pair_count", "pair_interaction"]
        , (left, right) <- orderedSymbolPairs
        ]
    orderedAtoms = M.toAscList (atoms molecule)
    pairs =
      [ (atomA, atomB)
      | (index, (_, atomA)) <- zip [0 :: Int ..] orderedAtoms
      , (_, atomB) <- drop (index + 1) orderedAtoms
      ]
    addPair acc (atomA, atomB) =
      let (leftSymbol, rightSymbol) = orderedSymbols (symbolOf atomA) (symbolOf atomB)
          countName = pairFeatureName "pair_count" leftSymbol rightSymbol
          interactionName = pairFeatureName "pair_interaction" leftSymbol rightSymbol
          distanceValue = max 1e-6 (distance atomA atomB)
          interaction =
            fromIntegral (atomicNumber (attributes atomA) * atomicNumber (attributes atomB))
              / distanceValue
      in M.insertWith (+) countName 1.0 $
           M.insertWith (+) interactionName interaction acc

typedSystemFeatures :: Molecule -> M.Map String Double
typedSystemFeatures molecule =
  M.fromList
    [ ("system_member_atoms_mean", if null atomSizes then 0.0 else mean atomSizes)
    , ("system_member_atoms_max", if null atomSizes then 0.0 else maximum atomSizes)
    , ("system_member_edges_mean", if null edgeSizes then 0.0 else mean edgeSizes)
    , ("system_member_edges_max", if null edgeSizes then 0.0 else maximum edgeSizes)
    , ("system_shared_electrons_sum", sum shared)
    , ("system_shared_electrons_mean", if null shared then 0.0 else mean shared)
    , ("system_shared_electrons_max", if null shared then 0.0 else maximum shared)
    ]
  where
    atomSizes = [fromIntegral (S.size (memberAtoms system)) | (_, system) <- systems molecule]
    edgeSizes = [fromIntegral (S.size (memberEdges system)) | (_, system) <- systems molecule]
    shared = [fromIntegral (getNN (sharedElectrons system)) | (_, system) <- systems molecule]

typedEdgeOrderBucketFeatures :: Molecule -> M.Map String Double
typedEdgeOrderBucketFeatures molecule =
  foldl' addOrder initial (S.toList (allEdges molecule))
  where
    initial =
      M.fromList
        [ ("edge_order_sigma_like_count", 0.0)
        , ("edge_order_delocalized_count", 0.0)
        , ("edge_order_double_like_count", 0.0)
        , ("edge_order_triple_plus_count", 0.0)
        ]
    addOrder acc edge =
      let orderValue = effectiveOrder molecule edge
          bucket
            | orderValue <= 1.10 = "edge_order_sigma_like_count"
            | orderValue < 1.80 = "edge_order_delocalized_count"
            | orderValue < 2.40 = "edge_order_double_like_count"
            | otherwise = "edge_order_triple_plus_count"
      in M.insertWith (+) bucket 1.0 acc

typedRadialFeatures :: Molecule -> M.Map String Double
typedRadialFeatures molecule =
  foldl' addCenter initial radialCenters
  where
    initial =
      M.fromList
        [ (radialFeatureName prefix center, 0.0)
        | prefix <- ["aprdf_all", "aprdf_edge_order", "aprdf_system_edge"]
        , center <- radialCenters
        ]
    orderedAtoms = M.toAscList (atoms molecule)
    atomPairs =
      [ (atomA, atomB)
      | (index, (_, atomA)) <- zip [0 :: Int ..] orderedAtoms
      , (_, atomB) <- drop (index + 1) orderedAtoms
      ]
    systemEdges = S.unions [memberEdges system | (_, system) <- systems molecule]
    addCenter acc center =
      let atomContribution =
            sum
              [ fromIntegral (atomicNumber (attributes atomA) * atomicNumber (attributes atomB))
                  * radialChannel center (distance atomA atomB)
              | (atomA, atomB) <- atomPairs
              ]
          edgeContribution =
            sum
              [ effectiveOrder molecule edge
                  * radialChannel center (edgeDistance molecule edge)
              | edge <- S.toList (allEdges molecule)
              ]
          systemContribution =
            sum
              [ effectiveOrder molecule edge
                  * radialChannel center (edgeDistance molecule edge)
              | edge <- S.toList systemEdges
              ]
      in M.insert (radialFeatureName "aprdf_all" center) atomContribution $
           M.insert (radialFeatureName "aprdf_edge_order" center) edgeContribution $
             M.insert (radialFeatureName "aprdf_system_edge" center) systemContribution acc

typedAngleFeatures :: Molecule -> M.Map String Double
typedAngleFeatures molecule =
  foldl' addCenterAngles initial (M.toAscList adjacency)
  where
    initial =
      M.fromList
        [ (angularFeatureName prefix center, 0.0)
        | prefix <- ["bond_angle_all", "bond_angle_distance_weighted", "bond_angle_order_weighted"]
        , center <- angleCenters
        ]
    adjacency = adjacencyFromEdges (allEdges molecule)
    addCenterAngles acc (centerId, neighbors)
      | length neighbors < 2 = acc
      | otherwise = foldl' (addAngle centerId) acc (neighborPairs neighbors)
    addAngle centerId acc (leftId, rightId) =
      let centerAtom = atoms molecule M.! centerId
          leftAtom = atoms molecule M.! leftId
          rightAtom = atoms molecule M.! rightId
          leftVector = vectorFromTo centerAtom leftAtom
          rightVector = vectorFromTo centerAtom rightAtom
          leftDistance = vectorNorm leftVector
          rightDistance = vectorNorm rightVector
      in if leftDistance <= 1e-6 || rightDistance <= 1e-6
           then acc
           else
             let cosineValue =
                   clamp (-1.0) 1.0 (dot3 leftVector rightVector / (leftDistance * rightDistance))
                 angleDegrees = acos cosineValue * 180.0 / pi
                 distanceWeight =
                   fromIntegral (atomicNumber (attributes leftAtom) * atomicNumber (attributes rightAtom))
                     / max 1e-6 (leftDistance * rightDistance)
                 orderWeight =
                   0.5
                     * ( effectiveOrder molecule (mkEdge centerId leftId)
                         + effectiveOrder molecule (mkEdge centerId rightId)
                       )
             in foldl'
                  (\inner center ->
                     let channel = angleChannel center angleDegrees
                     in M.insertWith (+) (angularFeatureName "bond_angle_all" center) channel $
                          M.insertWith (+) (angularFeatureName "bond_angle_distance_weighted" center) (distanceWeight * channel) $
                            M.insertWith (+) (angularFeatureName "bond_angle_order_weighted" center) (orderWeight * channel) inner
                  )
                  acc
                  angleCenters

typedTorsionFeatures :: Molecule -> M.Map String Double
typedTorsionFeatures molecule =
  foldl' addEdgeTorsions initial (S.toList (allEdges molecule))
  where
    initial =
      M.fromList
        [ (angularFeatureName prefix center, 0.0)
        | prefix <- ["torsion_all", "torsion_distance_weighted", "torsion_order_weighted"]
        , center <- torsionCenters
        ]
    adjacency = adjacencyFromEdges (allEdges molecule)
    addEdgeTorsions acc edge@(Edge leftId rightId) =
      let leftNeighbors = filter (/= rightId) (M.findWithDefault [] leftId adjacency)
          rightNeighbors = filter (/= leftId) (M.findWithDefault [] rightId adjacency)
          centralOrder = effectiveOrder molecule edge
      in foldl'
           (addTerminalTorsions edge centralOrder)
           acc
           [ (terminalLeft, terminalRight)
           | terminalLeft <- leftNeighbors
           , terminalRight <- rightNeighbors
           , terminalLeft /= terminalRight
           ]
    addTerminalTorsions (Edge leftId rightId) centralOrder acc (terminalLeft, terminalRight) =
      let atomA = atoms molecule M.! terminalLeft
          atomB = atoms molecule M.! leftId
          atomC = atoms molecule M.! rightId
          atomD = atoms molecule M.! terminalRight
          leftDistance = distance atomA atomB
          rightDistance = distance atomD atomC
      in if leftDistance <= 1e-6 || rightDistance <= 1e-6
           then acc
           else
             let dihedral = absoluteDihedralDegrees atomA atomB atomC atomD
                 distanceWeight =
                   fromIntegral (atomicNumber (attributes atomA) * atomicNumber (attributes atomD))
                     / max 1e-6 (leftDistance * rightDistance)
             in foldl'
                  (\inner center ->
                     let channel = torsionChannel center dihedral
                     in M.insertWith (+) (angularFeatureName "torsion_all" center) channel $
                          M.insertWith (+) (angularFeatureName "torsion_distance_weighted" center) (distanceWeight * channel) $
                            M.insertWith (+) (angularFeatureName "torsion_order_weighted" center) (centralOrder * channel) inner
                  )
                  acc
                  torsionCenters

proposeMolecule :: Molecule -> StdGen -> (Maybe Molecule, StdGen)
proposeMolecule molecule gen =
  let (moveName, gen1) = weightedChoice moveWeights gen
  in case moveName of
       "add_terminal_atom" -> addTerminalAtom molecule gen1
       "add_sigma_edge" -> addSigmaEdge molecule gen1
       "mutate_atom" -> mutateAtom molecule gen1
       "remove_terminal_atom" -> removeTerminalAtom molecule gen1
       "add_pi_ring_system" -> addPiRingSystem molecule gen1
       _ -> (Nothing, gen1)

moveWeights :: [(String, Double)]
moveWeights =
  [ ("add_terminal_atom", 0.40)
  , ("add_sigma_edge", 0.25)
  , ("mutate_atom", 0.20)
  , ("remove_terminal_atom", 0.10)
  , ("add_pi_ring_system", 0.05)
  ]

addTerminalAtom :: Molecule -> StdGen -> (Maybe Molecule, StdGen)
addTerminalAtom molecule gen =
  case parents of
    [] -> (Nothing, gen)
    _ ->
      let (parentId, gen1) = chooseOne parents gen
          allowedSymbols =
            if heavyAtomCount molecule >= heavyAtomGrowthLimit
              then [H]
              else [C, C, O, N, F, Cl]
          (newSymbol, gen2) = chooseOne allowedSymbols gen1
          parentAtom = atoms molecule M.! parentId
          moleculeWithRoom = makeRoomAt parentId molecule
          newId = freshAtomId moleculeWithRoom
          newAtomValue = newAtom newId newSymbol parentAtom
          proposal =
            moleculeWithRoom
              { atoms = M.insert newId newAtomValue (atoms moleculeWithRoom)
              , localBonds = S.insert (mkEdge parentId newId) (localBonds moleculeWithRoom)
              }
      in (tryValidCandidate proposal, gen2)
  where
    parents =
      [ atomId
      | (atomId, atom) <- M.toAscList (atoms molecule)
      , symbolOf atom /= H
      , availableValence molecule atomId >= 1.0 - 1e-9
          || not (null (terminalHydrogensAttachedTo molecule atomId))
      ]

addSigmaEdge :: Molecule -> StdGen -> (Maybe Molecule, StdGen)
addSigmaEdge molecule gen =
  case candidates of
    [] -> (Nothing, gen)
    _ ->
      let preferred = if null ringCandidates then candidates else ringCandidates
          (pair, gen1) = chooseOne preferred gen
          (left, right) = pair
          proposal0 = makeRoomAt right (makeRoomAt left molecule)
          proposal =
            proposal0 { localBonds = S.insert (mkEdge left right) (localBonds proposal0) }
      in (tryValidCandidate proposal, gen1)
  where
    heavyIds =
      [ atomId
      | (atomId, atom) <- M.toAscList (atoms molecule)
      , symbolOf atom /= H
      , availableValence molecule atomId >= 1.0 - 1e-9
          || not (null (terminalHydrogensAttachedTo molecule atomId))
      ]
    candidates =
      [ (left, right)
      | (index, left) <- zip [0 :: Int ..] heavyIds
      , right <- drop (index + 1) heavyIds
      , let edge = mkEdge left right
      , not (edge `S.member` localBonds molecule)
      , not (hasLocalizedSingletonSystem molecule edge)
      , let pathLength = shortestSigmaPathLength molecule left right
      , maybe False (\value -> value >= 4 && value <= 6) pathLength
      ]
    ringCandidates =
      [ pair
      | pair@(left, right) <- candidates
      , shortestSigmaPathLength molecule left right == Just 5
      ]

mutateAtom :: Molecule -> StdGen -> (Maybe Molecule, StdGen)
mutateAtom molecule gen =
  case candidates of
    [] -> (Nothing, gen)
    _ ->
      let (atomId, gen1) = chooseOne candidates gen
          atom = atoms molecule M.! atomId
          alternatives = filter (/= symbolOf atom) [C, N, O, F, Cl]
          (newSymbol, gen2) = chooseOne alternatives gen1
          mutatedAtom =
            atom
              { attributes = elementAttributes newSymbol
              , shells = elementShells newSymbol
              }
          proposal = molecule { atoms = M.insert atomId mutatedAtom (atoms molecule) }
      in (tryValidCandidate proposal, gen2)
  where
    candidates =
      [ atomId
      | (atomId, atom) <- M.toAscList (atoms molecule)
      , symbolOf atom /= H
      ]

removeTerminalAtom :: Molecule -> StdGen -> (Maybe Molecule, StdGen)
removeTerminalAtom molecule gen =
  case removableTerminalAtoms molecule of
    [] -> (Nothing, gen)
    candidates ->
      let (atomId, gen1) = chooseOne candidates gen
      in (tryValidCandidate (removeAtom atomId molecule), gen1)

addPiRingSystem :: Molecule -> StdGen -> (Maybe Molecule, StdGen)
addPiRingSystem molecule gen =
  case rings of
    [] -> (Nothing, gen)
    _ ->
      let (ring, gen1) = chooseOne rings gen
          nextSystemId =
            SystemId (1 + maximum (0 : [value | (SystemId value, _) <- systems molecule]))
          system = mkBondingSystem (NonNegative 6) ring (Just "pi_ring")
          proposal = molecule { systems = systems molecule ++ [(nextSystemId, system)] }
      in (tryValidCandidate proposal, gen1)
  where
    rings =
      [ ring
      | ring <- detectCarbonSixRings molecule
      , not (hasPiSystem molecule ring)
      ]

tryValidCandidate :: Molecule -> Maybe Molecule
tryValidCandidate molecule =
  case validateCandidate (canonicalizeAtomIds (completeTerminalHydrogens molecule)) of
    Left _ -> Nothing
    Right valid -> Just valid

validateCandidate :: Molecule -> Either String Molecule
validateCandidate molecule = do
  valid <- validateMolecule molecule
  unlessEither (isConnected valid) "Molecule is disconnected"
  ensureSupportedSymbols valid
  ensureNoHydrogenHydrogenLocalBonds valid
  ensureConservativeGeneratorValence valid
  ensureSoundBondingSystems valid
  pure valid

ensureSupportedSymbols :: Molecule -> Either String ()
ensureSupportedSymbols molecule =
  case unsupported of
    [] -> Right ()
    xs -> Left ("Unsupported generated elements: " ++ intercalate ", " (sort xs))
  where
    unsupported =
      [ show (symbolOf atom)
      | atom <- M.elems (atoms molecule)
      , not (symbolOf atom `elem` supportedSymbols)
      ]

ensureNoHydrogenHydrogenLocalBonds :: Molecule -> Either String ()
ensureNoHydrogenHydrogenLocalBonds molecule =
  case badEdges of
    [] -> Right ()
    _  -> Left "Generated molecules may not contain H-H local bonds"
  where
    badEdges =
      [ edge
      | edge@(Edge left right) <- S.toList (localBonds molecule)
      , symbolOf (atoms molecule M.! left) == H
      , symbolOf (atoms molecule M.! right) == H
      ]

ensureConservativeGeneratorValence :: Molecule -> Either String ()
ensureConservativeGeneratorValence molecule =
  case badAtoms of
    [] -> Right ()
    (atomId, _) : _ -> Left ("Atom " ++ showAtomId atomId ++ " exceeds generator valence cap")
  where
    badAtoms =
      [ (atomId, used)
      | (atomId, atom) <- M.toAscList (atoms molecule)
      , let used = usedElectronsAt molecule atomId
      , used > growthMaxValence (symbolOf atom) + 1e-9
      ]

ensureSoundBondingSystems :: Molecule -> Either String ()
ensureSoundBondingSystems molecule =
  foldl' step (Right S.empty) (systems molecule) >> Right ()
  where
    step (Left err) _ = Left err
    step (Right seen) (_, system) =
      let signature =
            ( getNN (sharedElectrons system)
            , sort [(showAtomId left, showAtomId right) | Edge left right <- S.toList (memberEdges system)]
            , tag system
            )
      in if signature `S.member` seen
           then Left "Duplicate Dietz bonding system"
           else if tag system == Just "pi_ring" && not (isValidPiRing molecule system)
                  then Left "pi_ring bonding system is not a simple carbon six-ring"
                  else Right (S.insert signature seen)

unlessEither :: Bool -> String -> Either String ()
unlessEither True _ = Right ()
unlessEither False err = Left err

seedMolecule :: SeedMoleculeName -> Molecule
seedMolecule SeedWater =
  Molecule
    { atoms =
        M.fromList
          [ (AtomId 1, seedAtom 1 O 0.00 0.00 0.00)
          , (AtomId 2, seedAtom 2 H 0.96 0.00 0.00)
          , (AtomId 3, seedAtom 3 H (-0.32) 0.90 0.00)
          ]
    , localBonds = S.fromList [mkEdge (AtomId 1) (AtomId 2), mkEdge (AtomId 1) (AtomId 3)]
    , systems = []
    , smilesStereochemistry = emptySmilesStereochemistry
    }
seedMolecule SeedMethane =
  Molecule
    { atoms =
        M.fromList
          [ (AtomId 1, seedAtom 1 C 0.00 0.00 0.00)
          , (AtomId 2, seedAtom 2 H 1.09 0.00 0.00)
          , (AtomId 3, seedAtom 3 H (-1.09) 0.00 0.00)
          , (AtomId 4, seedAtom 4 H 0.00 1.09 0.00)
          , (AtomId 5, seedAtom 5 H 0.00 (-1.09) 0.00)
          ]
    , localBonds =
        S.fromList
          [ mkEdge (AtomId 1) (AtomId 2)
          , mkEdge (AtomId 1) (AtomId 3)
          , mkEdge (AtomId 1) (AtomId 4)
          , mkEdge (AtomId 1) (AtomId 5)
          ]
    , systems = []
    , smilesStereochemistry = emptySmilesStereochemistry
    }

seedAtom :: Integer -> AtomicSymbol -> Double -> Double -> Double -> Atom
seedAtom atomNumber atomSymbol xValue yValue zValue =
  Atom
    { atomID = AtomId atomNumber
    , attributes = elementAttributes atomSymbol
    , coordinate =
        Coordinate
          (mkAngstrom xValue)
          (mkAngstrom yValue)
          (mkAngstrom zValue)
    , shells = elementShells atomSymbol
    , formalCharge = 0
    }

newAtom :: AtomId -> AtomicSymbol -> Atom -> Atom
newAtom atomId atomSymbol parentAtom =
  let n = fromIntegral (atomIdInteger atomId)
      angle = fromIntegral (atomIdInteger atomId `mod` 6) * pi / 3.0
      radius = 1.2 + 0.05 * fromIntegral (atomIdInteger atomId `mod` 5)
      Coordinate px py pz = coordinate parentAtom
  in Atom
       { atomID = atomId
       , attributes = elementAttributes atomSymbol
       , coordinate =
           Coordinate
             (mkAngstrom (unAngstrom px + radius * cos angle))
             (mkAngstrom (unAngstrom py + radius * sin angle))
             (mkAngstrom (unAngstrom pz + 0.1 * fromIntegral (atomIdInteger atomId `mod` 3) + 0.001 * n))
       , shells = elementShells atomSymbol
       , formalCharge = 0
       }

completeTerminalHydrogens :: Molecule -> Molecule
completeTerminalHydrogens molecule =
  let withoutHydrogens =
        foldl' (flip removeAtom) molecule removableHydrogens
      startingId = 1 + maximum (0 : map atomIdInteger (M.keys (atoms withoutHydrogens)))
      (_, completed) =
        foldl'
          addHydrogensForAtom
          (startingId, withoutHydrogens)
          (M.toAscList (atoms withoutHydrogens))
  in completed
  where
    systemAtoms = S.unions [memberAtoms system | (_, system) <- systems molecule]
    removableHydrogens =
      [ atomId
      | (atomId, atom) <- M.toAscList (atoms molecule)
      , symbolOf atom == H
      , formalCharge atom == 0
      , atomId `S.notMember` systemAtoms
      , length (neighborsSigma molecule atomId) == 1
      ]

    addHydrogensForAtom (nextIdValue, current) (atomId, atom)
      | symbolOf atom == H = (nextIdValue, current)
      | otherwise =
          let available = growthMaxValence (symbolOf atom) - usedElectronsAt current atomId
              hydrogenCount = max 0 (floor (available + 1e-9))
          in foldl'
               (\(nextValue, acc) _ ->
                  let hydrogenId = AtomId nextValue
                      hydrogen = newAtom hydrogenId H atom
                  in ( nextValue + 1
                     , acc
                         { atoms = M.insert hydrogenId hydrogen (atoms acc)
                         , localBonds = S.insert (mkEdge atomId hydrogenId) (localBonds acc)
                         }
                     )
               )
               (nextIdValue, current)
               [1 .. hydrogenCount]

canonicalizeAtomIds :: Molecule -> Molecule
canonicalizeAtomIds molecule =
  if oldIds == newIds
    then molecule
    else
      molecule
        { atoms =
            M.fromList
              [ (newId, atom { atomID = newId })
              | (oldId, newId) <- M.toAscList idMap
              , let atom = atoms molecule M.! oldId
              ]
        , localBonds =
            S.fromList
              [ mkEdge (translate left) (translate right)
              | Edge left right <- S.toList (localBonds molecule)
              ]
        , systems =
            [ ( SystemId index
              , mkBondingSystem
                  (sharedElectrons system)
                  (S.fromList [mkEdge (translate left) (translate right) | Edge left right <- S.toList (memberEdges system)])
                  (tag system)
              )
            | (index, (_, system)) <- zip [1 ..] (systems molecule)
            ]
        }
  where
    oldIds = M.keys (atoms molecule)
    newIds = map AtomId [1 .. fromIntegral (length oldIds)]
    idMap = M.fromList (zip oldIds newIds)
    translate atomId = idMap M.! atomId

removeAtom :: AtomId -> Molecule -> Molecule
removeAtom atomId molecule =
  molecule
    { atoms = M.delete atomId (atoms molecule)
    , localBonds = S.filter (not . edgeTouches atomId) (localBonds molecule)
    , systems =
        [ (systemId, system)
        | (systemId, system) <- systems molecule
        , atomId `S.notMember` memberAtoms system
        , all (not . edgeTouches atomId) (S.toList (memberEdges system))
        ]
    }

makeRoomAt :: AtomId -> Molecule -> Molecule
makeRoomAt atomId molecule
  | availableValence molecule atomId >= 1.0 - 1e-9 = molecule
  | otherwise =
      case terminalHydrogensAttachedTo molecule atomId of
        [] -> molecule
        hydrogenId : _ -> removeAtom hydrogenId molecule

terminalHydrogensAttachedTo :: Molecule -> AtomId -> [AtomId]
terminalHydrogensAttachedTo molecule atomId =
  [ neighbor
  | neighbor <- sort (neighborsSigma molecule atomId)
  , let atom = atoms molecule M.! neighbor
  , symbolOf atom == H
  , neighbor `S.notMember` systemAtoms
  , length (neighborsSigma molecule neighbor) == 1
  ]
  where
    systemAtoms = S.unions [memberAtoms system | (_, system) <- systems molecule]

removableTerminalAtoms :: Molecule -> [AtomId]
removableTerminalAtoms molecule =
  [ atomId
  | (atomId, atom) <- M.toAscList (atoms molecule)
  , M.size (atoms molecule) > 1
  , atomId `S.notMember` protectedAtoms
  , symbolOf atom /= H
  , length (neighborsSigma molecule atomId) == 1
  ]
  where
    protectedAtoms =
      S.unions
        [ memberAtoms system
        | (_, system) <- systems molecule
        , S.size (memberEdges system) > 1
        ]

detectCarbonSixRings :: Molecule -> [S.Set Edge]
detectCarbonSixRings molecule =
  sortOn ringSortKey (S.toList discovered)
  where
    adjacency = adjacencyFromEdges (localBonds molecule)
    starts = M.keys adjacency
    discovered =
      foldl'
        (\acc start -> search acc [start] start)
        S.empty
        starts

    search acc path current
      | length path == 6 =
          if head path `elem` M.findWithDefault [] current adjacency
             && head path == minimum path
             && all (\atomId -> symbolOf (atoms molecule M.! atomId) == C) path
            then S.insert (ringFromPath path) acc
            else acc
      | otherwise =
          foldl'
            (\inner neighbor ->
               if neighbor `elem` path
                 then inner
                 else search inner (path ++ [neighbor]) neighbor
            )
            acc
            (M.findWithDefault [] current adjacency)

    ringFromPath path =
      S.fromList
        [ mkEdge (path !! index) (if index < 5 then path !! (index + 1) else head path)
        | index <- [0 .. 5]
        ]

hasPiSystem :: Molecule -> S.Set Edge -> Bool
hasPiSystem molecule ring =
  any
    (\(_, system) ->
       memberEdges system == ring
         && getNN (sharedElectrons system) == 6
         && S.size (memberEdges system) == 6
    )
    (systems molecule)

isValidPiRing :: Molecule -> BondingSystem -> Bool
isValidPiRing molecule system =
  getNN (sharedElectrons system) == 6
    && S.size (memberEdges system) == 6
    && S.size ringAtoms == 6
    && all (\atomId -> M.member atomId (atoms molecule) && symbolOf (atoms molecule M.! atomId) == C) (S.toList ringAtoms)
    && all (`S.member` localBonds molecule) (S.toList (memberEdges system))
    && all (== 2) (M.elems ringDegree)
  where
    ringAtoms = S.unions [S.fromList [left, right] | Edge left right <- S.toList (memberEdges system)]
    ringDegree =
      foldl'
        (\acc (Edge left right) -> M.insertWith (+) left 1 (M.insertWith (+) right 1 acc))
        (M.fromList [(atomId, 0 :: Int) | atomId <- S.toList ringAtoms])
        (S.toList (memberEdges system))

shortestSigmaPathLength :: Molecule -> AtomId -> AtomId -> Maybe Int
shortestSigmaPathLength molecule start goal =
  breadthFirst S.empty [(start, 0)]
  where
    breadthFirst _ [] = Nothing
    breadthFirst seen ((current, distanceValue) : rest)
      | current == goal = Just distanceValue
      | current `S.member` seen = breadthFirst seen rest
      | otherwise =
          let nextSeen = S.insert current seen
              next =
                [ (neighbor, distanceValue + 1)
                | neighbor <- neighborsSigma molecule current
                , neighbor `S.notMember` nextSeen
                ]
          in breadthFirst nextSeen (rest ++ next)

hasLocalizedSingletonSystem :: Molecule -> Edge -> Bool
hasLocalizedSingletonSystem molecule edge =
  any
    (\(_, system) ->
       S.size (memberEdges system) == 1
         && getNN (sharedElectrons system) == 2
         && edge `S.member` memberEdges system
    )
    (systems molecule)

isConnected :: Molecule -> Bool
isConnected molecule
  | M.size (atoms molecule) <= 1 = True
  | otherwise = seen == atomSet
  where
    atomSet = S.fromList (M.keys (atoms molecule))
    adjacency = adjacencyFromEdges (allEdges molecule)
    start = minimum (M.keys (atoms molecule))
    seen = walk S.empty [start] adjacency

walk :: S.Set AtomId -> [AtomId] -> M.Map AtomId [AtomId] -> S.Set AtomId
walk seen [] _ = seen
walk seen (current : rest) adjacency
  | current `S.member` seen = walk seen rest adjacency
  | otherwise =
      walk
        (S.insert current seen)
        (M.findWithDefault [] current adjacency ++ rest)
        adjacency

allEdges :: Molecule -> S.Set Edge
allEdges molecule =
  S.unions (localBonds molecule : [memberEdges system | (_, system) <- systems molecule])

adjacencyFromEdges :: S.Set Edge -> M.Map AtomId [AtomId]
adjacencyFromEdges edgeSet =
  M.map sort $
    foldl'
      (\acc (Edge left right) ->
         M.insertWith (++) left [right] $
           M.insertWith (++) right [left] acc
      )
      M.empty
      (S.toList edgeSet)

writeCandidateFiles :: FilePath -> SearchResult -> IO SearchResult
writeCandidateFiles outputDir result = do
  createDirectoryIfMissing True outputDir
  paths <-
    forM (zip [1 :: Int ..] (take topKDefault (resultTopCandidates result))) $ \(rank, candidate) -> do
      let path = outputDir </> printf "top_%02d_molecule.hs" rank
      writeFile path (candidateHaskellSource rank candidate result)
      pure path
  pure result { resultMoleculeFilePaths = paths }

candidateHaskellSource :: Int -> Candidate -> SearchResult -> String
candidateHaskellSource rank candidate result =
  unlines
    [ "import Chem.Dietz"
    , "import Chem.Molecule"
    , "import Chem.Molecule.Coordinate"
    , "import Chem.Validate"
    , "import Constants"
    , "import qualified Data.Map.Strict as M"
    , "import qualified Data.Set as S"
    , ""
    , "rank :: Int"
    , "rank = " ++ show rank
    , ""
    , "targetFreeSolv :: Double"
    , "targetFreeSolv = " ++ show (resultTarget result)
    , ""
    , "seedMolecule :: String"
    , "seedMolecule = " ++ show (seedMoleculeLabel (resultSeedMolecule result))
    , ""
    , "predictedFreeSolv :: Double"
    , "predictedFreeSolv = " ++ show (candidatePredictedMean candidate)
    , ""
    , "predictiveSd :: Double"
    , "predictiveSd = " ++ show (candidatePredictiveSd candidate)
    , ""
    , "targetError :: Double"
    , "targetError = " ++ show (abs (candidatePredictedMean candidate - resultTarget result))
    , ""
    , "score :: Double"
    , "score = " ++ show (candidateScore candidate)
    , ""
    , "formula :: String"
    , "formula = " ++ show (molecularFormula (candidateMolecule candidate))
    , ""
    , "molecule :: Molecule"
    , "molecule = either error id (validateMolecule (Molecule"
    , "  { atoms = M.fromList"
    , "      [ " ++ intercalate "\n      , " (atomSourceLines (candidateMolecule candidate))
    , "      ]"
    , "  , localBonds = S.fromList"
    , "      [ " ++ intercalate "\n      , " (edgeSourceLines (localBonds (candidateMolecule candidate)))
    , "      ]"
    , "  , systems ="
    , "      [ " ++ intercalate "\n      , " (systemSourceLines (candidateMolecule candidate))
    , "      ]"
    , "  , smilesStereochemistry = emptySmilesStereochemistry"
    , "  }))"
    ]

atomSourceLines :: Molecule -> [String]
atomSourceLines molecule =
  [ "(AtomId " ++ showAtomId atomId ++ ", Atom"
      ++ " { atomID = AtomId " ++ showAtomId atomId
      ++ ", attributes = elementAttributes " ++ show (symbolOf atom)
      ++ ", coordinate = Coordinate (mkAngstrom " ++ showDoubleLiteral coordX
      ++ ") (mkAngstrom " ++ showDoubleLiteral coordY
      ++ ") (mkAngstrom " ++ showDoubleLiteral coordZ ++ ")"
      ++ ", shells = elementShells " ++ show (symbolOf atom)
      ++ ", formalCharge = " ++ show (formalCharge atom)
      ++ " })"
  | (atomId, atom) <- M.toAscList (atoms molecule)
  , let Coordinate cx cy cz = coordinate atom
        coordX = unAngstrom cx
        coordY = unAngstrom cy
        coordZ = unAngstrom cz
  ]

edgeSourceLines :: S.Set Edge -> [String]
edgeSourceLines edgeSet =
  [ "Edge (AtomId " ++ showAtomId left ++ ") (AtomId " ++ showAtomId right ++ ")"
  | Edge left right <- S.toList edgeSet
  ]

systemSourceLines :: Molecule -> [String]
systemSourceLines molecule =
  [ "(SystemId " ++ show systemIdValue
      ++ ", mkBondingSystem (NonNegative " ++ show (getNN (sharedElectrons system))
      ++ ") (S.fromList ["
      ++ intercalate ", " (edgeSourceLines (memberEdges system))
      ++ "]) " ++ maybe "Nothing" (("Just " ++) . showMaybeString) (tag system)
      ++ ")"
  | (SystemId systemIdValue, system) <- systems molecule
  ]

showDoubleLiteral :: Double -> String
showDoubleLiteral value
  | value < 0 = "(" ++ show value ++ ")"
  | otherwise = show value

showMaybeString :: String -> String
showMaybeString value = "(" ++ show value ++ ")"

printSearchResult :: SearchResult -> IO ()
printSearchResult result = putStrLn (renderSearchResult result)

renderSearchResult :: SearchResult -> String
renderSearchResult result =
  unlines $
    defaultTargetLine
      ++ [ "Target FreeSolv hydration free energy: " ++ printf "%.3f" (resultTarget result)
         , ""
         , "Diagnostics"
         ]
      ++ modelLines
      ++ [ "  seed molecule: " ++ seedMoleculeLabel (resultSeedMolecule result)
         , "  deterministic seed: " ++ show randomSeedDefault
         , "  benchmark molecules: train=" ++ show (resultTrainMolecules result)
             ++ ", valid=" ++ show (resultValidMolecules result)
             ++ ", test=" ++ show (resultTestMolecules result)
             ++ ", total=" ++ show benchmarkTotal
         , "  search budget: " ++ show (resultSeedCount result)
             ++ " seed chains x " ++ show (resultStepsPerSeed result)
             ++ " proposals = " ++ show (resultSeedCount result * resultStepsPerSeed result)
         , "  posterior draws used: " ++ show (resultPosteriorDrawsUsed result)
             ++ " of " ++ show (resultPosteriorDrawsFound result)
         , "  total proposals: " ++ show (totalProposals diagnostics)
         , "  valid proposals: " ++ show (validProposals diagnostics)
         , "  invalid proposals: " ++ show (invalidProposals diagnostics)
         , "  accepted proposals: " ++ show (acceptedProposals diagnostics)
         , "  acceptance rate: " ++ printf "%.3f" (safeRate (acceptedProposals diagnostics) (totalProposals diagnostics))
         , "  invalid proposal rate: " ++ printf "%.3f" (safeRate (invalidProposals diagnostics) (totalProposals diagnostics))
         , "  unique valid molecules seen: " ++ show (uniqueValidMoleculesSeen diagnostics)
         ]
      ++ elapsedLines
      ++ fileLines
      ++ [ ""
         , "Top generated molecules"
         ]
      ++ concat
           [ renderCandidate rank candidate (resultTarget result)
           | (rank, candidate) <- zip [1 :: Int ..] (resultTopCandidates result)
           ]
  where
    diagnostics = resultDiagnostics result
    benchmarkTotal =
      resultTrainMolecules result + resultValidMolecules result + resultTestMolecules result
    defaultTargetLine =
      if resultUsedDefaultTarget result
        then ["No --target supplied; using median experimental FreeSolv target: " ++ printf "%.3f" (resultTarget result)]
        else []
    modelLines =
      maybe [] (\path -> ["  FreeSolv model parameters: " ++ path]) (resultCoefficientSource result)
        ++ maybe [] (\path -> ["  FreeSolv posterior draws: " ++ path]) (resultDrawSource result)
    fileLines =
      case resultMoleculeFilePaths result of
        [] -> []
        paths -> "  molecule files:" : map ("    " ++) paths
    elapsedLines =
      maybe [] (\seconds -> ["  search runtime: " ++ formatSeconds seconds]) (resultElapsedSeconds result)

printInverseDesignPlan :: FreeSolvPredictor -> InverseDesignConfig -> Double -> Int -> IO ()
printInverseDesignPlan predictor config target proposalBudget = do
  let trainCount = predictorTrainMolecules predictor
      validCount = predictorValidMolecules predictor
      testCount = predictorTestMolecules predictor
      totalCount = trainCount + validCount + testCount
      seedCount = max 1 (configSeeds config)
      stepsPerSeed = max 0 (configSteps config)
  putStrLn "FreeSolv inverse-design setup:"
  putStrLn $
    "  benchmark molecules: train=" ++ show trainCount
      ++ ", valid=" ++ show validCount
      ++ ", test=" ++ show testCount
      ++ ", total=" ++ show totalCount
  putStrLn $ "  feature count: " ++ show (length (predictorFeatureNames predictor))
  putStrLn $ "  selected GP features: " ++ show (length (predictorSelectedIndices predictor))
  putStrLn $
    "  posterior draws: " ++ show (length (predictorDrawWeights predictor))
      ++ " used of " ++ show (predictorDrawsFound predictor)
  putStrLn $ "  target: " ++ printf "%.3f" target ++ " kcal/mol"
  putStrLn $ "  seed molecule: " ++ seedMoleculeLabel (configSeedMolecule config)
  putStrLn $
    "  search budget: " ++ show seedCount
      ++ " seed chains x " ++ show stepsPerSeed
      ++ " proposals = " ++ show proposalBudget
  putStrLn $ "  runtime expectation: " ++ inverseRuntimeExpectation trainCount proposalBudget
  hFlush stdout

inverseRuntimeExpectation :: Int -> Int -> String
inverseRuntimeExpectation trainCount proposalBudget
  | proposalBudget <= 2500 =
      "usually under a minute; each valid unique molecule is scored against the GP posterior."
  | trainCount <= 600 && proposalBudget <= 10000 =
      "expect seconds to a few minutes; runtime depends on how many proposals validate into unique molecules."
  | otherwise =
      "expect several minutes or more; increase comes from proposal count, validation, and GP scoring."

formatSeconds :: Double -> String
formatSeconds seconds = printf "%.2fs" seconds

renderCandidate :: Int -> Candidate -> Double -> [String]
renderCandidate rank candidate target =
  [ ""
  , "Molecule #" ++ show rank
  , "  predicted FreeSolv: " ++ printf "%.3f" (candidatePredictedMean candidate)
  , "  predictive sd: " ++ printf "%.3f" (candidatePredictiveSd candidate)
  , "  target error: " ++ printf "%.3f" (abs (candidatePredictedMean candidate - target))
  , "  score: " ++ printf "%.3f" (candidateScore candidate)
  , "  atoms: " ++ show (M.size (atoms molecule))
  , "  heavy atoms: " ++ show (heavyAtomCount molecule)
  , "  local bonds: " ++ show (S.size (localBonds molecule))
  , "  Dietz bonding systems: " ++ show (length (systems molecule))
  , "  formula: " ++ molecularFormula molecule
  , formatDietzMolecule molecule
  ]
  where
    molecule = candidateMolecule candidate

formatDietzMolecule :: Molecule -> String
formatDietzMolecule molecule =
  unlines $
    [ "  atoms:" ]
      ++ [ "    " ++ showAtomId atomId ++ " " ++ show (symbolOf atom)
         | (atomId, atom) <- M.toAscList (atoms molecule)
         ]
      ++ [ "  local_bonds:" ]
      ++ bondLines
      ++ [ "  bonding_systems:" ]
      ++ systemLines
  where
    bondLines =
      case S.toList (localBonds molecule) of
        [] -> ["    (none)"]
        edges ->
          [ "    {" ++ showAtomId left ++ "," ++ showAtomId right ++ "}"
          | Edge left right <- edges
          ]
    systemLines =
      case systems molecule of
        [] -> ["    (none)"]
        values ->
          [ "    System " ++ show index
              ++ " (id=" ++ show systemIdValue ++ "): shared_electrons="
              ++ show (getNN (sharedElectrons system))
              ++ ", member_edges={"
              ++ intercalate "," [ "{" ++ showAtomId left ++ "," ++ showAtomId right ++ "}" | Edge left right <- S.toList (memberEdges system) ]
              ++ "}"
              ++ maybe "" ((", tag=" ++) ) (tag system)
          | (index, (SystemId systemIdValue, system)) <- zip [1 :: Int ..] values
          ]

formatAndPrintResult :: SearchResult -> IO SearchResult
formatAndPrintResult result = printSearchResult result >> pure result

weightedChoice :: [(String, Double)] -> StdGen -> (String, StdGen)
weightedChoice weighted gen =
  let total = sum (map snd weighted)
      (threshold, gen1) = randomR (0.0, total) gen
  in (pick threshold weighted, gen1)
  where
    pick _ [] = ""
    pick threshold ((name, weight) : rest)
      | threshold <= weight = name
      | otherwise = pick (threshold - weight) rest

chooseOne :: [a] -> StdGen -> (a, StdGen)
chooseOne [] _ = error "chooseOne called with an empty list"
chooseOne values gen =
  let (index, gen1) = randomR (0, length values - 1) gen
  in (values !! index, gen1)

screenTopCorrelationFeatures :: Int -> [[Double]] -> [Double] -> [Int]
screenTopCorrelationFeatures requested trainRows trainTargets =
  sort $
    take (max 1 (min requested featureCount)) $
      map snd $
        sortOn (\(score, index) -> (Down score, Down index)) $
          zip scores [0 ..]
  where
    featureCount =
      case trainRows of
        [] -> 0
        row : _ -> length row
    targetMean = mean trainTargets
    centeredTargets = map (\value -> value - targetMean) trainTargets
    targetNorm = sqrt (sum (map (^ (2 :: Int)) centeredTargets))
    columns = transposeRows trainRows
    scores =
      [ let denominator = sqrt (sum (map (^ (2 :: Int)) column)) * targetNorm
        in if denominator <= 0.0
             then 0.0
             else abs (sum (zipWith (*) column centeredTargets) / denominator)
      | column <- columns
      ]

transposeRows :: [[a]] -> [[a]]
transposeRows [] = []
transposeRows rows
  | any null rows = []
  | otherwise = map head rows : transposeRows (map tail rows)

selectIndices :: [Int] -> [a] -> [a]
selectIndices indices row = map (row !!) indices

kernelTrainMatrix :: V.Vector (U.Vector Double) -> GpDraw -> U.Vector Double
kernelTrainMatrix trainInputs draw =
  let trainCount = V.length trainInputs
      ridge = drawSigma draw * drawSigma draw + kernelJitter
  in U.generate (trainCount * trainCount) $ \flat ->
       let (rowIndex, colIndex) = flat `divMod` trainCount
           baseKernel = rbfKernel draw (trainInputs V.! rowIndex) (trainInputs V.! colIndex)
       in if rowIndex == colIndex then baseKernel + ridge else baseKernel

crossKernelVector :: V.Vector (U.Vector Double) -> GpDraw -> U.Vector Double -> U.Vector Double
crossKernelVector trainInputs draw testInput =
  U.generate (V.length trainInputs) $ \index ->
    rbfKernel draw (trainInputs V.! index) testInput

rbfKernel :: GpDraw -> U.Vector Double -> U.Vector Double -> Double
rbfKernel draw left right =
  let lengthscale = max 1e-9 (drawLengthscale draw)
      varianceScale = drawSignalScale draw * drawSignalScale draw
      featureCount = max 1 (U.length left)
      sqdist =
        U.sum $
          U.zipWith
            (\a b -> let delta = a - b in delta * delta)
            left
            right
      normalized = sqdist / fromIntegral featureCount
  in varianceScale * exp (negate normalized / (2.0 * lengthscale * lengthscale))

choleskyDecompose :: Int -> U.Vector Double -> Maybe (U.Vector Double)
choleskyDecompose matrixSize inputMatrix =
  runST $ do
    lower <- MU.replicate (matrixSize * matrixSize) 0.0
    failedRef <- newSTRef False
    mapM_
      (\colIndex -> do
         failed <- readSTRef failedRef
         if failed
           then pure ()
           else do
             diagonalReduction <-
               sumMutable
                 [ do value <- mutableIndex matrixSize lower colIndex innerIndex
                      pure (value * value)
                 | innerIndex <- [0 .. colIndex - 1]
                 ]
             let candidate = matrixIndex matrixSize inputMatrix colIndex colIndex - diagonalReduction
             if candidate <= minimumVariance
               then writeSTRef failedRef True
               else do
                 let diagonal = sqrt candidate
                 MU.write lower (flatIndex matrixSize colIndex colIndex) diagonal
                 mapM_
                   (\rowIndex -> do
                      offDiagonalReduction <-
                        sumMutable
                          [ do rowValue <- mutableIndex matrixSize lower rowIndex innerIndex
                               colValue <- mutableIndex matrixSize lower colIndex innerIndex
                               pure (rowValue * colValue)
                          | innerIndex <- [0 .. colIndex - 1]
                          ]
                      let numerator = matrixIndex matrixSize inputMatrix rowIndex colIndex - offDiagonalReduction
                      MU.write lower (flatIndex matrixSize rowIndex colIndex) (numerator / diagonal)
                   )
                   [colIndex + 1 .. matrixSize - 1]
      )
      [0 .. matrixSize - 1]
    failed <- readSTRef failedRef
    if failed
      then pure Nothing
      else Just <$> U.unsafeFreeze lower

solveSymmetricPositiveDefinite :: Int -> U.Vector Double -> U.Vector Double -> U.Vector Double
solveSymmetricPositiveDefinite matrixSize cholesky rhs =
  backwardSubstitute matrixSize cholesky (forwardSubstitute matrixSize cholesky rhs)

forwardSubstitute :: Int -> U.Vector Double -> U.Vector Double -> U.Vector Double
forwardSubstitute matrixSize lower rhs =
  runST $ do
    solution <- MU.replicate matrixSize 0.0
    mapM_
      (\rowIndex -> do
         partial <-
           sumMutable
             [ do value <- MU.read solution colIndex
                  pure (matrixIndex matrixSize lower rowIndex colIndex * value)
             | colIndex <- [0 .. rowIndex - 1]
             ]
         let diagonal = matrixIndex matrixSize lower rowIndex rowIndex
             rhsEntry = rhs U.! rowIndex
         MU.write solution rowIndex ((rhsEntry - partial) / diagonal)
      )
      [0 .. matrixSize - 1]
    U.unsafeFreeze solution

backwardSubstitute :: Int -> U.Vector Double -> U.Vector Double -> U.Vector Double
backwardSubstitute matrixSize lower rhs =
  runST $ do
    solution <- MU.replicate matrixSize 0.0
    mapM_
      (\rowIndex -> do
         partial <-
           sumMutable
             [ do value <- MU.read solution colIndex
                  pure (matrixIndex matrixSize lower colIndex rowIndex * value)
             | colIndex <- [rowIndex + 1 .. matrixSize - 1]
             ]
         let diagonal = matrixIndex matrixSize lower rowIndex rowIndex
             rhsEntry = rhs U.! rowIndex
         MU.write solution rowIndex ((rhsEntry - partial) / diagonal)
      )
      (reverse [0 .. matrixSize - 1])
    U.unsafeFreeze solution

sumMutable :: [ST s Double] -> ST s Double
sumMutable = foldl' step (pure 0.0)
  where
    step acc action = do
      total <- acc
      value <- action
      pure (total + value)

matrixIndex :: Int -> U.Vector Double -> Int -> Int -> Double
matrixIndex matrixSize matrix rowIndex colIndex =
  matrix U.! flatIndex matrixSize rowIndex colIndex

mutableIndex :: Int -> MU.MVector s Double -> Int -> Int -> ST s Double
mutableIndex matrixSize matrix rowIndex colIndex =
  MU.read matrix (flatIndex matrixSize rowIndex colIndex)

flatIndex :: Int -> Int -> Int -> Int
flatIndex matrixSize rowIndex colIndex = rowIndex * matrixSize + colIndex

mean :: [Double] -> Double
mean [] = 0.0
mean values = sum values / fromIntegral (length values)

variance :: [Double] -> Double
variance [] = 0.0
variance values =
  let mu = mean values
  in mean [let delta = value - mu in delta * delta | value <- values]

dot :: U.Vector Double -> U.Vector Double -> Double
dot left right = U.sum (U.zipWith (*) left right)

radialCenters :: [Double]
radialCenters = [1.5, 2.5, 3.5, 4.5]

angleCenters :: [Double]
angleCenters = [60.0, 90.0, 120.0, 180.0]

torsionCenters :: [Double]
torsionCenters = [0.0, 60.0, 120.0, 180.0]

radialChannel :: Double -> Double -> Double
radialChannel center value = exp (negate ((value - center) * (value - center)) / (2.0 * 0.75 * 0.75))

angleChannel :: Double -> Double -> Double
angleChannel center value = exp (negate ((value - center) * (value - center)) / (2.0 * 18.0 * 18.0))

torsionChannel :: Double -> Double -> Double
torsionChannel center value = exp (negate ((value - center) * (value - center)) / (2.0 * 20.0 * 20.0))

radialFeatureName :: String -> Double -> String
radialFeatureName prefix center = prefix ++ "_" ++ replaceDot (printf "%.1fa" center)

angularFeatureName :: String -> Double -> String
angularFeatureName prefix center = prefix ++ "_" ++ show (round center :: Int) ++ "d"

replaceDot :: String -> String
replaceDot = map (\char -> if char == '.' then 'p' else char)

pairSymbols :: [AtomicSymbol]
pairSymbols = [H, C, N, O, S, P, Si, F, Cl, Br, I, Fe, B, Na]

orderedSymbolPairs :: [(AtomicSymbol, AtomicSymbol)]
orderedSymbolPairs =
  [ (left, right)
  | (index, left) <- zip [0 :: Int ..] pairSymbols
  , right <- drop index pairSymbols
  ]

orderedSymbols :: AtomicSymbol -> AtomicSymbol -> (AtomicSymbol, AtomicSymbol)
orderedSymbols left right =
  if symbolIndex left <= symbolIndex right
    then (left, right)
    else (right, left)

symbolIndex :: AtomicSymbol -> Int
symbolIndex symbolValue =
  case lookup symbolValue (zip pairSymbols [0 ..]) of
    Just index -> index
    Nothing -> 999

pairFeatureName :: String -> AtomicSymbol -> AtomicSymbol -> String
pairFeatureName prefix left right =
  prefix ++ "_" ++ symbolToken left ++ "_" ++ symbolToken right

symbolToken :: AtomicSymbol -> String
symbolToken = map toLower . show

symbolOf :: Atom -> AtomicSymbol
symbolOf = symbol . attributes

moleculeWeight :: Molecule -> Double
moleculeWeight molecule = sum [atomicWeight (attributes atom) | atom <- M.elems (atoms molecule)]

heteroAtomCount :: Molecule -> Double
heteroAtomCount molecule =
  fromIntegral (length [() | atom <- M.elems (atoms molecule), symbolOf atom `notElem` [C, H]])

hydrogenBondAcceptorCount :: Molecule -> Double
hydrogenBondAcceptorCount molecule =
  fromIntegral (length [() | atom <- M.elems (atoms molecule), symbolOf atom `elem` [N, O, S]])

hydrogenBondDonorCount :: Molecule -> Double
hydrogenBondDonorCount molecule =
  fromIntegral
    ( length
        [ ()
        | (atomId, atom) <- M.toAscList (atoms molecule)
        , symbolOf atom `elem` [N, O, S]
        , any (\neighbor -> symbolOf (atoms molecule M.! neighbor) == H) (neighborsSigma molecule atomId)
        ]
    )

moleculeBondOrder :: Molecule -> Double
moleculeBondOrder molecule =
  sum [effectiveOrder molecule edge | edge <- S.toList (allEdges molecule)]

heavyAtomCount :: Molecule -> Int
heavyAtomCount molecule =
  length [() | atom <- M.elems (atoms molecule), symbolOf atom /= H]

halogenAtomCount :: Molecule -> Int
halogenAtomCount molecule =
  length [() | atom <- M.elems (atoms molecule), symbolOf atom `elem` [F, Cl, Br, I]]

atomCountBySymbol :: AtomicSymbol -> Molecule -> Double
atomCountBySymbol atomSymbol molecule =
  fromIntegral (length [() | atom <- M.elems (atoms molecule), symbolOf atom == atomSymbol])

aromaticRingCount :: Molecule -> Double
aromaticRingCount molecule =
  fromIntegral (length [() | (_, system) <- systems molecule, tag system == Just "pi_ring"])

ringEdgeFraction :: Molecule -> Double
ringEdgeFraction molecule
  | S.null uniqueEdges = 0.0
  | otherwise =
      fromIntegral (length [edge | edge <- S.toList uniqueEdges, edgeInCycle adjacency edge])
        / fromIntegral (S.size uniqueEdges)
  where
    uniqueEdges = allEdges molecule
    adjacency = adjacencyFromEdges (localBonds molecule)

rotatableBondCount :: Molecule -> Double
rotatableBondCount molecule =
  fromIntegral
    ( length
        [ ()
        | edge@(Edge left right) <- S.toList (localBonds molecule)
        , isHeavy left
        , isHeavy right
        , heavyDegree left > 1
        , heavyDegree right > 1
        , effectiveOrder molecule edge <= 1.1
        , not (edgeInCycle adjacency edge)
        ]
    )
  where
    adjacency = adjacencyFromEdges (localBonds molecule)
    isHeavy atomId = symbolOf (atoms molecule M.! atomId) /= H
    heavyDegree atomId =
      length [neighbor | neighbor <- M.findWithDefault [] atomId adjacency, isHeavy neighbor]

edgeInCycle :: M.Map AtomId [AtomId] -> Edge -> Bool
edgeInCycle adjacency (Edge left right) =
  let reduced =
        M.adjust (filter (/= right)) left $
          M.adjust (filter (/= left)) right adjacency
  in right `S.member` walk S.empty [left] reduced

distance :: Atom -> Atom -> Double
distance left right = vectorNorm (vectorFromTo left right)

edgeDistance :: Molecule -> Edge -> Double
edgeDistance molecule (Edge left right) =
  distance (atoms molecule M.! left) (atoms molecule M.! right)

vectorFromTo :: Atom -> Atom -> (Double, Double, Double)
vectorFromTo fromAtom toAtom =
  let Coordinate fx fy fz = coordinate fromAtom
      Coordinate tx ty tz = coordinate toAtom
  in (unAngstrom tx - unAngstrom fx, unAngstrom ty - unAngstrom fy, unAngstrom tz - unAngstrom fz)

vectorNorm :: (Double, Double, Double) -> Double
vectorNorm (a, b, c) = sqrt (a * a + b * b + c * c)

dot3 :: (Double, Double, Double) -> (Double, Double, Double) -> Double
dot3 (a1, a2, a3) (b1, b2, b3) = a1 * b1 + a2 * b2 + a3 * b3

cross3 :: (Double, Double, Double) -> (Double, Double, Double) -> (Double, Double, Double)
cross3 (a1, a2, a3) (b1, b2, b3) =
  (a2 * b3 - a3 * b2, a3 * b1 - a1 * b3, a1 * b2 - a2 * b1)

scale3 :: Double -> (Double, Double, Double) -> (Double, Double, Double)
scale3 scale (a, b, c) = (scale * a, scale * b, scale * c)

minus3 :: (Double, Double, Double) -> (Double, Double, Double) -> (Double, Double, Double)
minus3 (a1, a2, a3) (b1, b2, b3) = (a1 - b1, a2 - b2, a3 - b3)

absoluteDihedralDegrees :: Atom -> Atom -> Atom -> Atom -> Double
absoluteDihedralDegrees atomA atomB atomC atomD =
  let bondAB = vectorFromTo atomB atomA
      bondBC = vectorFromTo atomB atomC
      bondCD = vectorFromTo atomC atomD
      normBC = vectorNorm bondBC
  in if normBC <= 1e-6
       then 0.0
       else
         let bcUnit = scale3 (1.0 / normBC) bondBC
             normalLeft = bondAB `minus3` scale3 (dot3 bondAB bcUnit) bcUnit
             normalRight = bondCD `minus3` scale3 (dot3 bondCD bcUnit) bcUnit
             leftNorm = vectorNorm normalLeft
             rightNorm = vectorNorm normalRight
         in if leftNorm <= 1e-6 || rightNorm <= 1e-6
              then 0.0
              else
                let leftUnit = scale3 (1.0 / leftNorm) normalLeft
                    rightUnit = scale3 (1.0 / rightNorm) normalRight
                    xValue = dot3 leftUnit rightUnit
                    yValue = dot3 (cross3 bcUnit leftUnit) rightUnit
                in abs (atan2 yValue xValue * 180.0 / pi)

neighborPairs :: [a] -> [(a, a)]
neighborPairs values =
  [ (left, right)
  | (index, left) <- zip [0 :: Int ..] values
  , right <- drop (index + 1) values
  ]

clamp :: Double -> Double -> Double -> Double
clamp lower upper value = max lower (min upper value)

safeRate :: Int -> Int -> Double
safeRate _ 0 = 0.0
safeRate numerator denominator = fromIntegral numerator / fromIntegral denominator

growthMaxValence :: AtomicSymbol -> Double
growthMaxValence H = 1.0
growthMaxValence C = 4.0
growthMaxValence N = 3.0
growthMaxValence O = 2.0
growthMaxValence F = 1.0
growthMaxValence Cl = 1.0
growthMaxValence other =
  error ("Unsupported inverse-design element: " ++ show other)

supportedSymbols :: [AtomicSymbol]
supportedSymbols = [H, C, N, O, F, Cl]

availableValence :: Molecule -> AtomId -> Double
availableValence molecule atomId =
  growthMaxValence (symbolOf (atoms molecule M.! atomId)) - usedElectronsAt molecule atomId

freshAtomId :: Molecule -> AtomId
freshAtomId molecule = AtomId (1 + maximum (0 : map atomIdInteger (M.keys (atoms molecule))))

edgeTouches :: AtomId -> Edge -> Bool
edgeTouches atomId (Edge left right) = atomId == left || atomId == right

atomIdInteger :: AtomId -> Integer
atomIdInteger (AtomId value) = value

showAtomId :: AtomId -> String
showAtomId = show . atomIdInteger

ringSortKey :: S.Set Edge -> [(Integer, Integer)]
ringSortKey ring =
  sort [(atomIdInteger left, atomIdInteger right) | Edge left right <- S.toList ring]

moleculeKey :: Molecule -> String
moleculeKey molecule =
  show
    ( [ (atomIdInteger atomId, show (symbolOf atom)) | (atomId, atom) <- M.toAscList (atoms molecule) ]
    , [ (atomIdInteger left, atomIdInteger right) | Edge left right <- S.toList (localBonds molecule) ]
    , [ ( getNN (sharedElectrons system)
        , ringSortKey (memberEdges system)
        , tag system
        )
      | (_, system) <- systems molecule
      ]
    )

molecularFormula :: Molecule -> String
molecularFormula molecule =
  concat
    [ symbolText ++ if count == 1 then "" else show count
    | symbolText <- orderedSymbolsForFormula
    , let count = M.findWithDefault 0 symbolText counts
    , count > 0
    ]
  where
    counts =
      M.fromListWith (+)
        [ (show (symbolOf atom), 1 :: Int)
        | atom <- M.elems (atoms molecule)
        ]
    orderedSymbolsForFormula =
      (if M.member "C" counts then ["C"] else [])
        ++ (if M.member "H" counts then ["H"] else [])
        ++ filter (`M.member` counts) ["B", "Br", "Cl", "F", "Fe", "I", "N", "Na", "O", "P", "S", "Si"]
