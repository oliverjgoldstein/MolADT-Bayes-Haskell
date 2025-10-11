module EffectfulCode.Python.Analyse.WalkTree
  ( accumulateHandlers
  ) where

import Data.Foldable (foldl')

import EffectfulCode.Effects (EffectMap, emptyEffects, mergeEffects)
import EffectfulCode.Python.Analyse.WalkTree.Compat
  ( Handler
  , HandlerBase
  , HandlerState
  , resourceExcept
  )

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
