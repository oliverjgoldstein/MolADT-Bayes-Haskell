-- | Executable entry point used for quick smoke-testing of the library.
-- The program exercises the parser, validator and logP regression in one
-- go so that running the binary gives a concise integration test.
module Main where

import Chem.IO.SDF (readSDF)
import Chem.Molecule (atoms)
import Chem.Validate (validateMolecule)
import InstructionsForBlockchain.Minimal (runMinimalDemo)
import LogPModel
  ( LogPInferenceMethod(..)
  , SamplingConfig(..)
  , defaultSamplingConfig
  , runLogPRegressionWith
  )
import System.IO (hFlush, stdout)
import Text.Megaparsec (errorBundlePretty)
import Text.Read (readMaybe)
import Data.Char (isSpace)
import Data.List (dropWhileEnd)

-- | Read a numeric property from an SDF file by name.  The parser is
-- intentionally lightweight since the demo files are tiny and only a handful
-- of properties are needed.
readSDFDoubleProperty :: FilePath -> String -> IO (Maybe Double)
readSDFDoubleProperty fp propName = do
  contents <- readFile fp
  let target = "> <" ++ propName ++ ">"
      ls     = lines contents
  pure $ case dropWhile (/= target) ls of
           (_:val:_) -> readMaybe val
           _         -> Nothing

-- | Parse and validate benzene for demonstration,
-- then predict the logP of water using the learned model.
-- | Drive the minimal demo workflow:
--
--   * parse the example benzene molecule from disk
--   * validate its structure and pretty-print it
--   * parse and validate the water example
--   * run a probabilistic logP regression using the demo data set and
--     print predictions for water and the remaining database entries.
main :: IO ()
main = do
  putStrLn "Parsing molecules/benzene.sdf"
  benzeneParsed <- readSDF "molecules/benzene.sdf"
  case benzeneParsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right benzene ->
      case validateMolecule benzene of
        Left err -> do
          putStrLn "Benzene invalid:"
          putStrLn err
        Right _ -> do
          putStrLn $ "Benzene validated (" ++ show (length (atoms benzene)) ++ " atoms)."
          benzeneActualLogP <- readSDFDoubleProperty "molecules/benzene.sdf" "PUBCHEM_XLOGP3"
          case benzeneActualLogP of
            Just actual ->
              putStrLn $ "Actual benzene logP (PUBCHEM_XLOGP3): " ++ show actual
            Nothing ->
              putStrLn "Warning: could not locate a numeric PUBCHEM_XLOGP3 property for benzene"
          putStrLn "Parsing molecules/water.sdf"
          waterParsed <- readSDF "molecules/water.sdf"
          case waterParsed of
            Left err -> putStrLn (errorBundlePretty err)
            Right water ->
              case validateMolecule water of
                Left err2 -> do
                  putStrLn "Water invalid:"
                  putStrLn err2
                Right _ -> do
                  samplingConfig <- promptSamplingConfig
                  putStrLn "Running LogP regression over DB1 and predicting for water and DB2 (LWIS):"
                  let trackedMolecules =
                        [ ("Benzene", benzene, benzeneActualLogP)
                        , ("Water", water, Nothing)
                        ]
                      lwisMethod = UseLWIS (posteriorSamples samplingConfig)
                      mhMethod   = UseMH 0.9
                  runLogPRegressionWith samplingConfig lwisMethod trackedMolecules
                  putStrLn ""
                  putStrLn "Running LogP regression over DB1 and predicting for water and DB2 (MH):"
                  runLogPRegressionWith samplingConfig mhMethod trackedMolecules
                  putStrLn ""
                  runMinimalDemo

promptSamplingConfig :: IO SamplingConfig
promptSamplingConfig = do
  putStrLn "Configure sampling (press Enter to accept defaults)."
  burnIn <- promptPositiveInt "  Burn-in iterations" (burnInIterations defaultSamplingConfig)
  posterior <- promptPositiveInt "  Posterior samples" (posteriorSamples defaultSamplingConfig)
  pure defaultSamplingConfig
    { burnInIterations = burnIn
    , posteriorSamples = posterior
    }

promptPositiveInt :: String -> Int -> IO Int
promptPositiveInt label defVal = do
  putStr $ label ++ " [" ++ show defVal ++ "]: "
  hFlush stdout
  input <- getLine
  let trimmed = dropWhile isSpace (dropWhileEnd isSpace input)
  if null trimmed
    then pure defVal
    else
      case readMaybe trimmed of
        Just n | n > 0 -> pure n
        _ -> do
          putStrLn $ "  Invalid entry; keeping default " ++ show defVal ++ "."
          pure defVal
