-- Diborane (B2H6) with two 3c–2e bridges as Dietz pools.
--
-- Atom IDs:
--   1..2   = boron atoms
--   3..4   = bridging hydrogens
--   5..8   = terminal hydrogens
--
-- If you want PubChem 3D SDF coords, replace coordinate lists using:
--   https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/12544637/record/SDF?record_type=3d
-- (CID 12544637 is diborane on PubChem).

module Diborane (diboranePretty) where

import qualified Data.Map.Strict as M
import qualified Data.Set as S

import Chem.Dietz
  ( AtomId(..)
  , SystemId(..)
  , NonNegative(..)
  , mkEdge
  , mkBondingSystem
  )
import Chem.Molecule
  ( AtomicSymbol(..)
  , Molecule(..)
  , Atom(..)
  , Coordinate(..)
  , mkAngstrom
  )
import Constants (elementAttributes, elementShells)

diboranePretty :: Molecule
diboranePretty = Molecule
  { atoms      = atomTable
  , localBonds = sigmaFramework
  , systems    =
      [ (SystemId 1, bridgeH3System)
      , (SystemId 2, bridgeH4System)
      ]
  }
  where
    -- Atom IDs
    b1 = AtomId 1
    b2 = AtomId 2

    h3 = AtomId 3  -- bridge
    h4 = AtomId 4  -- bridge

    h5 = AtomId 5  -- terminal on b1
    h6 = AtomId 6  -- terminal on b1
    h7 = AtomId 7  -- terminal on b2
    h8 = AtomId 8  -- terminal on b2

    -- Shared element data
    boronAttributes    = elementAttributes B
    hydrogenAttributes = elementAttributes H

    boronShells    = elementShells B
    hydrogenShells = elementShells H

    -- Helpers
    coord (x,y,z) =
      Coordinate (mkAngstrom x) (mkAngstrom y) (mkAngstrom z)

    mkAtom aid attrs sh xyz = Atom
      { atomID       = aid
      , attributes   = attrs
      , coordinate   = coord xyz
      , shells       = sh
      , formalCharge = 0
      }

    mkEdges = S.fromList . map (uncurry mkEdge)

    -- Idealised D2h-like geometry (Å), chosen to make bridges explicit.
    bCoords =
      [ (-0.8850,  0.0000,  0.0000)  -- B1
      , ( 0.8850,  0.0000,  0.0000)  -- B2
      ]

    hCoords =
      [ ( 0.0000,  0.0000,  0.9928)  -- H3 bridge
      , ( 0.0000,  0.0000, -0.9928)  -- H4 bridge
      , (-0.8850,  1.1900,  0.0000)  -- H5 terminal (B1)
      , (-0.8850, -1.1900,  0.0000)  -- H6 terminal (B1)
      , ( 0.8850,  1.1900,  0.0000)  -- H7 terminal (B2)
      , ( 0.8850, -1.1900,  0.0000)  -- H8 terminal (B2)
      ]

    boronAtoms =
      zipWith (\aid xyz -> mkAtom aid boronAttributes boronShells xyz)
              [b1,b2]
              bCoords

    hydrogenAtoms =
      zipWith (\aid xyz -> mkAtom aid hydrogenAttributes hydrogenShells xyz)
              [h3,h4,h5,h6,h7,h8]
              hCoords

    allAtoms = boronAtoms ++ hydrogenAtoms
    atomTable = M.fromList [(atomID a, a) | a <- allAtoms]

    -- σ adjacency: B–B and four terminal B–H bonds
    sigmaFramework =
      mkEdges [ (b1,b2)
              , (b1,h5), (b1,h6)
              , (b2,h7), (b2,h8)
              ]

    -- 3c–2e bridges as Dietz pools (2 electrons shared over two edges)
    bridgeH3Edges = mkEdges [(b1,h3), (b2,h3)]
    bridgeH4Edges = mkEdges [(b1,h4), (b2,h4)]

    bridgeH3System =
      mkBondingSystem (NonNegative 2) bridgeH3Edges (Just "bridge_h3_3c2e")

    bridgeH4System =
      mkBondingSystem (NonNegative 2) bridgeH4Edges (Just "bridge_h4_3c2e")
