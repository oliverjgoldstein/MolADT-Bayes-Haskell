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
import           System.Environment (getArgs)
import           Text.Megaparsec (errorBundlePretty)
import           Text.Read (readMaybe)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> runDemo
    ["demo"] -> runDemo
    ["parse", path] -> runParse path
    ["parse-smiles", smilesText] -> runParseSMILES smilesText
    ["to-smiles", path] -> runToSMILES path
    ["infer-benchmark", datasetPrefix, methodName] ->
      runInferBenchmark datasetPrefix methodName Nothing
    ["infer-benchmark", datasetPrefix, methodName, limitText] ->
      runInferBenchmark datasetPrefix methodName (readMaybe limitText)
    _ -> putStrLn usage

usage :: String
usage = unlines
  [ "Usage:"
  , "  stack run moladtbayes -- demo"
  , "  stack run moladtbayes -- parse molecules/benzene.sdf"
  , "  stack run moladtbayes -- parse-smiles \"c1ccccc1\""
  , "  stack run moladtbayes -- to-smiles molecules/benzene.sdf"
  , "  stack run moladtbayes -- infer-benchmark freesolv_smiles lwis"
  , "  stack run moladtbayes -- infer-benchmark qm9_sdf mh:0.9 256"
  ]

runDemo :: IO ()
runDemo = do
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
                  putStrLn "Running aligned FreeSolv / SMILES smoke benchmark (LWIS):"
                  runBenchmarkRegressionWith samplingConfig lwisMethod defaultProcessedDataDir "freesolv_smiles" (Just 128)
                  putStrLn "Running aligned QM9 / SDF smoke benchmark (MH):"
                  runBenchmarkRegressionWith samplingConfig mhMethod defaultProcessedDataDir "qm9_sdf" (Just 256)

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

runInferBenchmark :: String -> String -> Maybe Int -> IO ()
runInferBenchmark datasetPrefix methodName mLimit =
  case parseInferenceMethod defaultSamplingConfig methodName of
    Nothing ->
      putStrLn $
        "Unknown inference method `" ++ methodName
        ++ "`. Use `lwis`, `lwis:<particles>`, `mh`, or `mh:<jitter>`."
    Just method ->
      runBenchmarkRegressionWith defaultSamplingConfig method defaultProcessedDataDir datasetPrefix mLimit

printSmiles :: String -> Molecule -> IO ()
printSmiles label molecule =
  case moleculeToSMILES molecule of
    Left err -> putStrLn (label ++ ": " ++ err)
    Right smilesText -> putStrLn (label ++ ": " ++ smilesText)
