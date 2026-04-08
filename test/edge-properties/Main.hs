{-# LANGUAGE ScopedTypeVariables #-}

-- | QuickCheck properties focused on basic Dietz edge manipulation.  They act
-- as regression tests for invariants relied upon by the molecule builders.
module Main (main) where

import Test.QuickCheck
import qualified Data.Map.Strict as M
import qualified Data.Set as S

import Chem.Dietz
import Chem.Molecule (Molecule(..), addSigma, emptySmilesStereochemistry)

-- | Generate arbitrary atom identifiers by wrapping random integers.
instance Arbitrary AtomId where
  arbitrary = AtomId <$> arbitrary

-- | Ensure that mkEdge always returns an edge with non-decreasing AtomIds.
prop_edgeCanonical :: AtomId -> AtomId -> Bool
prop_edgeCanonical a b = let Edge u v = mkEdge a b in u <= v

-- | Adding the same sigma edge twice should not change the bond count.
prop_addSigmaIdempotent :: AtomId -> AtomId -> Bool
prop_addSigmaIdempotent i j =
  let m0 = Molecule M.empty S.empty [] emptySmilesStereochemistry
      m1 = addSigma i j m0
      m2 = addSigma i j m1
  in S.size (localBonds m2) == S.size (localBonds m1)

-- | Execute the QuickCheck properties.
main :: IO ()
main = do
  quickCheck prop_edgeCanonical
  quickCheck prop_addSigmaIdempotent
