{-# LANGUAGE OverloadedStrings #-}
-- | Self-contained walkthrough program that shows how to turn the
-- hydrogen combustion reaction into a sequenced chemputer script.  The
-- module exposes ready-to-use blueprints, the compiled program, and
-- helper utilities for rendering the emitted instructions as human
-- readable text.
module InstructionsForBlockchain.Example
  ( exampleReactionLabel
  , hydrogenBlueprint
  , oxygenBlueprint
  , waterBlueprint
  , combustionReaction
  , combustionProgram
  , combustionInstructions
  , renderInstruction
  , prettyCombustionScript
  ) where

import           Chem.Molecule (Molecule)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as BB
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import           Data.Word (Word64)

import           InstructionsForBlockchain.ChemputerProgram
                   ( ChemputerProgram(..)
                   , ChemputerM
                   , Instruction(..)
                   , InstructionMetadata(..)
                   , Operation(..)
                   , ProvenanceTag(..)
                   , adjustPressure
                   , adjustTemperature
                   , dose
                   , emitNote
                   , holdForRate
                   , recordProduct
                   , registerBlueprint
                   , runChemputerProgram
                   , verifyBlueprint
                   , withNotes
                   , withProvenance
                   , emptyMetadata
                   )
import           InstructionsForBlockchain.Hash (hashBuilder, renderHash)
import           InstructionsForBlockchain.MoleculeBlueprint
                   ( MoleculeBlueprint(..)
                   , VerificationChecklist(..)
                   , mkBlueprint
                   )
import           Reaction (Condition(..), Reaction(..), exampleReaction)
import           SampleMolecules (hydrogen, oxygen, water)

-- | Human-readable label used for all provenance tags in this example.
exampleReactionLabel :: Text
exampleReactionLabel = "Hydrogen combustion example"

-- | Convenience alias to reuse the existing reaction definition from
-- the main library.
combustionReaction :: Reaction
combustionReaction = exampleReaction

-- | Blueprint wrappers for the species involved in the combustion
-- reaction.  These blueprints anchor the molecules with deterministic
-- hashes that can be referenced from chemputer instructions or smart
-- contracts.
hydrogenBlueprint, oxygenBlueprint, waterBlueprint :: MoleculeBlueprint
hydrogenBlueprint = blueprintFrom "Hydrogen (H₂)" hydrogen
oxygenBlueprint   = blueprintFrom "Oxygen (O₂)" oxygen
waterBlueprint    = blueprintFrom "Water (H₂O)" water

-- | Compile the example reaction into a sequenced chemputer program.
-- The script mirrors the individual steps a lab automation system
-- would follow: register and verify each molecule, dose reactants,
-- tune environmental conditions, wait for the rate target, and record
-- the products.  A deterministic reaction tag ensures every emitted
-- instruction carries reproducible provenance metadata.
combustionProgram :: ChemputerProgram ()
combustionProgram = runChemputerProgram $ do
  let reactionTag = ReactionTag exampleReactionLabel (fingerprintReaction combustionReaction)
      annotate :: Text -> InstructionMetadata
      annotate msg = withProvenance [reactionTag]
                   $ withNotes [msg]
                   $ emptyMetadata

  registerBlueprint hydrogenBlueprint (annotate "Register hydrogen feedstock blueprint")
  verifyBlueprint hydrogenBlueprint (annotate "Validate hydrogen neighbour and charge map")

  registerBlueprint oxygenBlueprint (annotate "Register oxygen oxidiser blueprint")
  verifyBlueprint oxygenBlueprint (annotate "Validate oxygen neighbour and charge map")

  registerBlueprint waterBlueprint (annotate "Register water condensate blueprint")
  verifyBlueprint waterBlueprint (annotate "Validate water neighbour and charge map")

  dose hydrogenBlueprint 2.0 (annotate "Dose hydrogen at 2.0 molar equivalents")
  dose oxygenBlueprint 1.0 (annotate "Dose oxygen at 1.0 molar equivalents")

  mapM_ (applyCondition annotate) (conditions combustionReaction)

  holdForRate (rate combustionReaction)
              (annotate ("Maintain reaction until rate constant "
                        <> showDouble (rate combustionReaction)))

  recordProduct waterBlueprint 2.0
                (annotate "Record water yield at 2.0 molar equivalents")

  emitNote "Hydrogen combustion example complete"
           (withProvenance [reactionTag] emptyMetadata)

-- | The ordered instruction log produced by 'combustionProgram'.
combustionInstructions :: [Instruction]
combustionInstructions = programInstructions combustionProgram

-- | Render an instruction (including metadata) into a human readable
-- paragraph.  This is handy for documentation, tutorials, or emitting
-- artefacts alongside blockchain transactions.
renderInstruction :: Instruction -> Text
renderInstruction instruction =
  T.intercalate "\n" $
    headerLine :
    map ("  " <>) detailLines ++
    provenanceLines ++
    noteLines
  where
    headerLine = T.pack (show (instructionIndex instruction))
               <> ". "
               <> heading
    (heading, detailLines) = describeOperation (instructionOp instruction)
    provenanceLines =
      case metadataProvenance (instructionMeta instruction) of
        []   -> []
        tags -> ["  Provenance: " <> T.intercalate ", " (map renderTag tags)]
    noteLines = map ("  Note: " <>) (metadataNotes (instructionMeta instruction))

-- | Pretty printed multi-line summary of the entire program.
prettyCombustionScript :: Text
prettyCombustionScript = T.intercalate "\n\n" (map renderInstruction combustionInstructions)

-- Internal helpers ---------------------------------------------------------

blueprintFrom :: Text -> Molecule -> MoleculeBlueprint
blueprintFrom = mkBlueprint

showDouble :: Double -> Text
showDouble = T.pack . show

showInt :: Int -> Text
showInt = T.pack . show

applyCondition :: (Text -> InstructionMetadata) -> Condition -> ChemputerM ()
applyCondition annotate (TempCondition t) =
  adjustTemperature t (annotate ("Set reactor temperature to " <> showDouble t <> " K"))
applyCondition annotate (PressureCondition p) =
  adjustPressure p (annotate ("Regulate pressure to " <> showDouble p <> " bar"))

fingerprintReaction :: Reaction -> Word64
fingerprintReaction reaction =
  hashBuilder $
       BB.byteString (TE.encodeUtf8 exampleReactionLabel)
    <> foldMap renderParticipant reactantBlueprints
    <> BB.word8 0x7c
    <> foldMap renderParticipant productBlueprints
    <> BB.word8 0x2e
    <> BB.doubleBE (rate reaction)
    <> foldMap renderCondition (conditions reaction)
  where
    reactantBlueprints =
      [ (coeff, blueprintFrom (participantName "reactant" idx) molecule)
      | (idx, (coeff, molecule)) <- zip [1 :: Int ..] (reactants reaction)
      ]
    productBlueprints =
      [ (coeff, blueprintFrom (participantName "product" idx) molecule)
      | (idx, (coeff, molecule)) <- zip [1 :: Int ..] (products reaction)
      ]

participantName :: Text -> Int -> Text
participantName role idx =
  exampleReactionLabel <> " " <> role <> " " <> T.pack (show idx)

renderParticipant :: (Double, MoleculeBlueprint) -> BB.Builder
renderParticipant (coeff, blueprint) =
     BB.doubleBE coeff
  <> BB.word64BE (blueprintHash blueprint)

renderCondition :: Condition -> BB.Builder
renderCondition (TempCondition t)    = BB.stringUtf8 "temp" <> BB.doubleBE t
renderCondition (PressureCondition p) = BB.stringUtf8 "press" <> BB.doubleBE p

renderTag :: ProvenanceTag -> Text
renderTag (MoleculeTag name hashValue) =
  name <> " [" <> renderHash hashValue <> "]"
renderTag (ReactionTag name hashValue) =
  "reaction " <> name <> " [" <> renderHash hashValue <> "]"
renderTag (ExternalReference ref) = ref

-- | Break down each operation into a human readable heading and set of
-- descriptive detail lines.
describeOperation :: Operation -> (Text, [Text])
describeOperation (RegisterBlueprint blueprint) =
  ( "Register blueprint for " <> blueprintName blueprint
  , [ "hash = " <> renderHash (blueprintHash blueprint)
    , "payload bytes = " <> showInt (BS.length (blueprintBytes blueprint))
    ]
  )
describeOperation (VerifyMolecule blueprint checklist) =
  ( "Verify blueprint integrity for " <> blueprintName blueprint
  , [ "neighbour entries = " <> showInt (mapSize (checklistNeighbours checklist))
    , "charge entries = " <> showInt (mapSize (checklistCharges checklist))
    ]
  )
describeOperation (Dose blueprint quantity) =
  ( "Dose " <> blueprintName blueprint
  , ["stoichiometric multiplier = " <> showDouble quantity]
  )
describeOperation (AdjustTemperature value) =
  ( "Adjust temperature"
  , ["target = " <> showDouble value <> " K"]
  )
describeOperation (AdjustPressure value) =
  ( "Adjust pressure"
  , ["target = " <> showDouble value <> " bar"]
  )
describeOperation (HoldForRate value) =
  ( "Hold for rate constant"
  , ["target = " <> showDouble value]
  )
describeOperation (RecordProduct blueprint quantity) =
  ( "Record product " <> blueprintName blueprint
  , ["expected multiplier = " <> showDouble quantity]
  )
describeOperation (EmitNote note) =
  ( "Emit note"
  , ["message = " <> note]
  )

mapSize :: Map k v -> Int
mapSize = M.size
