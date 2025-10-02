{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Length units and Cartesian coordinates expressed in Angstroms.  The
-- newtypes help prevent unit-mismatch bugs when constructing molecules.
module Chem.Molecule.Coordinate
  ( Angstrom(..)
  , mkAngstrom
  , unAngstrom
  , Coordinate(..)
  ) where

import Control.DeepSeq (NFData)
import GHC.Generics (Generic)
import Data.Binary (Binary)

-- | Wrapper marking that the numeric value represents a distance in
-- Angstroms.
newtype Angstrom = Angstrom Double
  deriving (Eq, Ord, Show, Read, Generic, NFData)

-- | Smart constructor kept symmetric with 'unAngstrom' for clarity.
mkAngstrom :: Double -> Angstrom
mkAngstrom = Angstrom

unAngstrom :: Angstrom -> Double
unAngstrom (Angstrom d) = d

-- | Cartesian coordinates in Angstroms.
data Coordinate = Coordinate
  { x :: Angstrom
  , y :: Angstrom
  , z :: Angstrom
  } deriving (Eq, Show, Read, Generic, NFData)

instance Binary Angstrom
instance Binary Coordinate
