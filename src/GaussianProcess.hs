{-# LANGUAGE DeriveGeneric #-}

module GaussianProcess
  ( GaussianProcessParameters(..)
  , GaussianProcessSupport
  , defaultGaussianProcessFeatureCap
  , gaussianProcessFeatureNames
  , gaussianProcessLogLikelihood
  , predictGaussianProcess
  , prepareGaussianProcessSupport
  ) where

import Control.DeepSeq (NFData)
import Control.Monad (forM_, when)
import Control.Monad.ST (ST, runST)
import Data.List (sortOn, transpose)
import Data.Ord (Down(..))
import Data.STRef (newSTRef, readSTRef, writeSTRef)
import qualified Data.Vector as V
import qualified Data.Vector.Unboxed as U
import qualified Data.Vector.Unboxed.Mutable as MU
import GHC.Generics (Generic)


data GaussianProcessParameters = GaussianProcessParameters
  { gpMeanOffset  :: !Double
  , gpKernelScale :: !Double
  , gpLengthScale :: !Double
  , gpNoiseScale  :: !Double
  } deriving (Eq, Show, Generic)

instance NFData GaussianProcessParameters


data GaussianProcessSupport = GaussianProcessSupport
  { supportSelectedFeatureNames   :: ![String]
  , supportSelectedFeatureIndices :: ![Int]
  , supportTrainInputs            :: !(V.Vector (U.Vector Double))
  , supportTrainTargets           :: !(U.Vector Double)
  , supportInputDimension         :: !Int
  }


defaultGaussianProcessFeatureCap :: Int
defaultGaussianProcessFeatureCap = 24


gaussianProcessFeatureNames :: GaussianProcessSupport -> [String]
gaussianProcessFeatureNames = supportSelectedFeatureNames


prepareGaussianProcessSupport
  :: Int
  -> [String]
  -> [[Double]]
  -> [Double]
  -> GaussianProcessSupport
prepareGaussianProcessSupport requestedFeatureCap featureNames trainRows trainTargets =
  let featureCap = max 1 (min requestedFeatureCap (length featureNames))
      selectedFeatureIndices =
        take featureCap $
          map fst $
            sortOn (\(idx, score) -> (Down score, idx)) $
              zip [0 ..] (featureCorrelationScores trainRows trainTargets)
      selectedFeatureNames = map (featureNames !!) selectedFeatureIndices
      selectedTrainInputs =
        V.fromList $
          map (U.fromList . selectFeatures selectedFeatureIndices) trainRows
      selectedTrainTargets = U.fromList trainTargets
      inputDimension = max 1 (length selectedFeatureIndices)
  in GaussianProcessSupport
       { supportSelectedFeatureNames = selectedFeatureNames
       , supportSelectedFeatureIndices = selectedFeatureIndices
       , supportTrainInputs = selectedTrainInputs
       , supportTrainTargets = selectedTrainTargets
       , supportInputDimension = inputDimension
       }


gaussianProcessLogLikelihood :: GaussianProcessSupport -> GaussianProcessParameters -> Maybe Double
gaussianProcessLogLikelihood support params = do
  let trainCount = V.length (supportTrainInputs support)
      kernel = kernelTrainMatrix support params
      centeredTargets = centeredTrainTargets support params
  cholesky <- choleskyDecompose trainCount kernel
  let alpha = solveSymmetricPositiveDefinite trainCount cholesky centeredTargets
      quadraticTerm = dot centeredTargets alpha
      logDeterminant =
        2.0 * sum [log (matrixIndex trainCount cholesky i i) | i <- [0 .. trainCount - 1]]
      sampleCount = fromIntegral trainCount
      normalizer = sampleCount * log (2.0 * pi)
  pure (-0.5 * quadraticTerm - 0.5 * logDeterminant - 0.5 * normalizer)


predictGaussianProcess
  :: GaussianProcessSupport
  -> [GaussianProcessParameters]
  -> [[Double]]
  -> [(Double, Double)]
predictGaussianProcess _ [] testRows =
  replicate (length testRows) (0.0, 1.0)
predictGaussianProcess support parameterSamples testRows
  | null testRows = []
  | otherwise =
      let testInputs =
            V.fromList $
              map (U.fromList . selectFeatures (supportSelectedFeatureIndices support)) testRows
          perSample =
            [ prediction
            | params <- parameterSamples
            , Just prediction <- [predictGaussianProcessSample support params testInputs]
            ]
      in if null perSample
           then replicate (length testRows) (0.0, 1.0)
           else aggregatePredictions perSample


predictGaussianProcessSample
  :: GaussianProcessSupport
  -> GaussianProcessParameters
  -> V.Vector (U.Vector Double)
  -> Maybe ([Double], [Double])
predictGaussianProcessSample support params testInputs = do
  let trainInputs = supportTrainInputs support
      trainCount = V.length trainInputs
      centeredTargets = centeredTrainTargets support params
      kernel = kernelTrainMatrix support params
      kernelVariance = gpKernelScale params * gpKernelScale params
      noiseVariance = gpNoiseScale params * gpNoiseScale params
  cholesky <- choleskyDecompose trainCount kernel
  let alpha = solveSymmetricPositiveDefinite trainCount cholesky centeredTargets
      predictOne testInput =
        let kStar =
              U.generate trainCount (\i -> rbfKernel params (trainInputs V.! i) testInput)
            meanValue = gpMeanOffset params + dot kStar alpha
            forwardValue = forwardSubstitute trainCount cholesky kStar
            latentVariance = max minimumVariance (kernelVariance - dot forwardValue forwardValue)
            observedVariance = max minimumVariance (latentVariance + noiseVariance)
        in (meanValue, observedVariance)
      (means, variances) = unzip (map predictOne (V.toList testInputs))
  pure (means, variances)


aggregatePredictions :: [([Double], [Double])] -> [(Double, Double)]
aggregatePredictions samplePredictions =
  let groupedMeans = transpose (map fst samplePredictions)
      groupedVariances = transpose (map snd samplePredictions)
  in zipWith aggregateOne groupedMeans groupedVariances
  where
    aggregateOne means variances =
      let meanValue = average means
          secondMoment =
            average (zipWith (\mu variance -> variance + mu * mu) means variances)
          varianceValue = max minimumVariance (secondMoment - meanValue * meanValue)
      in (meanValue, sqrt varianceValue)


kernelTrainMatrix :: GaussianProcessSupport -> GaussianProcessParameters -> U.Vector Double
kernelTrainMatrix support params =
  let trainInputs = supportTrainInputs support
      trainCount = V.length trainInputs
      ridge = gpNoiseScale params * gpNoiseScale params + kernelJitter
  in U.generate (trainCount * trainCount) $ \flatIndex ->
       let (rowIndex, colIndex) = flatIndex `divMod` trainCount
           baseKernel = rbfKernel params (trainInputs V.! rowIndex) (trainInputs V.! colIndex)
       in if rowIndex == colIndex then baseKernel + ridge else baseKernel


rbfKernel :: GaussianProcessParameters -> U.Vector Double -> U.Vector Double -> Double
rbfKernel params xs ys =
  let lengthScale = max minimumLengthScale (gpLengthScale params)
      varianceScale = gpKernelScale params * gpKernelScale params
      squaredDistance = normalizedSquaredDistance xs ys
  in varianceScale * exp (negate squaredDistance / (2.0 * lengthScale * lengthScale))


normalizedSquaredDistance :: U.Vector Double -> U.Vector Double -> Double
normalizedSquaredDistance xs ys =
  let featureCount = max 1 (U.length xs)
      squaredDifference =
        U.sum $
          U.zipWith
            (\x y ->
               let delta = x - y
               in delta * delta
            )
            xs
            ys
  in squaredDifference / fromIntegral featureCount


centeredTrainTargets :: GaussianProcessSupport -> GaussianProcessParameters -> U.Vector Double
centeredTrainTargets support params =
  U.map (\y -> y - gpMeanOffset params) (supportTrainTargets support)


featureCorrelationScores :: [[Double]] -> [Double] -> [Double]
featureCorrelationScores [] _ = []
featureCorrelationScores trainRows trainTargets =
  map (abs . pearsonCorrelation trainTargets) (transpose trainRows)


pearsonCorrelation :: [Double] -> [Double] -> Double
pearsonCorrelation xs ys
  | length xs /= length ys = 0.0
  | denominator <= 0.0 = 0.0
  | otherwise = numerator / denominator
  where
    meanX = average xs
    meanY = average ys
    centeredProducts = zipWith (\x y -> (x - meanX) * (y - meanY)) xs ys
    squaredX = map (\x -> let delta = x - meanX in delta * delta) xs
    squaredY = map (\y -> let delta = y - meanY in delta * delta) ys
    numerator = sum centeredProducts
    denominator = sqrt (sum squaredX * sum squaredY)


selectFeatures :: [Int] -> [Double] -> [Double]
selectFeatures indices row = map (row !!) indices


average :: [Double] -> Double
average [] = 0.0
average values = sum values / fromIntegral (length values)


dot :: U.Vector Double -> U.Vector Double -> Double
dot xs ys = U.sum (U.zipWith (*) xs ys)


solveSymmetricPositiveDefinite
  :: Int
  -> U.Vector Double
  -> U.Vector Double
  -> U.Vector Double
solveSymmetricPositiveDefinite matrixSize cholesky rhs =
  let forwardValue = forwardSubstitute matrixSize cholesky rhs
  in backwardSubstitute matrixSize cholesky forwardValue


forwardSubstitute :: Int -> U.Vector Double -> U.Vector Double -> U.Vector Double
forwardSubstitute matrixSize lowerTriangular rhs =
  runST $ do
    solution <- MU.replicate matrixSize 0.0
    forM_ [0 .. matrixSize - 1] $ \rowIndex -> do
      partialSum <-
        sumMutable
          [ do solutionEntry <- MU.read solution colIndex
               pure (matrixIndex matrixSize lowerTriangular rowIndex colIndex * solutionEntry)
          | colIndex <- [0 .. rowIndex - 1]
          ]
      let diagonalEntry = matrixIndex matrixSize lowerTriangular rowIndex rowIndex
          rhsEntry = rhs U.! rowIndex
          solutionEntry = (rhsEntry - partialSum) / diagonalEntry
      MU.write solution rowIndex solutionEntry
    U.unsafeFreeze solution


backwardSubstitute :: Int -> U.Vector Double -> U.Vector Double -> U.Vector Double
backwardSubstitute matrixSize lowerTriangular rhs =
  runST $ do
    solution <- MU.replicate matrixSize 0.0
    forM_ (reverse [0 .. matrixSize - 1]) $ \rowIndex -> do
      partialSum <-
        sumMutable
          [ do solutionEntry <- MU.read solution colIndex
               pure (matrixIndex matrixSize lowerTriangular colIndex rowIndex * solutionEntry)
          | colIndex <- [rowIndex + 1 .. matrixSize - 1]
          ]
      let diagonalEntry = matrixIndex matrixSize lowerTriangular rowIndex rowIndex
          rhsEntry = rhs U.! rowIndex
          solutionEntry = (rhsEntry - partialSum) / diagonalEntry
      MU.write solution rowIndex solutionEntry
    U.unsafeFreeze solution


choleskyDecompose :: Int -> U.Vector Double -> Maybe (U.Vector Double)
choleskyDecompose matrixSize inputMatrix =
  runST $ do
    lowerTriangular <- MU.replicate (matrixSize * matrixSize) 0.0
    failureFlag <- newSTRef False
    forM_ [0 .. matrixSize - 1] $ \colIndex -> do
      failedAlready <- readSTRef failureFlag
      when (not failedAlready) $ do
        diagonalReduction <-
          sumMutable
            [ do value <- mutableIndex matrixSize lowerTriangular colIndex innerIndex
                 pure (value * value)
            | innerIndex <- [0 .. colIndex - 1]
            ]
        let diagonalCandidate =
              matrixIndex matrixSize inputMatrix colIndex colIndex - diagonalReduction
        if diagonalCandidate <= minimumVariance
          then writeSTRef failureFlag True
          else do
            let diagonalEntry = sqrt diagonalCandidate
            MU.write lowerTriangular (flatIndex matrixSize colIndex colIndex) diagonalEntry
            forM_ [colIndex + 1 .. matrixSize - 1] $ \rowIndex -> do
              offDiagonalReduction <-
                sumMutable
                  [ do rowValue <- mutableIndex matrixSize lowerTriangular rowIndex innerIndex
                       colValue <- mutableIndex matrixSize lowerTriangular colIndex innerIndex
                       pure (rowValue * colValue)
                  | innerIndex <- [0 .. colIndex - 1]
                  ]
              let numerator =
                    matrixIndex matrixSize inputMatrix rowIndex colIndex - offDiagonalReduction
                  offDiagonalEntry = numerator / diagonalEntry
              MU.write lowerTriangular (flatIndex matrixSize rowIndex colIndex) offDiagonalEntry
    didFail <- readSTRef failureFlag
    if didFail
      then pure Nothing
      else Just <$> U.unsafeFreeze lowerTriangular


sumMutable :: [ST s Double] -> ST s Double
sumMutable = foldl step (pure 0.0)
  where
    step acc action = do
      total <- acc
      value <- action
      pure (total + value)


mutableIndex :: Int -> MU.MVector s Double -> Int -> Int -> ST s Double
mutableIndex matrixSize matrix rowIndex colIndex =
  MU.read matrix (flatIndex matrixSize rowIndex colIndex)


matrixIndex :: Int -> U.Vector Double -> Int -> Int -> Double
matrixIndex matrixSize matrix rowIndex colIndex =
  matrix U.! flatIndex matrixSize rowIndex colIndex


flatIndex :: Int -> Int -> Int -> Int
flatIndex matrixSize rowIndex colIndex =
  rowIndex * matrixSize + colIndex


kernelJitter :: Double
kernelJitter = 1.0e-6


minimumLengthScale :: Double
minimumLengthScale = 1.0e-3


minimumVariance :: Double
minimumVariance = 1.0e-8
