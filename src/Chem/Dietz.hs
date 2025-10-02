{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Dietz: constitution-level primitives.
--   - AtomId, SystemId: stable identifiers
--   - Edge: canonical UNDIRECTED atom–atom edge (unordered pair)
--   - BondingSystem: one electron pool 's' spread over a set of edges 'E'
--   See: Dietz, "Yet Another Representation of Molecular Structure", JCICS (1995).

module Chem.Dietz
  ( AtomId(..), SystemId(..)
  , Edge(..), mkEdge, atomsOfEdge
  , NonNegative(..), mkNonNegative
  , BondingSystem(..), mkBondingSystem
  ) where

import           Control.DeepSeq (NFData)
import           GHC.Generics (Generic)
import           Data.Set     (Set)
import qualified Data.Set     as S
import           Data.Binary  (Binary)

-- Stable identifiers
newtype AtomId   = AtomId Integer deriving (Eq, Ord, Show, Read, Generic, NFData)
newtype SystemId = SystemId Int    deriving (Eq, Ord, Show, Read, Generic, NFData)

-- | Non-negative integer wrapper.
newtype NonNegative = NonNegative { getNN :: Int }
  deriving (Eq, Ord, Show, Read, Generic, NFData)

-- | Smart constructor ensuring the value is non-negative.
mkNonNegative :: Int -> Maybe NonNegative
mkNonNegative n
  | n >= 0    = Just (NonNegative n)
  | otherwise = Nothing

-- | Canonical undirected edge (store as ordered pair with i <= j).
data Edge = Edge AtomId AtomId
  deriving (Eq, Ord, Show, Read, Generic, NFData)

-- | Construct an undirected edge, ordering the identifiers deterministically
-- so that @(mkEdge a b) == (mkEdge b a)@.
mkEdge :: AtomId -> AtomId -> Edge
mkEdge a b = if a <= b then Edge a b else Edge b a

-- | Convenience accessor returning the atom identifiers stored in an edge.
atomsOfEdge :: Edge -> (AtomId, AtomId)
atomsOfEdge (Edge i j) = (i, j)

-- | One Dietz bonding system: s shared electrons over memberEdges E.
--   'memberAtoms' is cached for fast validation/queries.
data BondingSystem = BondingSystem
  { sharedElectrons :: NonNegative   -- ^ s >= 0
  , memberAtoms     :: Set AtomId    -- ^ derived from edges (cache)
  , memberEdges     :: Set Edge      -- ^ set of undirected edges E
  , tag             :: Maybe String  -- ^ optional label (e.g., "pi_ring")
  } deriving (Eq, Show, Read, Generic, NFData)

-- | Smart constructor: derive atom scope from the edges.
mkBondingSystem :: NonNegative -> Set Edge -> Maybe String -> BondingSystem
mkBondingSystem s es lbl =
  let scope = S.fromList [ v | e <- S.toList es, v <- let (i,j) = atomsOfEdge e in [i,j] ]
  in BondingSystem s scope es lbl

instance Binary AtomId
instance Binary SystemId
instance Binary NonNegative
instance Binary Edge
instance Binary BondingSystem
