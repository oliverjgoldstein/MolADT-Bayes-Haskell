-- | Convenience wrappers for persisting molecules using the library 'Binary'
-- instances.
module MolADT.Serialization
  ( writeMoleculeToFile
  , readMoleculeFromFile
  ) where

import Serialisable (readMoleculeFromFile, writeMoleculeToFile)
