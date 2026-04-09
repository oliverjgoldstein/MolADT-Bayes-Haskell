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
    it "loads the exported FreeSolv MolADT matrix" $ do
      dataset <- loadBenchmarkDataset defaultProcessedDataDir "freesolv_moladt" (Just 8)
      length (featureNames dataset) `shouldSatisfy` (> 0)
      representationName dataset `shouldBe` "moladt"
      length (trainObservations dataset) `shouldBe` 8
      length (validObservations dataset) `shouldSatisfy` (> 0)
      length (testObservations dataset) `shouldSatisfy` (> 0)

    it "loads the exported QM9 MolADT matrix" $ do
      dataset <- loadBenchmarkDataset defaultProcessedDataDir "qm9_moladt" (Just 8)
      representationName dataset `shouldBe` "moladt"
      targetName dataset `shouldBe` "mu"
