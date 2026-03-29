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
import Data.List (foldl', isSuffixOf, sortOn, zipWith3)
import Data.Ord (Down(..))
import Distr (normal)
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


data BenchmarkParameters = BenchmarkParameters
  { paramIntercept :: !Double
  , paramCoeffs    :: ![Double]
  , paramSigma     :: !Double
  } deriving (Show, Eq, Generic)

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
        | "_sdf" `isSuffixOf` prefix    = "sdf"
        | "_smiles" `isSuffixOf` prefix = "smiles"
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
                          method
                          processedDir
                          prefix
                          mLimit = do
  dataset <- loadBenchmarkDataset processedDir prefix mLimit
  let trainCount = length (trainObservations dataset)
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
  putStrLn "Model alignment: linear Student-t regression over the exact standardized X/y exports used by Python's bayes_linear_student_t benchmark."
  putStrLn $ "Inference method: " ++ describeInferenceMethod method

  parameterSamples <- benchmarkModelWith method dataset

  let (skippedBurnIn, postBurnSamples) = splitAt burnInIterations parameterSamples
      actualBurnIn = length skippedBurnIn
  when (burnInIterations > 0 && actualBurnIn < burnInIterations && not (null parameterSamples)) $
    putStrLn $
      "Warning: only " ++ show actualBurnIn
      ++ " burn-in samples were available out of the requested "
      ++ show burnInIterations ++ "."

  let posteriorSampleList =
        case method of
          UseLWIS {} -> take (max 1 posteriorSamples) parameterSamples
          UseMH {}   -> take (max 1 posteriorSamples) postBurnSamples
      collectedSamples = length posteriorSampleList
      effectiveSamples =
        if null posteriorSampleList
          then [zeroParameters (length (featureNames dataset))]
          else posteriorSampleList
      meanParameters = averageParameters effectiveSamples
      validPredictions = predictSplit effectiveSamples (validObservations dataset)
      testPredictions = predictSplit effectiveSamples (testObservations dataset)

  putStrLn $ "Posterior samples used: " ++ show collectedSamples
  putStrLn $ "Posterior mean intercept: " ++ show (paramIntercept meanParameters)
  putStrLn $ "Posterior mean sigma: " ++ show (paramSigma meanParameters)
  printTopCoefficients (featureNames dataset) meanParameters

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


benchmarkModelWith :: BenchmarkInferenceMethod -> BenchmarkDataset -> IO [BenchmarkParameters]
benchmarkModelWith UseLWIS { lwisSampleCount } dataset =
  lwis (max 1 lwisSampleCount) (benchmarkModel dataset)
benchmarkModelWith UseMH { mhJitter } dataset = do
  samples <- mh mhJitter (benchmarkModel dataset)
  pure (map fst samples)


benchmarkModel :: BenchmarkDataset -> Meas BenchmarkParameters
benchmarkModel dataset = do
  intercept <- sample (normal 0.0 1.5)
  coeffs <- replicateM featureCount (sample (normal 0.0 1.0))
  sigmaRaw <- sample (normal 0.0 1.0)
  let sigma = max 1.0e-6 (abs sigmaRaw)
      params =
        BenchmarkParameters
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


predictSplit :: [BenchmarkParameters] -> [BenchmarkObservation] -> [BenchmarkPrediction]
predictSplit parameterSamples =
  parMap rdeepseq (predictObservation parameterSamples)


predictObservation :: [BenchmarkParameters] -> BenchmarkObservation -> BenchmarkPrediction
predictObservation parameterSamples BenchmarkObservation { observationLabel, predictorValues, observedTarget } =
  let draws = map (\params -> linearPredictor params predictorValues) parameterSamples
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
  "Metropolis-Hastings with jitter " ++ show mhJitter


describeRepresentation :: String -> String
describeRepresentation "sdf" =
  "sdf/3D structural descriptor matrix (the representation-advantaged path over SMILES)"
describeRepresentation "smiles" =
  "smiles-derived descriptor matrix"
describeRepresentation other = other


printTopCoefficients :: [String] -> BenchmarkParameters -> IO ()
printTopCoefficients names BenchmarkParameters { paramCoeffs } = do
  let ranked =
        take 8 $
          sortOn (Down . abs . snd) (zip names paramCoeffs)
  unless (null ranked) $ do
    putStrLn "Top posterior mean coefficients:"
    forM_ ranked $ \(name, coeff) ->
      putStrLn $ "  " ++ name ++ ": " ++ show coeff


averageParameters :: [BenchmarkParameters] -> BenchmarkParameters
averageParameters samples =
  let sampleCount = fromIntegral (length samples)
      interceptMean = meanDouble (map paramIntercept samples)
      sigmaMean = meanDouble (map paramSigma samples)
      coeffMeans =
        [ foldl' (\acc params -> acc + paramCoeffs params !! index) 0.0 samples / sampleCount
        | index <- [0 .. length (paramCoeffs (head samples)) - 1]
        ]
  in BenchmarkParameters
       { paramIntercept = interceptMean
       , paramCoeffs = coeffMeans
       , paramSigma = sigmaMean
       }


linearPredictor :: BenchmarkParameters -> [Double] -> Double
linearPredictor BenchmarkParameters { paramIntercept, paramCoeffs } xs =
  paramIntercept + sum (zipWith (*) paramCoeffs xs)


studentTLogPdf :: Double -> Double -> Double -> Double -> Double
studentTLogPdf nu mu sigma y =
  let z = (y - mu) / sigma
      a = logGamma ((nu + 1.0) / 2.0) - logGamma (nu / 2.0)
      b = -0.5 * log (nu * pi) - log sigma
      c = -((nu + 1.0) / 2.0) * log (1.0 + (z * z) / nu)
  in a + b + c


zeroParameters :: Int -> BenchmarkParameters
zeroParameters featureCount =
  BenchmarkParameters
    { paramIntercept = 0.0
    , paramCoeffs = replicate featureCount 0.0
    , paramSigma = 1.0
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
