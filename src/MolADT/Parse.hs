-- | High-level parsing helpers backed by the internal SDF parser.  The goal is
-- to provide a small, curated surface area that downstream applications can
-- rely on without depending on the entire internal module hierarchy.
module MolADT.Parse
  ( SDFParseError
  , readSDF
  , parseSDF
  ) where

import Chem.IO.SDF (parseSDF, readSDF)
import Data.Void (Void)
import Text.Megaparsec (ParseErrorBundle)

-- | Convenience alias for the SDF parser error bundle.
type SDFParseError = ParseErrorBundle String Void
