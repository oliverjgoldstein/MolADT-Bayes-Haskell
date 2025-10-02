-- | Standalone example showing how to parse and validate molecules from SDF
-- files before pretty-printing them.
module Main where

import Chem.IO.SDF (readSDF)

import Chem.Molecule (prettyPrintMolecule)
import Chem.Dietz ()
import Text.Megaparsec (errorBundlePretty)
import Chem.Validate (validateMolecule, ValidationWarning(..))

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
            Left errs -> do
              putStrLn "Benzene invalid:"
              mapM_ (putStrLn . show) errs
            Right (_, warns) -> do
              mapM_ (putStrLn . ("Warning: " ++) . show) warns
              putStrLn $ prettyPrintMolecule mol

    putStrLn "\nParsing water.sdf"
    water <- readSDF "molecules/water.sdf"
    case water of
        Left err -> putStrLn $ errorBundlePretty err
        Right mol ->
          case validateMolecule mol of
            Left errs -> do
              putStrLn "Water invalid:"
              mapM_ (putStrLn . show) errs
            Right (_, warns) -> do
              mapM_ (putStrLn . ("Warning: " ++) . show) warns
              putStrLn $ prettyPrintMolecule mol
