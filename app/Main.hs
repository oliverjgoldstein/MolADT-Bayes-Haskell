module Main where

import           BenchmarkModel
  ( BenchmarkInferenceMethod(..)
  , defaultProcessedDataDir
  , defaultSamplingConfig
  , parseInferenceMethod
  , runBenchmarkRegressionWith
  )
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BL8
import           Chem.IO.SDF (readSDF)
import           Chem.IO.MoleculeJSON (moleculeFromJSON, moleculeToJSON)
import           Chem.IO.SMILES (moleculeToSMILES, parseSMILES)
import           Chem.IO.SDFTiming (measureSdfTiming, renderTimingReport)
import           Chem.Molecule (Molecule, atoms, prettyPrintMolecule)
import           Chem.Validate (validateMolecule)
import           ExampleMolecules.Diborane (diboranePretty)
import           ExampleMolecules.Ferrocene (ferrocenePretty)
import           ExampleMolecules.Morphine (morphinePretty)
import           FreeSolvInverseDesign
  ( InverseDesignConfig(..)
  , defaultInverseDesignConfig
  , parseSeedMoleculeName
  , printSearchResult
  , runFreeSolvInverseDesign
  )
import qualified Data.Char as Char
import           Data.List (isPrefixOf)
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
    ["parse-sdf-timing", path] -> runParseSdfTiming path Nothing
    ["parse-sdf-timing", path, limitText] -> runParseSdfTiming path (readMaybe limitText)
    ["pretty-example", name] -> runPrettyExample name
    ["to-smiles", path] -> runToSMILES path
    ["to-json", path] -> runToJSON path
    ["from-json", path] -> runFromJSON path
    ["infer-benchmark", datasetPrefix, methodName] ->
      runInferBenchmark processedDataDir datasetPrefix methodName Nothing
    ["infer-benchmark", datasetPrefix, methodName, limitText] ->
      runInferBenchmark processedDataDir datasetPrefix methodName (readMaybe limitText)
    "inverse-design" : inverseArgs ->
      runInverseDesignCli processedDataDir inverseArgs
    _ -> putStrLn usage

usage :: String
usage = unlines
  [ "Usage:"
  , "  stack run moladtbayes -- demo"
  , "  stack run moladtbayes -- parse molecules/benzene.sdf"
  , "  stack run moladtbayes -- parse-smiles \"c1ccccc1\""
  , "  stack run moladtbayes -- parse-sdf-timing path/to/file.sdf_or_sdf_directory"
  , "  stack run moladtbayes -- parse-sdf-timing path/to/file.sdf_or_sdf_directory 1000"
  , "  stack run moladtbayes -- pretty-example morphine"
  , "  stack run moladtbayes -- to-smiles molecules/benzene.sdf"
  , "  stack run moladtbayes -- to-json molecules/benzene.sdf > benzene.moladt.json"
  , "  stack run moladtbayes -- from-json benzene.moladt.json"
  , "  stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2"
  , "  stack run moladtbayes -- inverse-design --target -5.0 --seed-molecule water"
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
                      gpMethod = UseMH 0.2
                  putStrLn $ "Processed data directory: " ++ processedDataDir
                  putStrLn "Running aligned FreeSolv / MolADT featurized GP smoke benchmark (MH):"
                  runBenchmarkRegressionWith samplingConfig gpMethod processedDataDir "freesolv_moladt_featurized" (Just 128)

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

runParseSdfTiming :: FilePath -> Maybe Int -> IO ()
runParseSdfTiming path mLimit = do
  result <- measureSdfTiming path mLimit
  case result of
    Left err -> putStrLn err
    Right stages -> putStrLn (renderTimingReport stages)

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

runToJSON :: FilePath -> IO ()
runToJSON path = do
  parsed <- readSDF path
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule ->
      case validateMolecule molecule of
        Left err2 -> putStrLn err2
        Right validMolecule -> BL8.putStrLn (moleculeToJSON validMolecule)

runFromJSON :: FilePath -> IO ()
runFromJSON path = do
  payload <- BL.readFile path
  case moleculeFromJSON payload of
    Left err -> putStrLn err
    Right molecule -> renderValidated molecule

renderValidated :: Molecule -> IO ()
renderValidated molecule =
  case validateMolecule molecule of
    Left err -> putStrLn err
    Right validMolecule -> putStrLn (prettyPrintMolecule validMolecule)

runInferBenchmark :: FilePath -> String -> String -> Maybe Int -> IO ()
runInferBenchmark processedDataDir datasetPrefix methodName mLimit =
  if not ("freesolv_" `isPrefixOf` datasetPrefix)
    then
      putStrLn $
        "Unsupported benchmark dataset `"
        ++ datasetPrefix
        ++ "`. The Haskell benchmark consumer is now scoped to FreeSolv only; "
        ++ "use `freesolv_moladt_featurized`."
    else
      case parseInferenceMethod defaultSamplingConfig methodName of
        Nothing ->
          putStrLn $
            "Unknown inference method `" ++ methodName
            ++ "`. Use `lwis`, `lwis:<particles>`, `mh`, or `mh:<jitter>`."
        Just method ->
          runBenchmarkRegressionWith defaultSamplingConfig method processedDataDir datasetPrefix mLimit

runInverseDesignCli :: FilePath -> [String] -> IO ()
runInverseDesignCli processedDataDir rawArgs =
  case parseInverseDesignArgs rawArgs of
    Left err -> putStrLn err
    Right config -> do
      result <- runFreeSolvInverseDesign processedDataDir config
      printSearchResult result

parseInverseDesignArgs :: [String] -> Either String InverseDesignConfig
parseInverseDesignArgs rawArgs = go rawArgs defaultInverseDesignConfig
  where
    go [] config = Right config
    go ["--help"] _ = Left usage
    go ("--target" : value : rest) config =
      case readMaybe value of
        Nothing ->
          Left "Invalid --target value. Example: --target -5.0"
        Just targetValue ->
          go rest config { configTarget = Just targetValue }
    go ("--seed-molecule" : value : rest) config =
      case parseSeedMoleculeName value of
        Nothing ->
          Left "Invalid --seed-molecule value. Use water or methane."
        Just seedName ->
          go rest config { configSeedMolecule = seedName }
    go (flag : _) _ =
      Left $
        "Unknown inverse-design option `"
        ++ flag
        ++ "`. Use only --target and --seed-molecule."

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
