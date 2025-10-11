-- | Simple binary serialisation helpers for molecules.  The module uses the
-- 'binary' package so that molecules can be persisted to disk or exchanged
-- between processes during experimentation.
module Serialisable
  ( writeMoleculeToFile
  , readMoleculeFromFile
  ) where

import Chem.Molecule (Molecule)
import Chem.Dietz ()
import Data.Binary (decodeFile, encodeFile)

-- | Write a molecule to disk using the 'Binary' instance derived from the
-- constituent data types.
writeMoleculeToFile :: FilePath -> Molecule -> IO ()
writeMoleculeToFile = encodeFile

-- | Read a molecule previously serialised with 'writeMoleculeToFile'.
readMoleculeFromFile :: FilePath -> IO Molecule
readMoleculeFromFile = decodeFile
