module EffectfulCode.Effects
  ( EffectMap(..)
  , emptyEffects
  , mergeEffects
  ) where

import qualified Data.Map.Strict as M

-- | Minimal model of an effect environment used by the EffectfulCode analyser.
-- The real project keeps richer metadata, but for our purposes a multiset of
-- string tags is sufficient to demonstrate the handler folding logic.
newtype EffectMap = EffectMap { getEffects :: M.Map String Int }
  deriving (Eq, Show)

-- | Empty effect environment.
emptyEffects :: EffectMap
emptyEffects = EffectMap M.empty

-- | Combine two effect environments by summing the multiplicity of each tag.
mergeEffects :: EffectMap -> EffectMap -> EffectMap
mergeEffects (EffectMap a) (EffectMap b) = EffectMap (M.unionWith (+) a b)
