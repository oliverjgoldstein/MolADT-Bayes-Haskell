{-# LANGUAGE GeneralisedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
-- | Monadic scripting layer that turns molecules and reactions into
-- blockchain-friendly chemputer instructions.
module InstructionsForBlockchain.ChemputerProgram
  ( ChemputerProgram(..)
  , Instruction(..)
  , Operation(..)
  , InstructionMetadata(..)
  , ProvenanceTag(..)
  , ChemputerM
  , runChemputerProgram
  , emptyMetadata
  , withProvenance
  , withNotes
  , registerBlueprint
  , verifyBlueprint
  , dose
  , adjustTemperature
  , adjustPressure
  , holdForRate
  , recordProduct
  , emitNote
  , compileReaction
  ) where

import           Chem.Molecule (Molecule)
import           Control.Monad (forM_)
import           Control.Monad.State.Strict (State, get, put, runState)
import qualified Data.ByteString.Builder as BB
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import           Data.Word (Word64)

import           InstructionsForBlockchain.Hash (hashBuilder)
import           InstructionsForBlockchain.MoleculeBlueprint

import           Reaction (Condition(..), Reaction(..))

-- | Opaque wrapper produced once a script has been assembled.
data ChemputerProgram a = ChemputerProgram
  { programInstructions :: [Instruction]
  , programResult       :: a
  } deriving (Eq, Show)

-- | Individual instruction enriched with metadata for auditing.
data Instruction = Instruction
  { instructionIndex :: Int
  , instructionOp    :: Operation
  , instructionMeta  :: InstructionMetadata
  } deriving (Eq, Show)

-- | Primitive operations understood by the hypothetical chemputer.
data Operation
  = RegisterBlueprint MoleculeBlueprint
  | VerifyMolecule MoleculeBlueprint VerificationChecklist
  | Dose MoleculeBlueprint Double
  | AdjustTemperature Double
  | AdjustPressure Double
  | HoldForRate Double
  | RecordProduct MoleculeBlueprint Double
  | EmitNote Text
  deriving (Eq, Show)

-- | Additional contextual metadata emitted with each instruction.
data InstructionMetadata = InstructionMetadata
  { metadataProvenance :: [ProvenanceTag]
  , metadataNotes      :: [Text]
  } deriving (Eq, Show)

-- | Provenance annotations attach hashes or external references to steps.
data ProvenanceTag
  = MoleculeTag Text Word64
  | ReactionTag Text Word64
  | ExternalReference Text
  deriving (Eq, Show)

-- | Internal state used when assembling a program.
data ChemputerState = ChemputerState
  { nextIndex     :: !Int
  , instructionsR :: ![Instruction]
  }

newtype ChemputerM a = ChemputerM { unChemputerM :: State ChemputerState a }
  deriving (Functor, Applicative, Monad)

-- | Execute a chemputer program, returning the emitted instructions and the
-- result value produced by the monadic script.
runChemputerProgram :: ChemputerM a -> ChemputerProgram a
runChemputerProgram (ChemputerM action) =
  let initialState = ChemputerState 0 []
      (result, finalState) = runState action initialState
  in ChemputerProgram (reverse (instructionsR finalState)) result

-- | Empty metadata helper.
emptyMetadata :: InstructionMetadata
emptyMetadata = InstructionMetadata [] []

-- | Append provenance tags to metadata.
withProvenance :: [ProvenanceTag] -> InstructionMetadata -> InstructionMetadata
withProvenance tags meta = meta { metadataProvenance = metadataProvenance meta ++ tags }

-- | Append free-form notes to metadata.
withNotes :: [Text] -> InstructionMetadata -> InstructionMetadata
withNotes notes meta = meta { metadataNotes = metadataNotes meta ++ notes }

-- | Internal helper that pushes a new instruction onto the state.
emit :: Operation -> InstructionMetadata -> ChemputerM ()
emit op meta = ChemputerM $ do
  ChemputerState idx acc <- get
  let instr = Instruction idx op meta
  put $ ChemputerState (idx + 1) (instr : acc)

-- | Ensure molecule tags are always attached to blueprint-specific steps.
attachMolecule :: MoleculeBlueprint -> InstructionMetadata -> InstructionMetadata
attachMolecule blueprint meta = meta
  { metadataProvenance = metadataProvenance meta
      ++ [MoleculeTag (blueprintName blueprint) (blueprintHash blueprint)]
  }

registerBlueprint :: MoleculeBlueprint -> InstructionMetadata -> ChemputerM ()
registerBlueprint blueprint meta =
  emit (RegisterBlueprint blueprint) (attachMolecule blueprint meta)

verifyBlueprint :: MoleculeBlueprint -> InstructionMetadata -> ChemputerM ()
verifyBlueprint blueprint meta =
  emit (VerifyMolecule blueprint (blueprintChecklist blueprint))
       (attachMolecule blueprint meta)

dose :: MoleculeBlueprint -> Double -> InstructionMetadata -> ChemputerM ()
dose blueprint quantity meta =
  emit (Dose blueprint quantity) (attachMolecule blueprint meta)

adjustTemperature :: Double -> InstructionMetadata -> ChemputerM ()
adjustTemperature value meta = emit (AdjustTemperature value) meta

adjustPressure :: Double -> InstructionMetadata -> ChemputerM ()
adjustPressure value meta = emit (AdjustPressure value) meta

holdForRate :: Double -> InstructionMetadata -> ChemputerM ()
holdForRate value meta = emit (HoldForRate value) meta

recordProduct :: MoleculeBlueprint -> Double -> InstructionMetadata -> ChemputerM ()
recordProduct blueprint quantity meta =
  emit (RecordProduct blueprint quantity) (attachMolecule blueprint meta)

emitNote :: Text -> InstructionMetadata -> ChemputerM ()
emitNote note meta = emit (EmitNote note) meta

-- | Compile a 'Reaction' into a deterministic instruction program.
compileReaction :: Text -> Reaction -> ChemputerProgram ()
compileReaction label reaction =
  let script = do
        let reactantBlueprints = zipWith (mkParticipant "reactant") [1 :: Int ..]
                                 (reactants reaction)
            productBlueprints  = zipWith (mkParticipant "product") [1 :: Int ..]
                                 (products reaction)
            reactionHash = fingerprintReaction label reactantBlueprints productBlueprints reaction
            reactionTag  = ReactionTag label reactionHash

        forM_ reactantBlueprints $ \(coeff, blueprint) -> do
          let meta = withProvenance [reactionTag]
                   $ withNotes ["Register reactant with stoichiometry " <> T.pack (show coeff)]
                   $ emptyMetadata
          registerBlueprint blueprint meta
          verifyBlueprint blueprint meta

        forM_ reactantBlueprints $ \(coeff, blueprint) -> do
          let meta = withProvenance [reactionTag]
                   $ withNotes ["Dose reactant at multiplier " <> T.pack (show coeff)]
                   $ emptyMetadata
          dose blueprint coeff meta

        forM_ (conditions reaction) $ \case
          TempCondition t ->
            let meta = withProvenance [reactionTag]
                     $ withNotes ["Set temperature"]
                     $ emptyMetadata
            in adjustTemperature t meta
          PressureCondition p ->
            let meta = withProvenance [reactionTag]
                     $ withNotes ["Set pressure"]
                     $ emptyMetadata
            in adjustPressure p meta

        let rateMeta = withProvenance [reactionTag]
                     $ withNotes ["Hold reaction to satisfy rate constant"]
                     $ emptyMetadata
        holdForRate (rate reaction) rateMeta

        forM_ productBlueprints $ \(coeff, blueprint) -> do
          let meta = withProvenance [reactionTag]
                   $ withNotes ["Record product yield multiplier " <> T.pack (show coeff)]
                   $ emptyMetadata
          recordProduct blueprint coeff meta

        emitNote "Reaction program complete" (withProvenance [reactionTag] emptyMetadata)
  in runChemputerProgram script
  where
    mkParticipant :: Text -> Int -> (Double, Molecule) -> (Double, MoleculeBlueprint)
    mkParticipant role idx (coeff, molecule) =
      let name = label <> " " <> role <> " " <> T.pack (show idx)
      in (coeff, mkBlueprint name molecule)

    fingerprintReaction :: Text
                         -> [(Double, MoleculeBlueprint)]
                         -> [(Double, MoleculeBlueprint)]
                         -> Reaction
                         -> Word64
    fingerprintReaction name reactants' products' r =
      hashBuilder $
        BB.byteString (TE.encodeUtf8 name)
        <> foldMap renderParticipant reactants'
        <> BB.word8 0x7c
        <> foldMap renderParticipant products'
        <> BB.word8 0x2e
        <> BB.doubleBE (rate r)
        <> foldMap renderCondition (conditions r)

    renderParticipant :: (Double, MoleculeBlueprint) -> BB.Builder
    renderParticipant (coeff, blueprint) =
      BB.doubleBE coeff <> BB.word64BE (blueprintHash blueprint)

    renderCondition :: Condition -> BB.Builder
    renderCondition (TempCondition t)    = BB.stringUtf8 "temp" <> BB.doubleBE t
    renderCondition (PressureCondition p) = BB.stringUtf8 "press" <> BB.doubleBE p
