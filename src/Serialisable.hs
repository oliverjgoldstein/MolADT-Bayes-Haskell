-- | Simple binary serialisation helpers for molecules.  The module uses the
-- 'binary' package so that molecules can be persisted to disk or exchanged
-- between processes during experimentation.
module Serialisable where

import Chem.Molecule
import Chem.Dietz ()
import SampleMolecules (methane)
import Data.Binary (encodeFile, decodeFile)

-- | Write a molecule to disk using the 'Binary' instance derived from the
-- constituent data types.
writeMoleculeToFile :: FilePath -> Molecule -> IO ()
writeMoleculeToFile = encodeFile

-- | Read a molecule previously serialised with 'writeMoleculeToFile'.
readMoleculeFromFile :: FilePath -> IO Molecule
readMoleculeFromFile = decodeFile

-- | Minimal demonstration that writes and then reads back the methane
-- example molecule.
main :: IO ()
main = do
  -- Write the methane molecule to a file
  writeMoleculeToFile "methane.bin" methane

  -- Read the methane molecule from the file
  molecule <- readMoleculeFromFile "methane.bin"
  
  -- Print the molecule read from the file
  print molecule
