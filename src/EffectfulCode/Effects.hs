module EffectfulCode.Effects
  ( EffectMap
  , emptyEffects
  , mergeEffects
  ) where

import qualified Data.Map.Strict as M

-- | Minimal model of an effect environment used by the EffectfulCode analyser.
-- The real project keeps richer metadata, but for our purposes a multiset of
-- string tags is sufficient to demonstrate the handler folding logic.
type EffectMap = M.Map String Int

-- | Empty effect environment.
emptyEffects :: EffectMap
emptyEffects = M.empty

-- | Combine two effect environments by summing the multiplicity of each tag.
mergeEffects :: EffectMap -> EffectMap -> EffectMap
mergeEffects = M.unionWith (+)
