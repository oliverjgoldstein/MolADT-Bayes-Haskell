-- | Demonstrate serialising and deserialising molecules using the curated API.
module Main where

import MolADT.Molecule (prettyPrintMolecule)
import MolADT.Samples (methane)
import MolADT.Serialization (readMoleculeFromFile, writeMoleculeToFile)

main :: IO ()
main = do
  let filePath = "methane.bin"
  putStrLn $ "Writing methane to " ++ filePath
  writeMoleculeToFile filePath methane

  putStrLn $ "Reading " ++ filePath ++ " back into memory"
  molecule <- readMoleculeFromFile filePath
  putStrLn "Recovered molecule:"
  putStrLn (prettyPrintMolecule molecule)
