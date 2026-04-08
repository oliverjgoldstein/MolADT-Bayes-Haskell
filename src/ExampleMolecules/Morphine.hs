-- | Hand-crafted morphine skeleton expressed directly as a Dietz-style
-- molecule. The atom numbering follows the non-cyclic morphine sketch in the
-- classic ring-closure figure:
--
--   O1C2C(O)C=C(C3C2(C4)C5c1c(O)ccc5CC3N(C)C4)
--
-- The five SMILES closure digits become ordinary sigma edges here:
--   1 -> (1, 11)
--   2 -> (2, 8)
--   3 -> (7, 18)
--   4 -> (9, 21)
--   5 -> (10, 16)
--
-- The constitutional point is explicit in the ADT:
--   - localBonds stores the sigma framework directly
--   - one 2e system marks the alkene bridge
--   - one 6e system marks the phenyl pi ring
--
-- Coordinates are schematic rather than experimental.
module ExampleMolecules.Morphine
  ( morphinePretty
  , morphineRingClosureSmiles
  ) where

import qualified Data.Map.Strict as M
import qualified Data.Set as S

import Chem.Dietz
  ( AtomId(..)
  , NonNegative(..)
  , SystemId(..)
  , mkBondingSystem
  , mkEdge
  )
import Chem.Molecule
  ( Atom(..)
  , AtomicSymbol(..)
  , Coordinate(..)
  , Molecule(..)
  , emptySmilesStereochemistry
  , mkAngstrom
  )
import Constants (elementAttributes, elementShells)

morphineRingClosureSmiles :: String
morphineRingClosureSmiles = "O1C2C(O)C=C(C3C2(C4)C5c1c(O)ccc5CC3N(C)C4)"

morphinePretty :: Molecule
morphinePretty = Molecule
  { atoms = atomTable
  , localBonds = S.fromList [edgeFromPair pair | pair <- sigmaEdges]
  , systems =
      [ (SystemId 1, alkeneBridgeSystem)
      , (SystemId 2, phenylPiRingSystem)
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
  where
    atomTable =
      M.fromList
        [ ( aid
          , Atom
              { atomID = aid
              , attributes = elementAttributes sym
              , coordinate = Coordinate (mkAngstrom x) (mkAngstrom y) (mkAngstrom z)
              , shells = elementShells sym
              , formalCharge = 0
              }
          )
        | (i, sym, x, y, z) <- atomsData
        , let aid = AtomId i
        ]

    atomsData =
      [ ( 1, O, 0.0, 0.0, 0.0)
      , ( 2, C, 1.0, 0.8, 0.0)
      , ( 3, C, 2.0, 0.8, 0.0)
      , ( 4, O, 2.0, -0.4, 0.0)
      , ( 5, C, 3.0, 0.8, 0.0)
      , ( 6, C, 4.0, 0.8, 0.0)
      , ( 7, C, 5.0, 0.8, 0.0)
      , ( 8, C, 1.8, 2.0, 0.0)
      , ( 9, C, 2.8, 2.8, 0.0)
      , (10, C, 3.8, 2.0, 0.0)
      , (11, C, 0.8, 2.0, 0.0)
      , (12, C, 1.2, 3.2, 0.0)
      , (13, O, 0.4, 4.0, 0.0)
      , (14, C, 2.4, 3.8, 0.0)
      , (15, C, 3.6, 3.8, 0.0)
      , (16, C, 4.2, 2.8, 0.0)
      , (17, C, 5.4, 2.8, 0.0)
      , (18, C, 6.2, 1.8, 0.0)
      , (19, N, 7.2, 1.8, 0.0)
      , (20, C, 8.2, 2.4, 0.0)
      , (21, C, 6.0, 2.8, 0.0)
      ]

    sigmaEdges =
      [ (1, 2)
      , (1, 11)
      , (2, 3)
      , (2, 8)
      , (3, 4)
      , (3, 5)
      , (5, 6)
      , (6, 7)
      , (7, 8)
      , (7, 18)
      , (8, 9)
      , (8, 10)
      , (9, 21)
      , (10, 11)
      , (10, 16)
      , (11, 12)
      , (12, 13)
      , (12, 14)
      , (14, 15)
      , (15, 16)
      , (16, 17)
      , (17, 18)
      , (18, 19)
      , (19, 20)
      , (19, 21)
      ]

    alkeneEdges =
      [ (5, 6)
      ]

    phenylPiRingEdges =
      [ (10, 11)
      , (11, 12)
      , (12, 14)
      , (14, 15)
      , (15, 16)
      , (10, 16)
      ]

    edgeFromPair (a, b) = mkEdge (AtomId a) (AtomId b)

    alkeneBridgeSystem =
      mkBondingSystem
        (NonNegative 2)
        (S.fromList [edgeFromPair pair | pair <- alkeneEdges])
        (Just "alkene_bridge")

    phenylPiRingSystem =
      mkBondingSystem
        (NonNegative 6)
        (S.fromList [edgeFromPair pair | pair <- phenylPiRingEdges])
        (Just "phenyl_pi_ring")

