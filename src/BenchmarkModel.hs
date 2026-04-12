{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NamedFieldPuns #-}

module BenchmarkModel
  ( BenchmarkInferenceMethod(..)
  , BenchmarkObservation(..)
  , BenchmarkDataset(..)
  , BenchmarkPrediction(..)
  , BenchmarkMetrics(..)
  , BenchmarkParameters(..)
  , SamplingConfig(..)
  , defaultSamplingConfig
  , defaultProcessedDataDir
  , loadBenchmarkDataset
  , parseInferenceMethod
  , runBenchmarkRegressionWith
  ) where

import Control.DeepSeq (NFData)
import Control.Monad (forM_, replicateM, unless, when)
import Control.Parallel.Strategies (parMap, rdeepseq)
import Data.Char (isSpace)
import Data.List (foldl', intercalate, isPrefixOf, isSuffixOf, sortOn, zipWith3)
import Data.Ord (Down(..))
import Distr (normal)
import GaussianProcess
  ( GaussianProcessParameters(..)
  , GaussianProcessSupport
  , defaultGaussianProcessFeatureCap
  , gaussianProcessFeatureNames
  , gaussianProcessLogLikelihood
  , predictGaussianProcess
  , prepareGaussianProcessSupport
  )
import GHC.Generics (Generic)
import LazyPPL (Meas, lwis, mh, sample, scoreLog)
import Numeric.Log (Log(Exp))
import Numeric.SpecFunctions (logGamma)
import System.FilePath ((</>))
import Text.Read (readMaybe)


data BenchmarkObservation = BenchmarkObservation
  { observationLabel :: !String
  , predictorValues  :: ![Double]
  , observedTarget   :: !Double
  } deriving (Show, Eq, Generic)

instance NFData BenchmarkObservation


data BenchmarkDataset = BenchmarkDataset
  { datasetPrefix      :: !String
  , targetName         :: !String
  , representationName :: !String
  , featureNames       :: ![String]
  , trainObservations  :: ![BenchmarkObservation]
  , validObservations  :: ![BenchmarkObservation]
  , testObservations   :: ![BenchmarkObservation]
  } deriving (Show, Eq, Generic)

instance NFData BenchmarkDataset


data BenchmarkParameters
  = LinearParameters
      { paramIntercept :: !Double
      , paramCoeffs    :: ![Double]
      , paramSigma     :: !Double
      }
  | GaussianProcessPosterior
      { paramGaussianProcess :: !GaussianProcessParameters
      }
  deriving (Show, Eq, Generic)

instance NFData BenchmarkParameters


data BenchmarkPrediction = BenchmarkPrediction
  { predictionLabel :: !String
  , predictedMean   :: !Double
  , predictedSd     :: !Double
  , actualValue     :: !Double
  , residualValue   :: !Double
  } deriving (Show, Eq, Generic)

instance NFData BenchmarkPrediction


data BenchmarkMetrics = BenchmarkMetrics
  { metricMae      :: !Double
  , metricRmse     :: !Double
  , metricRowCount :: !Int
  } deriving (Show, Eq, Generic)

instance NFData BenchmarkMetrics


data SamplingConfig = SamplingConfig
  { burnInIterations :: !Int
  , posteriorSamples :: !Int
  } deriving (Show, Eq)


defaultSamplingConfig :: SamplingConfig
defaultSamplingConfig =
  SamplingConfig
    { burnInIterations = 15000
    , posteriorSamples = 200
    }


data BenchmarkInferenceMethod
  = UseLWIS { lwisSampleCount :: !Int }
  | UseMH { mhJitter :: !Double }
  deriving (Eq, Show)


data BenchmarkModelFamily
  = UseLinearStudentT
  | UseGaussianProcessRbf
  deriving (Eq, Show)


data PreparedBenchmark = PreparedBenchmark
  { preparedDataset :: !BenchmarkDataset
  , preparedModel   :: !BenchmarkModelFamily
  , preparedGP      :: !(Maybe GaussianProcessSupport)
  }


defaultProcessedDataDir :: FilePath
defaultProcessedDataDir = "../MolADT-Bayes-Python/data/processed"


loadBenchmarkDataset :: FilePath -> String -> Maybe Int -> IO BenchmarkDataset
loadBenchmarkDataset processedDir prefix mLimit = do
  (xHeader, xTrainRows) <- readNumericCsv (processedDir </> (prefix ++ "_X_train.csv"))
  (_, xValidRows) <- readNumericCsv (processedDir </> (prefix ++ "_X_valid.csv"))
  (_, xTestRows) <- readNumericCsv (processedDir </> (prefix ++ "_X_test.csv"))
  (yTrainHeader, yTrainRows) <- readNumericCsv (processedDir </> (prefix ++ "_y_train.csv"))
  (_, yValidRows) <- readNumericCsv (processedDir </> (prefix ++ "_y_valid.csv"))
  (_, yTestRows) <- readNumericCsv (processedDir </> (prefix ++ "_y_test.csv"))
  target <- case yTrainHeader of
    [name] -> pure name
    _      -> fail ("Expected a single target column in " ++ prefix ++ "_y_train.csv")
  let train = mkObservations "train" xTrainRows yTrainRows
      valid = mkObservations "valid" xValidRows yValidRows
      test  = mkObservations "test" xTestRows yTestRows
      representation
        | "_moladt_featurized" `isSuffixOf` prefix = "moladt_featurized"
        | "_moladt" `isSuffixOf` prefix = "moladt"
        | otherwise                     = "unknown"
  pure
    BenchmarkDataset
      { datasetPrefix = prefix
      , targetName = target
      , representationName = representation
      , featureNames = xHeader
      , trainObservations = applyLimit mLimit train
      , validObservations = applyLimit mLimit valid
      , testObservations = applyLimit mLimit test
      }
  where
    mkObservations :: String -> [[Double]] -> [[Double]] -> [BenchmarkObservation]
    mkObservations splitName xs ys
      | length xs /= length ys =
          error $
            "Mismatched row counts for " ++ prefix ++ " " ++ splitName
            ++ " split: X has " ++ show (length xs)
            ++ " rows but y has " ++ show (length ys)
      | otherwise =
          zipWith3
            (\index predictors targetRow ->
               case targetRow of
                 [targetValue] ->
                   BenchmarkObservation
                     { observationLabel = splitName ++ "[" ++ show index ++ "]"
                     , predictorValues = predictors
                     , observedTarget = targetValue
                     }
                 _ ->
                   error $
                     "Expected a single target value in " ++ splitName
                     ++ " split row " ++ show index
            )
            [1 ..]
            xs
            ys

    applyLimit :: Maybe Int -> [a] -> [a]
    applyLimit Nothing xs = xs
    applyLimit (Just n) xs = take (max 0 n) xs


parseInferenceMethod :: SamplingConfig -> String -> Maybe BenchmarkInferenceMethod
parseInferenceMethod config raw =
  case break (== ':') raw of
    ("lwis", []) -> Just (UseLWIS (posteriorSamples config))
    ("lwis", ':' : countText) -> UseLWIS <$> readMaybe countText
    ("mh", []) -> Just (UseMH 0.9)
    ("mh", ':' : jitterText) -> UseMH <$> readMaybe jitterText
    _ -> Nothing


runBenchmarkRegressionWith :: SamplingConfig -> BenchmarkInferenceMethod -> FilePath -> String -> Maybe Int -> IO ()
runBenchmarkRegressionWith SamplingConfig { burnInIterations, posteriorSamples }
                          requestedMethod
                          processedDir
                          prefix
                          mLimit = do
  dataset <- loadBenchmarkDataset processedDir prefix mLimit
  let prepared = prepareBenchmark dataset
      modelFamily = preparedModel prepared
      method = adjustedInferenceMethod modelFamily requestedMethod
      actualBurnIn = adjustedBurnIn modelFamily burnInIterations
      actualPosteriorSamples = adjustedPosteriorSamples modelFamily posteriorSamples
      trainCount = length (trainObservations dataset)
      validCount = length (validObservations dataset)
      testCount  = length (testObservations dataset)
  putStrLn $ "Benchmark dataset: " ++ datasetPrefix dataset
  putStrLn $ "Target: " ++ targetName dataset
  putStrLn $ "Representation: " ++ describeRepresentation (representationName dataset)
  putStrLn $ "Feature count: " ++ show (length (featureNames dataset))
  putStrLn $
    "Split sizes: train=" ++ show trainCount
    ++ ", valid=" ++ show validCount
    ++ ", test=" ++ show testCount
  putStrLn $ "Model alignment: " ++ describeModelAlignment prepared
  putStrLn $ "Inference method: " ++ describeInferenceMethod method
  putStrLn $
    "Execution budget: burn-in=" ++ show actualBurnIn
    ++ ", posterior_samples=" ++ show actualPosteriorSamples
  printPreparedModelDetails prepared

  parameterSamples <- benchmarkModelWith method prepared

  let (skippedBurnIn, postBurnSamples) = splitAt actualBurnIn parameterSamples
      usedBurnIn = length skippedBurnIn
  when (actualBurnIn > 0 && usedBurnIn < actualBurnIn && not (null parameterSamples)) $
    putStrLn $
      "Warning: only " ++ show usedBurnIn
      ++ " burn-in samples were available out of the requested "
      ++ show actualBurnIn ++ "."

  let posteriorSampleList =
        case method of
          UseLWIS {} -> take (max 1 actualPosteriorSamples) parameterSamples
          UseMH {}   -> take (max 1 actualPosteriorSamples) postBurnSamples
      collectedSamples = length posteriorSampleList
      effectiveSamples =
        if null posteriorSampleList
          then [defaultParametersFor prepared]
          else posteriorSampleList
      validPredictions = predictSplit prepared effectiveSamples (validObservations dataset)
      testPredictions = predictSplit prepared effectiveSamples (testObservations dataset)

  putStrLn $ "Posterior samples used: " ++ show collectedSamples
  printPosteriorSummary prepared effectiveSamples

  unless (null validPredictions) $ do
    let validMetrics = summarizeMetrics validPredictions
    putStrLn $
      "Validation metrics: MAE=" ++ show (metricMae validMetrics)
      ++ ", RMSE=" ++ show (metricRmse validMetrics)
      ++ ", n=" ++ show (metricRowCount validMetrics)

  unless (null testPredictions) $ do
    let testMetrics = summarizeMetrics testPredictions
    putStrLn "Test-set predictions:"
    forM_ testPredictions $ \prediction ->
      putStrLn $
        "  - " ++ predictionLabel prediction
        ++ ": predicted=" ++ show (predictedMean prediction)
        ++ ", actual=" ++ show (actualValue prediction)
        ++ ", residual=" ++ show (residualValue prediction)
        ++ ", posterior_sd=" ++ show (predictedSd prediction)
    putStrLn $
      "Test-set metrics: MAE=" ++ show (metricMae testMetrics)
      ++ ", RMSE=" ++ show (metricRmse testMetrics)
      ++ ", n=" ++ show (metricRowCount testMetrics)


prepareBenchmark :: BenchmarkDataset -> PreparedBenchmark
prepareBenchmark dataset =
  case modelFamilyFor dataset of
    UseLinearStudentT ->
      PreparedBenchmark
        { preparedDataset = dataset
        , preparedModel = UseLinearStudentT
        , preparedGP = Nothing
        }
    UseGaussianProcessRbf ->
      let trainRows = map predictorValues (trainObservations dataset)
          trainTargets = map observedTarget (trainObservations dataset)
          support =
            prepareGaussianProcessSupport
              defaultGaussianProcessFeatureCap
              (featureNames dataset)
              trainRows
              trainTargets
      in PreparedBenchmark
           { preparedDataset = dataset
           , preparedModel = UseGaussianProcessRbf
           , preparedGP = Just support
           }


modelFamilyFor :: BenchmarkDataset -> BenchmarkModelFamily
modelFamilyFor dataset
  | "freesolv_" `isPrefixOf` datasetPrefix dataset
    && representationName dataset == "moladt_featurized" = UseGaussianProcessRbf
  | otherwise = UseLinearStudentT


adjustedInferenceMethod :: BenchmarkModelFamily -> BenchmarkInferenceMethod -> BenchmarkInferenceMethod
adjustedInferenceMethod UseGaussianProcessRbf UseLWIS { lwisSampleCount } =
  UseLWIS (min 128 (max 32 lwisSampleCount))
adjustedInferenceMethod _ method = method


adjustedBurnIn :: BenchmarkModelFamily -> Int -> Int
adjustedBurnIn UseGaussianProcessRbf requested = min 256 requested
adjustedBurnIn _ requested = requested


adjustedPosteriorSamples :: BenchmarkModelFamily -> Int -> Int
adjustedPosteriorSamples UseGaussianProcessRbf requested = min 64 requested
adjustedPosteriorSamples _ requested = requested


benchmarkModelWith :: BenchmarkInferenceMethod -> PreparedBenchmark -> IO [BenchmarkParameters]
benchmarkModelWith UseLWIS { lwisSampleCount } prepared =
  lwis (max 1 lwisSampleCount) (benchmarkModel prepared)
benchmarkModelWith UseMH { mhJitter } prepared = do
  samples <- mh mhJitter (benchmarkModel prepared)
  pure (map fst samples)


benchmarkModel :: PreparedBenchmark -> Meas BenchmarkParameters
benchmarkModel PreparedBenchmark { preparedDataset, preparedModel, preparedGP } =
  case preparedModel of
    UseLinearStudentT -> linearBenchmarkModel preparedDataset
    UseGaussianProcessRbf ->
      case preparedGP of
        Nothing -> error "Gaussian-process benchmark requested without prepared support."
        Just support -> gaussianProcessBenchmarkModel support


linearBenchmarkModel :: BenchmarkDataset -> Meas BenchmarkParameters
linearBenchmarkModel dataset = do
  intercept <- sample (normal 0.0 1.5)
  coeffs <- replicateM featureCount (sample (normal 0.0 1.0))
  sigmaRaw <- sample (normal 0.0 1.0)
  let sigma = max 1.0e-6 (abs sigmaRaw)
      params =
        LinearParameters
          { paramIntercept = intercept
          , paramCoeffs = coeffs
          , paramSigma = sigma
          }
  forM_ (trainObservations dataset) $ \observation -> do
    let mu = linearPredictor params (predictorValues observation)
        logLikelihood = studentTLogPdf 4.0 mu sigma (observedTarget observation)
    scoreLog (Exp logLikelihood)
  pure params
  where
    featureCount = length (featureNames dataset)


gaussianProcessBenchmarkModel :: GaussianProcessSupport -> Meas BenchmarkParameters
gaussianProcessBenchmarkModel support = do
  meanOffset <- sample (normal 0.0 5.0)
  logKernelScale <- sample (normal 0.0 1.0)
  logLengthScale <- sample (normal 0.0 1.0)
  logNoiseScale <- sample (normal (-1.0) 1.0)
  let params =
        GaussianProcessParameters
          { gpMeanOffset = meanOffset
          , gpKernelScale = max 1.0e-4 (exp logKernelScale)
          , gpLengthScale = max 1.0e-3 (exp logLengthScale)
          , gpNoiseScale = max 1.0e-4 (exp logNoiseScale)
          }
      logLikelihood =
        maybe (-1.0e12) id (gaussianProcessLogLikelihood support params)
  scoreLog (Exp logLikelihood)
  pure (GaussianProcessPosterior params)


predictSplit :: PreparedBenchmark -> [BenchmarkParameters] -> [BenchmarkObservation] -> [BenchmarkPrediction]
predictSplit PreparedBenchmark { preparedModel = UseLinearStudentT } parameterSamples observations =
  let linearSamples = [params | params@LinearParameters {} <- parameterSamples]
  in parMap rdeepseq (predictLinearObservation linearSamples) observations
predictSplit PreparedBenchmark { preparedModel = UseGaussianProcessRbf, preparedGP = Just support } parameterSamples observations =
  let gpSamples =
        [ params
        | GaussianProcessPosterior { paramGaussianProcess = params } <- parameterSamples
        ]
      predictedPairs = predictGaussianProcess support gpSamples (map predictorValues observations)
  in zipWith attachPrediction observations predictedPairs
  where
    attachPrediction observation (meanValue, sdValue) =
      let residual = meanValue - observedTarget observation
      in BenchmarkPrediction
           { predictionLabel = observationLabel observation
           , predictedMean = meanValue
           , predictedSd = sdValue
           , actualValue = observedTarget observation
           , residualValue = residual
           }
predictSplit _ _ _ = []


predictLinearObservation :: [BenchmarkParameters] -> BenchmarkObservation -> BenchmarkPrediction
predictLinearObservation parameterSamples BenchmarkObservation { observationLabel, predictorValues, observedTarget } =
  let draws =
        [ linearPredictor params predictorValues
        | params@LinearParameters {} <- parameterSamples
        ]
      meanValue = meanDouble draws
      sdValue = stddevDouble draws
      residual = meanValue - observedTarget
  in BenchmarkPrediction
       { predictionLabel = observationLabel
       , predictedMean = meanValue
       , predictedSd = sdValue
       , actualValue = observedTarget
       , residualValue = residual
       }


summarizeMetrics :: [BenchmarkPrediction] -> BenchmarkMetrics
summarizeMetrics predictions =
  let residuals = map residualValue predictions
      invN = 1.0 / fromIntegral (length residuals)
      mae = invN * foldl' (\acc residual -> acc + abs residual) 0.0 residuals
      mse = invN * foldl' (\acc residual -> acc + residual * residual) 0.0 residuals
  in BenchmarkMetrics
       { metricMae = mae
       , metricRmse = sqrt mse
       , metricRowCount = length residuals
       }


describeInferenceMethod :: BenchmarkInferenceMethod -> String
describeInferenceMethod UseLWIS { lwisSampleCount } =
  "Likelihood-weighted importance sampling with " ++ show lwisSampleCount ++ " particles"
describeInferenceMethod UseMH { mhJitter } =
  "Metropolis-Hastings with site-mutation probability " ++ show mhJitter


describeRepresentation :: String -> String
describeRepresentation "moladt_featurized" =
  "MolADT featurized descriptor matrix exported by the Python benchmark"
describeRepresentation "moladt" =
  "typed MolADT descriptor matrix exported by the Python benchmark"
describeRepresentation other = other


describeModelAlignment :: PreparedBenchmark -> String
describeModelAlignment PreparedBenchmark { preparedModel = UseLinearStudentT } =
  "linear Student-t regression baseline over the exact standardized X/y exports written by the Python benchmark pipeline."
describeModelAlignment PreparedBenchmark { preparedModel = UseGaussianProcessRbf } =
  "finite exact RBF Gaussian process over the screened MolADT featurized matrix, adapted from the LazyPPL GP pattern to the benchmark's exported feature rows."


printPreparedModelDetails :: PreparedBenchmark -> IO ()
printPreparedModelDetails PreparedBenchmark { preparedModel = UseLinearStudentT } = pure ()
printPreparedModelDetails PreparedBenchmark { preparedModel = UseGaussianProcessRbf, preparedGP = Just support } =
  putStrLn $
    "Screened GP features: " ++ intercalate ", " (gaussianProcessFeatureNames support)
printPreparedModelDetails _ = pure ()


printPosteriorSummary :: PreparedBenchmark -> [BenchmarkParameters] -> IO ()
printPosteriorSummary PreparedBenchmark { preparedModel = UseLinearStudentT, preparedDataset } parameterSamples = do
  let linearSamples = [params | params@LinearParameters {} <- parameterSamples]
      meanParameters =
        if null linearSamples
          then zeroLinearParameters (length (featureNames preparedDataset))
          else averageLinearParameters linearSamples
  putStrLn $ "Posterior mean intercept: " ++ show (paramIntercept meanParameters)
  putStrLn $ "Posterior mean sigma: " ++ show (paramSigma meanParameters)
  printTopCoefficients (featureNames preparedDataset) meanParameters
printPosteriorSummary PreparedBenchmark { preparedModel = UseGaussianProcessRbf } parameterSamples = do
  let gpSamples =
        [ params
        | GaussianProcessPosterior { paramGaussianProcess = params } <- parameterSamples
        ]
      meanParameters =
        if null gpSamples
          then zeroGaussianProcessParameters
          else averageGaussianProcessParameters gpSamples
  putStrLn $ "Posterior mean offset: " ++ show (gpMeanOffset meanParameters)
  putStrLn $ "Posterior mean kernel scale: " ++ show (gpKernelScale meanParameters)
  putStrLn $ "Posterior mean length scale: " ++ show (gpLengthScale meanParameters)
  putStrLn $ "Posterior mean noise scale: " ++ show (gpNoiseScale meanParameters)


printTopCoefficients :: [String] -> BenchmarkParameters -> IO ()
printTopCoefficients names LinearParameters { paramCoeffs } = do
  let ranked =
        take 8 $
          sortOn (Down . abs . snd) (zip names paramCoeffs)
  unless (null ranked) $ do
    putStrLn "Top posterior mean coefficients:"
    forM_ ranked $ \(name, coeff) ->
      putStrLn $ "  " ++ name ++ ": " ++ show coeff
printTopCoefficients _ _ = pure ()


averageLinearParameters :: [BenchmarkParameters] -> BenchmarkParameters
averageLinearParameters samples =
  let sampleCount = fromIntegral (length samples)
      interceptMean = meanDouble (map paramIntercept samples)
      sigmaMean = meanDouble (map paramSigma samples)
      coeffMeans =
        [ foldl' (\acc params -> acc + paramCoeffs params !! index) 0.0 samples / sampleCount
        | index <- [0 .. length (paramCoeffs (head samples)) - 1]
        ]
  in LinearParameters
       { paramIntercept = interceptMean
       , paramCoeffs = coeffMeans
       , paramSigma = sigmaMean
       }


averageGaussianProcessParameters :: [GaussianProcessParameters] -> GaussianProcessParameters
averageGaussianProcessParameters samples =
  GaussianProcessParameters
    { gpMeanOffset = meanDouble (map gpMeanOffset samples)
    , gpKernelScale = meanDouble (map gpKernelScale samples)
    , gpLengthScale = meanDouble (map gpLengthScale samples)
    , gpNoiseScale = meanDouble (map gpNoiseScale samples)
    }


linearPredictor :: BenchmarkParameters -> [Double] -> Double
linearPredictor LinearParameters { paramIntercept, paramCoeffs } xs =
  paramIntercept + sum (zipWith (*) paramCoeffs xs)
linearPredictor _ _ = 0.0


studentTLogPdf :: Double -> Double -> Double -> Double -> Double
studentTLogPdf nu mu sigma y =
  let z = (y - mu) / sigma
      a = logGamma ((nu + 1.0) / 2.0) - logGamma (nu / 2.0)
      b = -0.5 * log (nu * pi) - log sigma
      c = -((nu + 1.0) / 2.0) * log (1.0 + (z * z) / nu)
  in a + b + c


defaultParametersFor :: PreparedBenchmark -> BenchmarkParameters
defaultParametersFor PreparedBenchmark { preparedModel = UseLinearStudentT, preparedDataset } =
  zeroLinearParameters (length (featureNames preparedDataset))
defaultParametersFor PreparedBenchmark { preparedModel = UseGaussianProcessRbf } =
  GaussianProcessPosterior zeroGaussianProcessParameters


zeroLinearParameters :: Int -> BenchmarkParameters
zeroLinearParameters featureCount =
  LinearParameters
    { paramIntercept = 0.0
    , paramCoeffs = replicate featureCount 0.0
    , paramSigma = 1.0
    }


zeroGaussianProcessParameters :: GaussianProcessParameters
zeroGaussianProcessParameters =
  GaussianProcessParameters
    { gpMeanOffset = 0.0
    , gpKernelScale = 1.0
    , gpLengthScale = 1.0
    , gpNoiseScale = 1.0
    }


meanDouble :: [Double] -> Double
meanDouble [] = 0.0
meanDouble xs = foldl' (+) 0.0 xs / fromIntegral (length xs)


stddevDouble :: [Double] -> Double
stddevDouble [] = 0.0
stddevDouble [_] = 0.0
stddevDouble xs =
  let mu = meanDouble xs
      variance =
        foldl' (\acc x -> acc + (x - mu) * (x - mu)) 0.0 xs
          / fromIntegral (length xs)
  in sqrt variance


readNumericCsv :: FilePath -> IO ([String], [[Double]])
readNumericCsv path = do
  contents <- readFile path
  let nonEmptyLines = filter (not . null) (map trim (lines contents))
  case nonEmptyLines of
    [] -> fail ("Empty CSV file: " ++ path)
    headerLine : rowLines ->
      let header = splitComma headerLine
          rows = zipWith parseRow [2 ..] rowLines
      in pure (header, rows)
  where
    parseRow :: Int -> String -> [Double]
    parseRow lineNumber row =
      case mapM (readMaybe . trim) (splitComma row) of
        Just values -> values
        Nothing ->
          error $
            "Could not parse numeric CSV row in " ++ path
            ++ " at line " ++ show lineNumber


splitComma :: String -> [String]
splitComma [] = [""]
splitComma text =
  let (prefix, suffix) = break (== ',') text
  in case suffix of
       []        -> [prefix]
       (_ : xs)  -> prefix : splitComma xs


trim :: String -> String
trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse
