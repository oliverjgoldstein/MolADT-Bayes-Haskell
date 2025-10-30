{-# LANGUAGE OverloadedStrings #-}
-- | Minimal blockchain instruction walkthrough that stays small enough to run
-- from the executable's @main@ entry point.  The example registers a single
-- water blueprint, doses it, records the product, and prints the resulting
-- instruction log.
module InstructionsForBlockchain.Minimal
  ( minimalReactionLabel
  , minimalReaction
  , minimalProgram
  , minimalInstructions
  , renderMinimalInstruction
  , prettyMinimalScript
  , runMinimalDemo
  ) where

import           Control.Monad (when)
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import           Data.Time (UTCTime, getCurrentTime)
import           Data.Time.Format (defaultTimeLocale, formatTime)
import           System.Directory (createDirectoryIfMissing, doesFileExist)
import           System.FilePath ((</>))

import           InstructionsForBlockchain.ChemputerProgram
                   ( ChemputerProgram(..)
                   , Instruction(..)
                   , InstructionMetadata(..)
                   , Operation(..)
                   , ProvenanceTag(..)
                   , compileReaction
                   )
import           InstructionsForBlockchain.Hash (renderHash)
import           InstructionsForBlockchain.MoleculeBlueprint
                   ( MoleculeBlueprint(..) )
import           Reaction (Reaction(..))
import           SampleMolecules (water)

-- | Human-readable label shared by every instruction in the demonstration.
minimalReactionLabel :: Text
minimalReactionLabel = "Minimal water handling"

-- | Single-step reaction that consumes and reproduces water.  No temperature or
-- pressure tuning is required, which keeps the resulting instruction list short
-- enough for a quick terminal demonstration.
minimalReaction :: Reaction
minimalReaction = Reaction
  { reactants = [(1.0, water)]
  , products = [(1.0, water)]
  , conditions = []
  , rate = 1.0
  }

-- | Program compiled from 'minimalReaction'.
minimalProgram :: ChemputerProgram ()
minimalProgram = compileReaction minimalReactionLabel minimalReaction

-- | Ordered instructions emitted by 'minimalProgram'.
minimalInstructions :: [Instruction]
minimalInstructions = programInstructions minimalProgram

-- | Render a single instruction into plain text with simple provenance and note
-- output.  This keeps the terminal transcript compact while still exposing the
-- hashes attached to each molecule and reaction step.
renderMinimalInstruction :: Instruction -> Text
renderMinimalInstruction instruction =
  T.intercalate "\n" (headerLine : detailLines ++ provenanceLines ++ noteLines)
  where
    headerLine = T.pack (show (instructionIndex instruction))
               <> ". "
               <> describeOperation (instructionOp instruction)
    detailLines = map ("  " <>) (operationDetails (instructionOp instruction))
    meta = instructionMeta instruction
    provenanceLines =
      case metadataProvenance meta of
        []   -> []
        tags -> ["  provenance: " <> T.intercalate ", " (map renderTag tags)]
    noteLines = map ("  note: " <>) (metadataNotes meta)

-- | Render the entire instruction list separated by blank lines.
prettyMinimalScript :: Text
prettyMinimalScript = T.intercalate "\n\n" (map renderMinimalInstruction minimalInstructions)

-- | Friendly explanation of what the scripted output represents.
laymanOverview :: Text
laymanOverview = T.unlines
  [ "This walkthrough shows how a chemputer experiment could be notarised on a blockchain."
  , "Blockchain assumption: we rely on an append-only, tamper-evident ledger where every new instruction is permanently recorded."
  , "Each hash below is a digital fingerprint that lets anyone prove the blueprint or product record was not altered."
  , "Read the numbered steps to follow the lab actions that generate those fingerprints."
  ]

-- | Render the banner, explanation, and instruction script together for console
-- output.
renderMinimalDemoTranscript :: Text
renderMinimalDemoTranscript =
  T.intercalate "\n\n" [laymanOverview, prettyMinimalScript]

-- | Convenience helper used from the @main@ executable.  Prints a short banner
-- followed by the pretty-printed instruction script.
runMinimalDemo :: IO ()
runMinimalDemo = do
  let script     = renderMinimalDemoTranscript
      outputDir  = "blockchain-logs"
      outputFile = outputDir </> "minimal-ledger.txt"

  putStrLn "--- Minimal chemputer instruction demo ---"
  T.putStrLn script

  createDirectoryIfMissing True outputDir

  fileExists <- doesFileExist outputFile
  when (not fileExists) $ T.writeFile outputFile (laymanOverview <> "\n\n")

  timestamp <- getCurrentTime
  let runHeader   = "Run logged at " <> renderTimestamp timestamp
      hashEntries = labeledHashes minimalInstructions
      runBlock    = T.unlines (runHeader : map ("  " <>) hashEntries) <> "\n"

  T.appendFile outputFile runBlock
  putStrLn $ "Blockchain hash log appended to " ++ outputFile

-- Internal helpers ---------------------------------------------------------

describeOperation :: Operation -> Text
describeOperation (RegisterBlueprint blueprint) =
  "Register blueprint for " <> blueprintName blueprint
describeOperation (VerifyMolecule blueprint _) =
  "Verify blueprint integrity for " <> blueprintName blueprint
describeOperation (Dose blueprint quantity) =
  "Dose " <> blueprintName blueprint <> " at multiplier " <> showDouble quantity
describeOperation (AdjustTemperature value) =
  "Adjust temperature to " <> showDouble value <> " K"
describeOperation (AdjustPressure value) =
  "Adjust pressure to " <> showDouble value <> " bar"
describeOperation (HoldForRate value) =
  "Hold for rate constant " <> showDouble value
describeOperation (RecordProduct blueprint quantity) =
  "Record product " <> blueprintName blueprint <> " at multiplier " <> showDouble quantity
describeOperation (EmitNote note) =
  "Emit note: " <> note

operationDetails :: Operation -> [Text]
operationDetails (RegisterBlueprint blueprint) =
  [ "hash: "
    <> renderHash (blueprintHash blueprint)
    <> " (digital fingerprint of the "
    <> blueprintName blueprint
    <> " blueprint)"
  ]
operationDetails (VerifyMolecule _ _) = []
operationDetails (Dose _ _) = []
operationDetails (AdjustTemperature _) = []
operationDetails (AdjustPressure _) = []
operationDetails (HoldForRate _) = []
operationDetails (RecordProduct blueprint _) =
  [ "hash: "
    <> renderHash (blueprintHash blueprint)
    <> " (fingerprint proving the captured "
    <> blueprintName blueprint
    <> " product)"
  ]
operationDetails (EmitNote _) = []

renderTag :: ProvenanceTag -> Text
renderTag (MoleculeTag name hashValue) =
  name <> " [" <> renderHash hashValue <> "]"
renderTag (ReactionTag name hashValue) =
  name <> " [" <> renderHash hashValue <> "]"
renderTag (ExternalReference ref) = ref

showDouble :: Double -> Text
showDouble = T.pack . show

renderTimestamp :: UTCTime -> Text
renderTimestamp = T.pack . formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S UTC"

labeledHashes :: [Instruction] -> [Text]
labeledHashes = concatMap renderHashEntry
  where
    renderHashEntry instruction =
      case instructionOp instruction of
        RegisterBlueprint blueprint ->
          [ "register-blueprint: "
            <> blueprintName blueprint
            <> " -> "
            <> renderHash (blueprintHash blueprint)
            <> " (blueprint fingerprint)"
          ]
        RecordProduct blueprint _ ->
          [ "record-product: "
            <> blueprintName blueprint
            <> " -> "
            <> renderHash (blueprintHash blueprint)
            <> " (product fingerprint)"
          ]
        _ -> []
