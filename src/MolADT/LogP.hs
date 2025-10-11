-- | Curated façade for the logP regression pipeline used in the documentation
-- and example programs.
module MolADT.LogP
  ( LogPInferenceMethod(..)
  , runLogPRegressionWith
  , parseLogPFile
  ) where

import LogPModel (LogPInferenceMethod(..), parseLogPFile, runLogPRegressionWith)
