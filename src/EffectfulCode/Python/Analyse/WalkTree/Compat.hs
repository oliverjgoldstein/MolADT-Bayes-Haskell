module EffectfulCode.Python.Analyse.WalkTree.Compat
  ( Handler(..)
  , HandlerBase(..)
  , HandlerState(..)
  , resourceExcept
  ) where

import EffectfulCode.Effects (EffectMap(..))

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
