{-# LANGUAGE OverloadedStrings #-}
-- | Canonical blueprints derived from 'Chem.Molecule.Molecule' values.  They
-- capture the minimal metadata a chemputer or blockchain validator needs to
-- confirm a molecule definition before executing instructions.
module InstructionsForBlockchain.MoleculeBlueprint
  ( MoleculeBlueprint(..)
  , VerificationChecklist(..)
  , mkBlueprint
  , blueprintChecklist
  , serialiseMolecule
  , moleculeTag
  ) where

import           Chem.Dietz (AtomId)
import           Chem.Molecule
import           Data.Binary (encode)
import           Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as BL
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import           Data.Text (Text)
import           Data.Word (Word64)

import           InstructionsForBlockchain.Hash (hashBytes, renderHash)

-- | Static description of a molecule with verification helpers.
data MoleculeBlueprint = MoleculeBlueprint
  { blueprintName       :: Text
  , blueprintMolecule   :: Molecule
  , blueprintHash       :: Word64
  , blueprintBytes      :: ByteString
  , blueprintNeighbours :: Map AtomId [AtomId]
  , blueprintCharges    :: Map AtomId Int
  } deriving (Eq, Show)

-- | Checklist that a chemputer or smart contract can replay to confirm the
-- uploaded molecule has not been tampered with.
data VerificationChecklist = VerificationChecklist
  { checklistNeighbours :: Map AtomId [AtomId]
  , checklistCharges    :: Map AtomId Int
  } deriving (Eq, Show)

-- | Serialise a molecule using the existing 'Binary' instances for the
-- constituent types.
serialiseMolecule :: Molecule -> ByteString
serialiseMolecule = BL.toStrict . encode

-- | Build a blueprint from a molecule and a human-readable name.
mkBlueprint :: Text -> Molecule -> MoleculeBlueprint
mkBlueprint name molecule = MoleculeBlueprint
  { blueprintName       = name
  , blueprintMolecule   = molecule
  , blueprintHash       = hashBytes bytes
  , blueprintBytes      = bytes
  , blueprintNeighbours = neighbourMap
  , blueprintCharges    = chargeMap
  }
  where
    bytes        = serialiseMolecule molecule
    atomMap      = atoms molecule
    neighbourMap = M.fromList
      [ (atomId, neighborsSigma molecule atomId)
      | (atomId, _) <- M.toList atomMap
      ]
    chargeMap    = M.fromList
      [ (atomId, formalCharge atom)
      | (atomId, atom) <- M.toList atomMap
      ]

-- | Generate the verification checklist associated with a blueprint.
blueprintChecklist :: MoleculeBlueprint -> VerificationChecklist
blueprintChecklist blueprint = VerificationChecklist
  { checklistNeighbours = blueprintNeighbours blueprint
  , checklistCharges    = blueprintCharges blueprint
  }

-- | Human-readable provenance tag combining the display name and hash.
moleculeTag :: MoleculeBlueprint -> Text
moleculeTag blueprint =
  blueprintName blueprint <> " (" <> renderHash (blueprintHash blueprint) <> ")"
