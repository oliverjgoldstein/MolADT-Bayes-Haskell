-- | Convenience wrapper exposing the pedagogical benzene example under a
-- more descriptive name.  Re-exports the geometry defined in
-- 'ExampleMolecules.BenzenePretty.benzenePretty'.
module PrettyBenzene
  ( prettyBenzene
  ) where

import Chem.Molecule (Molecule)

import ExampleMolecules.BenzenePretty (benzenePretty)

-- | Pretty-printed benzene example expressed using the core molecule types.
prettyBenzene :: Molecule
prettyBenzene = benzenePretty
