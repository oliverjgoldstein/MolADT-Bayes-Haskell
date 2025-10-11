{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
module EffectfulCode.Python.Analyse.WalkTree
  ( Handler(..)
  , pattern FlatHandler
  , HandlerBase(..)
  , HandlerState(..)
  , mkHandler
  , addNestedScope
  , resourceExcept
  , accumulateHandlers
  ) where

import           Data.Foldable           (foldl')
import           Data.Map.Strict         (Map)
import           Data.Text               (Text)

import           EffectfulCode.Effects
                   ( EffectMap
                   , ScopePath
                   , appendScope
                   , collapseEffects
                   , emptyEffects
                   , mergeEffects
                   , mkScopePath
                   , renderScopePath
                   , scopedEffects
                   )

-- | Simplified representation of the Python AST handler type.  The real
-- project imports this from language-python, where the constructors carry much
-- richer span metadata.  We only keep the pieces that are relevant for folding
-- handler effects so the example remains self-contained.
data Handler = Handler
  { handlerName    :: !Text
  , handlerEffects :: !(Map Text Int)
  , handlerNested  :: ![(Text, Map Text Int)]
  }
  deriving (Eq, Show)

-- | Pattern synonym that maintains the pre-scoping constructor shape so callers
-- that only care about flat handlers do not need to change.
pattern FlatHandler :: Text -> Map Text Int -> Handler
pattern FlatHandler name effects <- Handler name effects []
  where FlatHandler name effects = Handler name effects []
{-# COMPLETE FlatHandler #-}

-- | Convenience constructor that mirrors the old two-field 'Handler'
-- definition.  Callers can opt-in to scoped behaviour later via
-- 'addNestedScope'.
mkHandler :: Text -> Map Text Int -> Handler
mkHandler name effects = FlatHandler name effects

-- | Attach an additional nested scope to a handler.  The label typically
-- corresponds to the exception type or alias, while the map captures the
-- effects produced inside that scope.
addNestedScope :: Handler -> Text -> Map Text Int -> Handler
addNestedScope handler label effects =
  handler { handlerNested = handlerNested handler ++ [(label, effects)] }

-- | Static information shared by all handlers while walking the tree.
newtype HandlerBase = HandlerBase { baseName :: Text }
  deriving (Eq, Show)

-- | Output collected for each handler.  Besides the flattened effect counts we
-- keep the fully scoped effect map so that downstream tooling can maintain a
-- precise trace of how each handler contributes to the overall environment.
data HandlerState = HandlerState
  { stateScopePath    :: !ScopePath
  , stateQualified    :: !Text
  , stateLocalEffects :: !(Map Text Int)
  , stateAggregate    :: !(Map Text Int)
  , stateEffectMap    :: !EffectMap
  }
  deriving (Eq, Show)

-- | Analyse a handler and return its scoped effect contributions.  The helper
-- ensures that nested scopes inside the handler are preserved so that callers
-- can inspect how resources flow across @try/except@ boundaries.
resourceExcept :: Handler -> HandlerBase -> HandlerState
resourceExcept Handler{handlerName = name, handlerEffects = effs, handlerNested = nested}
               HandlerBase{baseName = base} =
  let rootPath    = mkScopePath base [name]
      aggregate   = foldl' mergeNested (scopedEffects rootPath effs) nested
      qualified   = renderScopePath rootPath
      totals      = collapseEffects aggregate
  in HandlerState
       { stateScopePath    = rootPath
       , stateQualified    = qualified
       , stateLocalEffects = effs
       , stateAggregate    = totals
       , stateEffectMap    = aggregate
       }
  where
    mergeNested acc (label, innerEffects) =
      let nestedPath = appendScope rootPath label
          scoped     = scopedEffects nestedPath innerEffects
      in mergeEffects acc scoped

-- handlers from 'ExceptClause' to 'Handler'.  The analyser used to convert the
-- new representation back into the old name, which broke as soon as the library
-- stopped exporting 'ExceptClause'.  The logic below consumes the new
-- 'Handler' type directly and therefore builds with modern releases.
accumulateHandlers :: HandlerBase -> [Handler] -> (EffectMap, [HandlerState])
accumulateHandlers handlerBase handlers =
  let (effHandlers, handlerStatesRev) =
        foldl'
          (\(effAcc, statesAcc) handler ->
             let (effHandler, stHandler) = resourceExcept handler handlerBase
             in (mergeEffects effAcc effHandler, stHandler : statesAcc))
          (emptyEffects, [])
          handlers
  in (effHandlers, reverse handlerStatesRev)
