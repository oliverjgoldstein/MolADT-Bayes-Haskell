{-# LANGUAGE OverloadedStrings #-}

-- | Hspec regression tests ensuring the SDF parser is (mostly) reversible and
-- detects aromatic systems in the benzene example.
module Main (main) where

import Test.Hspec
import Chem.IO.SDF (readSDF, parseSDF)
import Chem.Molecule
import Chem.Dietz
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import Text.Megaparsec (errorBundlePretty)
import Control.Monad.Trans.Writer (runWriterT)
import Data.Monoid (Product(..))
import Distr (normalPdf)
import LazyPPL (Meas(..), Tree(..), runProb)
import LogPModel (LogPParameters, inferLogP, predictMolecule)
import Numeric.Log (Log, ln)
import SampleMolecules (methane, water)

-- | Run the Hspec suite defined in 'spec'.
main :: IO ()
main = hspec spec

-- | Group the parser round-trip tests.
spec :: Spec
spec = do
  describe "SDF round-trip" $ do
    it "preserves atom count and sigma adjacency" $ do
      parsed <- readSDF "molecules/benzene.sdf"
      case parsed of
        Left err -> expectationFailure (errorBundlePretty err)
        Right mol -> do
          let sdf = moleculeToSDF mol
          case parseSDF sdf of
            Left err -> expectationFailure (errorBundlePretty err)
            Right mol' -> do
              M.size (atoms mol') `shouldBe` M.size (atoms mol)
              localBonds mol' `shouldBe` localBonds mol

    it "detects one pi bonding system in benzene" $ do
      parsed <- readSDF "molecules/benzene.sdf"
      case parsed of
        Left err -> expectationFailure (errorBundlePretty err)
        Right mol -> length (systems mol) `shouldBe` 1

  describe "LogPModel inference" $ do
    it "uses a single coefficient sample for the entire dataset" $ do
      let datasetOne = [(water, 0.0)]
          datasetTwo = [(water, 0.0), (methane, 0.5)]
          tree = constantTree 0.42
          (paramsOne, weightOne) = runInference tree datasetOne
          (paramsTwo, weightTwo) = runInference tree datasetTwo
          predictedWater         = predictMolecule paramsOne water
          predictedMethane       = predictMolecule paramsTwo methane
          pdfWater               = normalPdf 0.0 0.2 predictedWater
          pdfMethane             = normalPdf 0.5 0.2 predictedMethane
          logWeightOne           = ln weightOne
          logWeightTwo           = ln weightTwo
          logPdfWater            = log pdfWater
          logPdfMethane          = log pdfMethane
          tolerance              = 1e-9
      paramsTwo `shouldBe` paramsOne
      abs (logWeightOne - logPdfWater) `shouldSatisfy` (< tolerance)
      abs (logWeightTwo - (logPdfWater + logPdfMethane)) `shouldSatisfy` (< tolerance)

-- | Minimal V2000 writer sufficient for round-trip testing.
moleculeToSDF :: Molecule -> String
moleculeToSDF m = unlines $ header ++ atomLines ++ bondLines ++ ["M  END"]
  where
    nAtoms = M.size (atoms m)
    nBonds = S.size (localBonds m)
    header = ["", "", "", countLine]
    countLine = unwords [show nAtoms, show nBonds, "0 0 0 0 0 0 0 0 0 0 0 0"]
    atomLines = map formatAtom (map snd (M.toAscList (atoms m)))
    formatAtom a =
      let Coordinate x y z = coordinate a
          sym = show (symbol (attributes a))
      in unwords [show (unAngstrom x), show (unAngstrom y), show (unAngstrom z), sym, "0"]
    bondLines = map formatBond (S.toList (localBonds m))
    formatBond (Edge (AtomId i) (AtomId j)) = unwords [show i, show j, "1"]

-- | Deterministic infinite tree returning the same pseudo-random value at each node.
constantTree :: Double -> Tree
constantTree x = tree where tree = Tree x (repeat tree)

-- | Evaluate 'inferLogP' once using a fixed randomness tree.
runInference :: Tree -> [(Molecule, Double)] -> (LogPParameters, Log Double)
runInference tree observations =
  let Meas program       = inferLogP observations
      (params, weightM)  = runProb (runWriterT program) tree
  in (params, getProduct weightM)
