{-# LANGUAGE OverloadedStrings #-}
module EffectfulCode.Effects
  ( EffectMap
  , ScopePath
  , emptyEffects
  , scopedEffects
  , mergeEffects
  , pushEffect
  , collapseEffects
  , mkScopePath
  , appendScope
  , renderScopePath
  , scopeSegments
  ) where

import           Data.List.NonEmpty        (NonEmpty (..))
import qualified Data.List.NonEmpty        as NE
import qualified Data.Map.Strict           as M
import           Data.Map.Strict           (Map)
import           Data.Text                 (Text)
import qualified Data.Text                 as T

-- | Path identifying a lexical scope.  The head of the non-empty list denotes
-- the outermost scope (for example the "try" block), while the tail captures
-- nested blocks such as individual exception handlers.
newtype ScopePath = ScopePath { unScopePath :: NonEmpty Text }
  deriving (Eq, Ord, Show)

-- | Rich representation of effect information.  We keep both the aggregated
-- totals across all scopes as well as per-scope breakdowns so that callers can
-- inspect how an effect flows through nested handlers.
data EffectMap = EffectMap
  { effectTotals :: !(Map Text Int)
  , effectScopes :: !(Map ScopePath (Map Text Int))
  }
  deriving (Eq, Show)

-- | An empty effect environment.
emptyEffects :: EffectMap
emptyEffects = EffectMap M.empty M.empty

-- | Build a scoped effect map from a concrete path and its local contribution.
scopedEffects :: ScopePath -> Map Text Int -> EffectMap
scopedEffects path local =
  let initial = EffectMap M.empty (M.singleton path M.empty)
  in M.foldlWithKey' (\acc eff weight -> pushEffect path eff weight acc) initial local

-- | Merge two scoped effect maps by adding their aggregated totals and
-- combining each scope's local contributions.
mergeEffects :: EffectMap -> EffectMap -> EffectMap
mergeEffects (EffectMap totalsA scopesA) (EffectMap totalsB scopesB) =
  EffectMap
    { effectTotals = M.unionWith (+) totalsA totalsB
    , effectScopes = M.unionWith (M.unionWith (+)) scopesA scopesB
    }

-- | Register an effect occurrence inside a specific scope.
pushEffect :: ScopePath -> Text -> Int -> EffectMap -> EffectMap
pushEffect path effect weight (EffectMap totals scopes) =
  let totals' = M.insertWith (+) effect weight totals
      updateLocal Nothing   = Just (M.singleton effect weight)
      updateLocal (Just mp) = Just (M.insertWith (+) effect weight mp)
      scopes' = M.alter updateLocal path scopes
  in EffectMap totals' scopes'

-- | Collapse all scoped information down to aggregated totals.
collapseEffects :: EffectMap -> Map Text Int
collapseEffects = effectTotals

-- | Construct a scope path from a root label and optional nested labels.
mkScopePath :: Text -> [Text] -> ScopePath
mkScopePath root rest = ScopePath (root :| rest)

-- | Append an additional label to an existing scope path.
appendScope :: ScopePath -> Text -> ScopePath
appendScope (ScopePath segments) child = ScopePath (segments <> pure child)

-- | Access the individual scope labels that make up a path.
scopeSegments :: ScopePath -> NonEmpty Text
scopeSegments (ScopePath segments) = segments

-- | Render a scope path using colon-separated labels.
renderScopePath :: ScopePath -> Text
renderScopePath (ScopePath segments) = T.intercalate ":" (NE.toList segments)
=======
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
