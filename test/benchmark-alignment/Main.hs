module Main where

import BenchmarkModel
  ( defaultProcessedDataDir
  , featureNames
  , loadBenchmarkDataset
  , representationName
  , testObservations
  , trainObservations
  , validObservations
  )
import Chem.Molecule (atoms)
import Chem.Validate (validateMolecule)
import FreeSolvInverseDesign
  ( Candidate(..)
  , InverseDesignConfig(..)
  , Prediction(..)
  , defaultInverseDesignConfig
  , formatDietzMolecule
  , resultTopCandidates
  , runInverseDesignWithPredictor
  )
import Test.Hspec
import Data.Either (isRight)


main :: IO ()
main = hspec $ do
  describe "Benchmark alignment" $ do
    it "loads the exported FreeSolv MolADT featurized matrix" $ do
      dataset <- loadBenchmarkDataset defaultProcessedDataDir "freesolv_moladt_featurized" (Just 8)
      length (featureNames dataset) `shouldSatisfy` (> 0)
      representationName dataset `shouldBe` "moladt_featurized"
      length (trainObservations dataset) `shouldBe` 8
      length (validObservations dataset) `shouldSatisfy` (> 0)
      length (testObservations dataset) `shouldSatisfy` (> 0)

    it "runs a validator-backed inverse-design smoke search with a toy predictor" $ do
      let config =
            defaultInverseDesignConfig
              { configTarget = Just (-5.0)
              , configSteps = 12
              , configSeeds = 1
              , configTopK = 3
              , configWriteResults = False
              }
          toyPredictor molecule =
            Prediction
              { predictionMean = negate (fromIntegral (length (atoms molecule)))
              , predictionSd = 1.0
              }
          result = runInverseDesignWithPredictor config toyPredictor
          candidates = resultTopCandidates result
      candidates `shouldSatisfy` (not . null)
      mapM_ (\candidate -> validateMolecule (candidateMolecule candidate) `shouldSatisfy` isRight) candidates
      formatDietzMolecule (candidateMolecule (head candidates)) `shouldContain` "local_bonds"
