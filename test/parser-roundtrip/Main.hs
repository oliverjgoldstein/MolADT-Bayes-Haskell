{-# LANGUAGE OverloadedStrings #-}

-- | Hspec regression tests ensuring the SDF parser is (mostly) reversible and
-- detects aromatic systems in the benzene example.
module Main (main) where

import Test.Hspec
import Chem.IO.SDF (readSDF, parseSDF)
import Chem.IO.SMILES (moleculeToSMILES, parseSMILES)
import Chem.Molecule
import Chem.Dietz
import Chem.Validate (validateMolecule)
import ExampleMolecules.Morphine (morphinePretty, morphineRingClosureSmiles)
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import Text.Megaparsec (errorBundlePretty)
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

  describe "SMILES boundary" $ do
    it "recovers a pi ring from aromatic benzene SMILES" $ do
      case parseSMILES "c1ccccc1" of
        Left err -> expectationFailure err
        Right mol -> do
          countSymbol C mol `shouldBe` 6
          countSymbol H mol `shouldBe` 6
          S.size (localBonds mol) `shouldBe` 12
          length (systems mol) `shouldBe` 1

    it "infers terminal hydrogens for bare methane and water SMILES" $ do
      case parseSMILES "C" of
        Left err -> expectationFailure err
        Right methaneMol -> do
          countSymbol C methaneMol `shouldBe` 1
          countSymbol H methaneMol `shouldBe` 4
          S.size (localBonds methaneMol) `shouldBe` 4
      case parseSMILES "O" of
        Left err -> expectationFailure err
        Right waterMol -> do
          countSymbol O waterMol `shouldBe` 1
          countSymbol H waterMol `shouldBe` 2
          S.size (localBonds waterMol) `shouldBe` 2

    it "does not add extra implicit hydrogens to bracket atoms" $ do
      case parseSMILES "[O]" of
        Left err -> expectationFailure err
        Right radicalOxygen -> do
          countSymbol O radicalOxygen `shouldBe` 1
          countSymbol H radicalOxygen `shouldBe` 0
          S.size (localBonds radicalOxygen) `shouldBe` 0

    it "renders water as bracketed SMILES and parses it back" $ do
      case moleculeToSMILES water of
        Left err -> expectationFailure err
        Right smilesText -> do
          smilesText `shouldBe` "[OH2]"
          case parseSMILES smilesText of
            Left err -> expectationFailure err
            Right mol -> do
              M.size (atoms mol) `shouldBe` 3
              S.size (localBonds mol) `shouldBe` 2

    it "renders methane as bracketed SMILES and parses it back" $ do
      case moleculeToSMILES methane of
        Left err -> expectationFailure err
        Right smilesText -> do
          smilesText `shouldBe` "[CH4]"
          case parseSMILES smilesText of
            Left err -> expectationFailure err
            Right mol -> do
              M.size (atoms mol) `shouldBe` 5
              S.size (localBonds mol) `shouldBe` 4

    it "renders benzene as a deterministic Kekule string and preserves localized double bonds on parse-back" $ do
      parsed <- readSDF "molecules/benzene.sdf"
      case parsed of
        Left err -> expectationFailure (errorBundlePretty err)
        Right mol ->
          case moleculeToSMILES mol of
            Left err -> expectationFailure err
            Right smilesText -> do
              smilesText `shouldBe` "[CH]1=[CH][CH]=[CH][CH]=[CH]1"
              case parseSMILES smilesText of
                Left err -> expectationFailure err
                Right mol' -> do
                  countSymbol C mol' `shouldBe` 6
                  countSymbol H mol' `shouldBe` 6
                  S.size (localBonds mol') `shouldBe` 12
                  length (systems mol') `shouldBe` 3
                  map (tag . snd) (systems mol') `shouldBe` [Nothing, Nothing, Nothing]

    it "records atom-centered stereochemistry from chiral bracket atoms" $ do
      case parseSMILES "N[C@](Br)(O)C" of
        Left err -> expectationFailure err
        Right mol -> do
          let annotations = atomStereoAnnotations (smilesStereochemistry mol)
          length annotations `shouldBe` 1
          stereoClass (head annotations) `shouldBe` StereoTetrahedral
          stereoConfiguration (head annotations) `shouldBe` 1
          stereoToken (head annotations) `shouldBe` "@"

    it "records directional bond annotations for alkene stereochemistry" $ do
      case parseSMILES "F/C=C\\F" of
        Left err -> expectationFailure err
        Right mol -> do
          let annotations = bondStereoAnnotations (smilesStereochemistry mol)
          length annotations `shouldBe` 2
          map bondStereoDirection annotations `shouldBe` [BondUp, BondDown]

    it "accepts silicon-containing SMILES used in the ZINC slice" $ do
      case parseSMILES "C[Si](C)(C)C" of
        Left err -> expectationFailure err
        Right mol -> do
          countSymbol Si mol `shouldBe` 1

    it "parses the documented morphine ring-closure boundary string" $ do
      case parseSMILES morphineRingClosureSmiles of
        Left err -> expectationFailure err
        Right mol -> do
          countSymbol C mol `shouldBe` 17
          countSymbol H mol `shouldBe` 19
          countSymbol N mol `shouldBe` 1
          countSymbol O mol `shouldBe` 3
          S.size (localBonds mol) `shouldBe` 44
          map (tag . snd) (systems mol) `shouldBe` [Nothing, Just "pi_ring"]

    it "parses a real ZINC entry even where the current validator is still too strict" $ do
      case parseSMILES "CC1(C)CN(C(=O)Nc2cc3ccccc3nn2)C[C@@]2(CCOC2)O1" of
        Left err -> expectationFailure err
        Right mol -> do
          countSymbol C mol `shouldSatisfy` (> 0)

  describe "Built-in Dietz examples" $ do
    it "validates the explicit morphine example and preserves both systems" $ do
      case validateMolecule morphinePretty of
        Left err -> expectationFailure err
        Right mol -> do
          S.size (localBonds mol) `shouldBe` 25
          map (tag . snd) (systems mol) `shouldBe` [Just "alkene_bridge", Just "phenyl_pi_ring"]

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

countSymbol :: AtomicSymbol -> Molecule -> Int
countSymbol sym mol =
  length
    [ ()
    | atom <- M.elems (atoms mol)
    , symbol (attributes atom) == sym
    ]
