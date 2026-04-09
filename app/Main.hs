module Main where

import           BenchmarkModel
  ( BenchmarkInferenceMethod(..)
  , defaultProcessedDataDir
  , defaultSamplingConfig
  , parseInferenceMethod
  , posteriorSamples
  , runBenchmarkRegressionWith
  )
import           Chem.IO.SDF (readSDF)
import           Chem.IO.SMILES (moleculeToSMILES, parseSMILES)
import           Chem.Molecule (Molecule, atoms, prettyPrintMolecule)
import           Chem.Validate (validateMolecule)
import           ExampleMolecules.Diborane (diboranePretty)
import           ExampleMolecules.Ferrocene (ferrocenePretty)
import           ExampleMolecules.Morphine (morphinePretty)
import qualified Data.Char as Char
import           System.Environment (getArgs, lookupEnv)
import           Text.Megaparsec (errorBundlePretty)
import           Text.Read (readMaybe)

main :: IO ()
main = do
  args <- getArgs
  processedDataDir <- resolveProcessedDataDir
  case args of
    [] -> runDemo processedDataDir
    ["demo"] -> runDemo processedDataDir
    ["parse", path] -> runParse path
    ["parse-smiles", smilesText] -> runParseSMILES smilesText
    ["pretty-example", name] -> runPrettyExample name
    ["to-smiles", path] -> runToSMILES path
    ["infer-benchmark", datasetPrefix, methodName] ->
      runInferBenchmark processedDataDir datasetPrefix methodName Nothing
    ["infer-benchmark", datasetPrefix, methodName, limitText] ->
      runInferBenchmark processedDataDir datasetPrefix methodName (readMaybe limitText)
    _ -> putStrLn usage

usage :: String
usage = unlines
  [ "Usage:"
  , "  stack run moladtbayes -- demo"
  , "  stack run moladtbayes -- parse molecules/benzene.sdf"
  , "  stack run moladtbayes -- parse-smiles \"c1ccccc1\""
  , "  stack run moladtbayes -- pretty-example morphine"
  , "  stack run moladtbayes -- to-smiles molecules/benzene.sdf"
  , "  stack run moladtbayes -- infer-benchmark freesolv_moladt lwis"
  , "  stack run moladtbayes -- infer-benchmark qm9_moladt mh:0.9 256"
  , ""
  , "Optional environment variable:"
  , "  MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed"
  ]

resolveProcessedDataDir :: IO FilePath
resolveProcessedDataDir = do
  mProcessedDataDir <- lookupEnv "MOLADT_PROCESSED_DATA_DIR"
  pure (maybe defaultProcessedDataDir id mProcessedDataDir)

runDemo :: FilePath -> IO ()
runDemo processedDataDir = do
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
          printSmiles "Benzene SMILES" benzene
          putStrLn "Parsing molecules/water.sdf"
          waterParsed <- readSDF "molecules/water.sdf"
          case waterParsed of
            Left err2 -> putStrLn (errorBundlePretty err2)
            Right water ->
              case validateMolecule water of
                Left err3 -> do
                  putStrLn "Water invalid:"
                  putStrLn err3
                Right _ -> do
                  printSmiles "Water SMILES" water
                  let samplingConfig = defaultSamplingConfig
                      lwisMethod = UseLWIS (posteriorSamples samplingConfig)
                      mhMethod = UseMH 0.9
                  putStrLn $ "Processed data directory: " ++ processedDataDir
                  putStrLn "Running aligned FreeSolv / MolADT smoke benchmark (LWIS):"
                  runBenchmarkRegressionWith samplingConfig lwisMethod processedDataDir "freesolv_moladt" (Just 128)
                  putStrLn "Running aligned QM9 / MolADT smoke benchmark (MH):"
                  runBenchmarkRegressionWith samplingConfig mhMethod processedDataDir "qm9_moladt" (Just 256)

runParse :: FilePath -> IO ()
runParse path = do
  parsed <- readSDF path
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule -> do
      renderValidated molecule
      printSmiles "SMILES" molecule

runParseSMILES :: String -> IO ()
runParseSMILES smilesText =
  case parseSMILES smilesText >>= validateMolecule of
    Left err -> putStrLn err
    Right molecule -> renderValidated molecule

runPrettyExample :: String -> IO ()
runPrettyExample rawName =
  case lookupPrettyExample rawName of
    Nothing ->
      putStrLn $
        "Unknown built-in example `"
        ++ rawName
        ++ "`. Choose one of: diborane, ferrocene, morphine."
    Just (title, note, molecule) -> do
      putStrLn title
      putStrLn note
      putStrLn ""
      renderValidated molecule

runToSMILES :: FilePath -> IO ()
runToSMILES path = do
  parsed <- readSDF path
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule ->
      case validateMolecule molecule of
        Left err2 -> putStrLn err2
        Right validMolecule ->
          case moleculeToSMILES validMolecule of
            Left err3 -> putStrLn err3
            Right smilesText -> putStrLn smilesText

renderValidated :: Molecule -> IO ()
renderValidated molecule =
  case validateMolecule molecule of
    Left err -> putStrLn err
    Right validMolecule -> putStrLn (prettyPrintMolecule validMolecule)

runInferBenchmark :: FilePath -> String -> String -> Maybe Int -> IO ()
runInferBenchmark processedDataDir datasetPrefix methodName mLimit =
  case parseInferenceMethod defaultSamplingConfig methodName of
    Nothing ->
      putStrLn $
        "Unknown inference method `" ++ methodName
        ++ "`. Use `lwis`, `lwis:<particles>`, `mh`, or `mh:<jitter>`."
    Just method ->
      runBenchmarkRegressionWith defaultSamplingConfig method processedDataDir datasetPrefix mLimit

printSmiles :: String -> Molecule -> IO ()
printSmiles label molecule =
  case moleculeToSMILES molecule of
    Left err -> putStrLn (label ++ ": " ++ err)
    Right smilesText -> putStrLn (label ++ ": " ++ smilesText)

lookupPrettyExample :: String -> Maybe (String, String, Molecule)
lookupPrettyExample rawName =
  case map Char.toLower rawName of
    "diborane" ->
      Just
        ( "Diborane (B2H6)"
        , "Dietz-style ADT with two explicit 3c-2e bridging hydrogen bonding systems."
        , diboranePretty
        )
    "ferrocene" ->
      Just
        ( "Ferrocene (Fe(C5H5)2)"
        , "Dietz-style ADT with two cyclopentadienyl pi systems and an Fe back-donation-style pool."
        , ferrocenePretty
        )
    "morphine" ->
      Just
        ( "Morphine (explicit Dietz skeleton)"
        , "Dietz-style ADT that turns the five classic SMILES ring closures into sigma edges, keeps the phenyl ring as an explicit pi system, and preserves the five atom-centered stereochemistry flags from the standard boundary string."
        , morphinePretty
        )
    _ -> Nothing
