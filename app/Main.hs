-- | Executable entry point used for quick smoke-testing of the library.
-- The program exercises the parser, validator and logP regression in one
-- go so that running the binary gives a concise integration test.
module Main where

import Chem.IO.SDF (readSDF)
import Chem.Molecule (prettyPrintMolecule)
import Chem.Validate (validateMolecule, ValidationWarning(..))
import LogPModel (LogPInferenceMethod(..), runLogPRegressionWith)
import Text.Megaparsec (errorBundlePretty)
import Text.Read (readMaybe)

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
        Left errs -> do
          putStrLn "Benzene invalid:"
          mapM_ (putStrLn . show) errs
        Right (_, warns) -> do
          mapM_ (putStrLn . ("Warning: " ++) . show) warns
          putStrLn (prettyPrintMolecule benzene)
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
                Left errs2 -> do
                  putStrLn "Water invalid:"
                  mapM_ (putStrLn . show) errs2
                Right _ -> do
                  putStrLn "Running LogP regression over DB1 and predicting for water and DB2 (LWIS):"
                  let trackedMolecules =
                        [ ("Benzene", benzene, benzeneActualLogP)
                        , ("Water", water, Nothing)
                        ]
                      lwisMethod = UseLWIS 2000
                      mhMethod   = UseMH 0.9
                  runLogPRegressionWith lwisMethod trackedMolecules
                  putStrLn "Running LogP regression over DB1 and predicting for water and DB2 (MH):"
                  runLogPRegressionWith mhMethod trackedMolecules
