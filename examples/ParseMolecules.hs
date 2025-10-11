-- | Standalone example showing how to parse and validate molecules from SDF
-- files before pretty-printing them.
module Main where

import MolADT.Molecule (prettyPrintMolecule)
import MolADT.Parse (readSDF)
import MolADT.Validate (validateMolecule)

import Text.Megaparsec (errorBundlePretty)

-- | Parse and validate the provided benzene and water SDF files, printing any
-- warnings emitted by the validator before rendering the molecules.
main :: IO ()
main = do
    putStrLn "Parsing benzene.sdf"
    benzene <- readSDF "molecules/benzene.sdf"
    case benzene of
        Left err -> putStrLn $ errorBundlePretty err
        Right mol ->
          case validateMolecule mol of
            Left err -> do
              putStrLn "Benzene invalid:"
              putStrLn err
            Right _ ->
              putStrLn $ prettyPrintMolecule mol

    putStrLn "\nParsing water.sdf"
    water <- readSDF "molecules/water.sdf"
    case water of
        Left err -> putStrLn $ errorBundlePretty err
        Right mol ->
          case validateMolecule mol of
            Left err -> do
              putStrLn "Water invalid:"
              putStrLn err
            Right _ ->
              putStrLn $ prettyPrintMolecule mol
