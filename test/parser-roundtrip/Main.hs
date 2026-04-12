{-# LANGUAGE OverloadedStrings #-}

-- | Hspec regression tests ensuring the SDF parser is (mostly) reversible and
-- detects aromatic systems in the benzene example.
module Main (main) where

import Test.Hspec
import Chem.IO.SDF (readSDF, parseSDF, parseSDFRecords)
import Chem.IO.SMILES (moleculeToSMILES, parseSMILES)
import Chem.IO.SMILESTiming (measureSmilesCsvTiming, timingFailureCount, timingStage, timingSuccessCount)
import Chem.Molecule
import Chem.Dietz
import Chem.Validate (validateMolecule)
import ExampleMolecules.Morphine (morphinePretty, morphineRingClosureSmiles)
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO (hClose, hPutStr, openTempFile)
import Text.Megaparsec (errorBundlePretty)
import SampleMolecules (methane, water)

v3000Water :: String
v3000Water = unlines
  [ "water"
  , "MolADT"
  , "generated"
  , "  0  0  0  0  0  0            999 V3000"
  , "M  V30 BEGIN CTAB"
  , "M  V30 COUNTS 3 2 0 0 0"
  , "M  V30 BEGIN ATOM"
  , "M  V30 1 O 0.0000 0.0000 0.0000 0"
  , "M  V30 2 H 0.9572 0.0000 0.0000 0"
  , "M  V30 3 H -0.2390 0.9270 0.0000 0"
  , "M  V30 END ATOM"
  , "M  V30 BEGIN BOND"
  , "M  V30 1 1 1 2"
  , "M  V30 2 1 1 3"
  , "M  V30 END BOND"
  , "M  V30 END CTAB"
  , "M  END"
  , "$$$$"
  ]

v3000Ammonium :: String
v3000Ammonium = unlines
  [ "ammonium"
  , "MolADT"
  , "generated"
  , "  0  0  0  0  0  0            999 V3000"
  , "M  V30 BEGIN CTAB"
  , "M  V30 COUNTS 5 4 0 0 0"
  , "M  V30 BEGIN ATOM"
  , "M  V30 1 N 0.0000 0.0000 0.0000 0 CHG=1"
  , "M  V30 2 H 0.9000 0.0000 0.0000 0"
  , "M  V30 3 H -0.3000 0.8500 0.0000 0"
  , "M  V30 4 H -0.3000 -0.4000 0.8000 0"
  , "M  V30 5 H -0.3000 -0.4000 -0.8000 0"
  , "M  V30 END ATOM"
  , "M  V30 BEGIN BOND"
  , "M  V30 1 1 1 2"
  , "M  V30 2 1 1 3"
  , "M  V30 3 1 1 4"
  , "M  V30 4 1 1 5"
  , "M  V30 END BOND"
  , "M  V30 END CTAB"
  , "M  END"
  , "$$$$"
  ]

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

    it "parses the core V3000 atom and bond blocks" $
      case parseSDF v3000Water of
        Left err -> expectationFailure (errorBundlePretty err)
        Right mol -> do
          M.size (atoms mol) `shouldBe` 3
          S.size (localBonds mol) `shouldBe` 2

    it "reads V3000 CHG tokens into formal charges" $
      case parseSDF v3000Ammonium of
        Left err -> expectationFailure (errorBundlePretty err)
        Right mol ->
          fmap formalCharge (M.lookup (AtomId 1) (atoms mol)) `shouldBe` Just 1

    it "parses multiple SDF records from one payload" $
      case parseSDFRecords (v3000Water ++ v3000Ammonium) of
        Left err -> expectationFailure (errorBundlePretty err)
        Right molecules -> do
          length molecules `shouldBe` 2
          M.size (atoms (head molecules)) `shouldBe` 3
          M.size (atoms (last molecules)) `shouldBe` 5

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
          map (tag . snd) (systems mol) `shouldBe` [Nothing, Nothing, Nothing, Nothing]
          map
            (\item -> (stereoCenter item, stereoClass item, stereoConfiguration item, stereoToken item))
            (atomStereoAnnotations (smilesStereochemistry mol))
            `shouldBe`
              [ (AtomId 5, StereoTetrahedral, 1, "@")
              , (AtomId 14, StereoTetrahedral, 1, "@")
              , (AtomId 16, StereoTetrahedral, 2, "@@")
              , (AtomId 21, StereoTetrahedral, 1, "@")
              , (AtomId 23, StereoTetrahedral, 1, "@")
              ]

    it "parses a real ZINC entry even where the current validator is still too strict" $ do
      case parseSMILES "CC1(C)CN(C(=O)Nc2cc3ccccc3nn2)C[C@@]2(CCOC2)O1" of
        Left err -> expectationFailure err
        Right mol -> do
          countSymbol C mol `shouldSatisfy` (> 0)

    it "times CSV field materialization separately from MolADT parsing" $ do
      tempDir <- getTemporaryDirectory
      (path, handle) <- openTempFile tempDir "moladt-smiles-timing.csv"
      hPutStr handle "smiles,name\nCCO,ethanol\nc1ccccc1,benzene\n"
      hClose handle
      result <- measureSmilesCsvTiming path (Just 2)
      removeFile path
      case result of
        Left err -> expectationFailure err
        Right stages -> do
          map timingStage stages `shouldBe` ["smiles_csv_string_parse", "smiles_adt_parse"]
          map timingSuccessCount stages `shouldBe` [2, 2]
          map timingFailureCount stages `shouldBe` [0, 0]

  describe "Built-in Dietz examples" $ do
    it "validates the explicit morphine example and preserves both systems" $ do
      case validateMolecule morphinePretty of
        Left err -> expectationFailure err
        Right mol -> do
          S.size (localBonds mol) `shouldBe` 25
          map (tag . snd) (systems mol) `shouldBe` [Just "alkene_bridge", Just "phenyl_pi_ring"]
          map
            (\item -> (stereoCenter item, stereoClass item, stereoConfiguration item, stereoToken item))
            (atomStereoAnnotations (smilesStereochemistry mol))
            `shouldBe`
              [ (AtomId 2, StereoTetrahedral, 1, "@")
              , (AtomId 3, StereoTetrahedral, 2, "@@")
              , (AtomId 7, StereoTetrahedral, 1, "@")
              , (AtomId 8, StereoTetrahedral, 1, "@")
              , (AtomId 18, StereoTetrahedral, 1, "@")
              ]

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
