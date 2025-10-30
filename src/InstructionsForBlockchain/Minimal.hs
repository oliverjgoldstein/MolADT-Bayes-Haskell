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

import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T

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

-- | Convenience helper used from the @main@ executable.  Prints a short banner
-- followed by the pretty-printed instruction script.
runMinimalDemo :: IO ()
runMinimalDemo = do
  putStrLn "--- Minimal chemputer instruction demo ---"
  T.putStrLn prettyMinimalScript

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
  ["hash: " <> renderHash (blueprintHash blueprint)]
operationDetails (VerifyMolecule _ _) = []
operationDetails (Dose _ _) = []
operationDetails (AdjustTemperature _) = []
operationDetails (AdjustPressure _) = []
operationDetails (HoldForRate _) = []
operationDetails (RecordProduct blueprint _) =
  ["hash: " <> renderHash (blueprintHash blueprint)]
operationDetails (EmitNote _) = []

renderTag :: ProvenanceTag -> Text
renderTag (MoleculeTag name hashValue) =
  name <> " [" <> renderHash hashValue <> "]"
renderTag (ReactionTag name hashValue) =
  name <> " [" <> renderHash hashValue <> "]"
renderTag (ExternalReference ref) = ref

showDouble :: Double -> Text
showDouble = T.pack . show
