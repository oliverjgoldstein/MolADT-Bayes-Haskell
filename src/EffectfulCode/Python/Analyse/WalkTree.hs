module EffectfulCode.Python.Analyse.WalkTree
  ( Handler(..)
  , HandlerBase(..)
  , HandlerState(..)
  , resourceExcept
  , accumulateHandlers
  ) where

import Data.Foldable (foldl')

import EffectfulCode.Effects (EffectMap, emptyEffects, mergeEffects)

-- | Simplified representation of the Python AST handler type.  The real
-- project imports this from language-python, where the constructors carry much
-- richer span metadata.  We only keep the pieces that are relevant for folding
-- handler effects so the example remains self-contained.
data Handler = Handler
  { handlerName    :: !String
  , handlerEffects :: !EffectMap
  }
  deriving (Eq, Show)

-- | Static information shared by all handlers while walking the tree.
newtype HandlerBase = HandlerBase { baseName :: String }
  deriving (Eq, Show)

-- | Output collected for each handler.
data HandlerState = HandlerState
  { stateOwner  :: !String
  , stateEffects :: !EffectMap
  }
  deriving (Eq, Show)

-- | Analyse a handler and return its effect contribution along with a summary
-- value.  The exact behaviour is not important; the real analyser does much
-- more work here.  What matters is that the API now speaks in terms of the new
-- 'Handler' type exposed by language-python.
resourceExcept :: Handler -> HandlerBase -> (EffectMap, HandlerState)
resourceExcept Handler{handlerName = name, handlerEffects = effs}
               HandlerBase{baseName = base} =
  let combinedName = base ++ ":" ++ name
      state        = HandlerState combinedName effs
  in (effs, state)

-- | Fold over the exception handlers associated with a Python "try" statement
-- and collect both their combined effect environment and a list of intermediate
-- states.  Recent versions of @language-python@ renamed the AST type for
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
