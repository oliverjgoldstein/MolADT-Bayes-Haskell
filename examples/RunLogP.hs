-- | End-to-end example that parses, validates and prints a couple of molecules
-- before running the logP regression demo from the curated MolADT API.
module Main where

import MolADT.LogP (LogPInferenceMethod(..), runLogPRegressionWith)
import MolADT.Molecule (Molecule, prettyPrintMolecule)
import MolADT.Parse (readSDF)
import MolADT.Validate (validateMolecule)

import Text.Megaparsec (errorBundlePretty)
import Text.Read (readMaybe)

-- | Read a numeric property from an SDF file by name.  The parser is
-- intentionally lightweight since the demo files are tiny and only a handful
-- of properties are needed.
readSDFDoubleProperty :: FilePath -> String -> IO (Maybe Double)
readSDFDoubleProperty fp propName = do
  contents <- readFile fp
  let target = "> <" ++ propName ++ ">"
      ls     = lines contents
  pure $ case dropWhile (/= target) ls of
           (_:val:_) -> readMaybe val
           _         -> Nothing

-- | Parse an SDF file, validate the resulting molecule and pretty-print it.
processMolecule :: FilePath -> IO (Maybe Molecule)
processMolecule fp = do
  parsed <- readSDF fp
  case parsed of
    Left err -> do
      putStrLn (errorBundlePretty err)
      pure Nothing
    Right mol ->
      case validateMolecule mol of
        Left validationError -> do
          putStrLn ("Validation error in " ++ fp ++ ":")
          putStrLn validationError
          pure Nothing
        Right _ -> do
          putStrLn (prettyPrintMolecule mol)
          pure (Just mol)

main :: IO ()
main = do
  putStrLn "Parsing molecules/benzene.sdf"
  benzene <- processMolecule "molecules/benzene.sdf"
  benzeneActualLogP <- readSDFDoubleProperty "molecules/benzene.sdf" "PUBCHEM_XLOGP3"

  putStrLn "\nParsing molecules/water.sdf"
  water <- processMolecule "molecules/water.sdf"

  case (benzene, water) of
    (Just benzeneMol, Just waterMol) -> do
      putStrLn "\nRunning LogP regression over DB1 and predicting for water and DB2 (LWIS):"
      let trackedMolecules =
            [ ("Benzene", benzeneMol, benzeneActualLogP)
            , ("Water", waterMol, Nothing)
            ]
          lwisMethod = UseLWIS 2000
          mhMethod   = UseMH 0.9
      runLogPRegressionWith lwisMethod trackedMolecules
      putStrLn "\nRunning LogP regression over DB1 and predicting for water and DB2 (MH):"
      runLogPRegressionWith mhMethod trackedMolecules
    _ ->
      putStrLn "Skipping regression because parsing or validation failed."
