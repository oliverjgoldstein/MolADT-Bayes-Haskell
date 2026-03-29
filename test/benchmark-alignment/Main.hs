module Main where

import BenchmarkModel
  ( defaultProcessedDataDir
  , featureNames
  , loadBenchmarkDataset
  , representationName
  , targetName
  , testObservations
  , trainObservations
  , validObservations
  )
import Test.Hspec


main :: IO ()
main = hspec $ do
  describe "Benchmark alignment" $ do
    it "loads the exported FreeSolv smiles matrix" $ do
      dataset <- loadBenchmarkDataset defaultProcessedDataDir "freesolv_smiles" (Just 8)
      length (featureNames dataset) `shouldSatisfy` (> 0)
      length (trainObservations dataset) `shouldBe` 8
      length (validObservations dataset) `shouldSatisfy` (> 0)
      length (testObservations dataset) `shouldSatisfy` (> 0)

    it "loads the exported QM9 sdf matrix" $ do
      dataset <- loadBenchmarkDataset defaultProcessedDataDir "qm9_sdf" (Just 8)
      representationName dataset `shouldBe` "sdf"
      targetName dataset `shouldBe` "mu"
