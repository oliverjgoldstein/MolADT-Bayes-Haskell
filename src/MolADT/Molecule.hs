-- | Lightweight façade re-exporting the primary molecule type and printer used
-- by the curated examples.
module MolADT.Molecule
  ( Molecule
  , prettyPrintMolecule
  ) where

import Chem.Molecule (Molecule, prettyPrintMolecule)
