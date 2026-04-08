-- Ferrocene (Fe(C5H5)2) in Dietz-style ADT.
-- Atom IDs follow the paper’s V(ferrocene):
--   1 = Fe
--   2..6   = Cp ring 1 carbons
--   7..11  = Cp ring 2 carbons
--   12..16 = ring 1 hydrogens
--   17..21 = ring 2 hydrogens
--
-- Dietz-style bonding systems (paper):
--   - localized C–H and C–C bonds in localBonds (σ adjacency)
--   - 6e pool over (Fe–C + ring C–C) for each Cp ring
--   - 6e pool over all Fe–C edges (back-donation-style pool)
--
-- If you want PubChem 3D SDF coords, replace coordinate lists using:
--   https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/7611/record/SDF?record_type=3d
-- (CID 7611 is ferrocene on PubChem).

module ExampleMolecules.Ferrocene (ferrocenePretty) where

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
  , emptySmilesStereochemistry
  )
import Constants (elementAttributes, elementShells)

ferrocenePretty :: Molecule
ferrocenePretty = Molecule
  { atoms      = atomTable
  , localBonds = sigmaFramework
  , systems    =
      [ (SystemId 1, cp1PiSystem)
      , (SystemId 2, cp2PiSystem)
      , (SystemId 3, feBackDonationSystem)
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
  where
    -- Atom IDs
    fe      = AtomId 1
    ring1C  = AtomId <$> [2..6]
    ring2C  = AtomId <$> [7..11]
    ring1H  = AtomId <$> [12..16]
    ring2H  = AtomId <$> [17..21]

    -- Shared element data
    feAttributes       = elementAttributes Fe
    carbonAttributes   = elementAttributes C
    hydrogenAttributes = elementAttributes H

    feShells       = elementShells Fe
    carbonShells   = elementShells C
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

    ringPairs xs = zip xs (tail (cycle xs))

    -- Idealised sandwich geometry (Å): Fe at origin, two staggered Cp rings.
    -- (Replace with PubChem SDF coords if desired.)
    feCoord = (0.0000,  0.0000,  0.0000)

    ring1CarbonCoords =
      [ ( 1.1800,  0.0000,  1.6600)
      , ( 0.3647,  1.1220,  1.6600)
      , (-0.9547,  0.6935,  1.6600)
      , (-0.9547, -0.6935,  1.6600)
      , ( 0.3647, -1.1220,  1.6600)
      ]

    ring2CarbonCoords =
      [ ( 0.9547,  0.6935, -1.6600)
      , (-0.3647,  1.1220, -1.6600)
      , (-1.1800,  0.0000, -1.6600)
      , (-0.3647, -1.1220, -1.6600)
      , ( 0.9547, -0.6935, -1.6600)
      ]

    ring1HydrogenCoords =
      [ ( 2.2700,  0.0000,  1.6600)
      , ( 0.7016,  2.1582,  1.6600)
      , (-1.8364,  1.3338,  1.6600)
      , (-1.8364, -1.3338,  1.6600)
      , ( 0.7016, -2.1582,  1.6600)
      ]

    ring2HydrogenCoords =
      [ ( 1.8364,  1.3338, -1.6600)
      , (-0.7016,  2.1582, -1.6600)
      , (-2.2700,  0.0000, -1.6600)
      , (-0.7016, -2.1582, -1.6600)
      , ( 1.8364, -1.3338, -1.6600)
      ]

    feAtom = mkAtom fe feAttributes feShells feCoord

    ring1CarbonAtoms =
      zipWith (\aid xyz -> mkAtom aid carbonAttributes carbonShells xyz)
              ring1C ring1CarbonCoords

    ring2CarbonAtoms =
      zipWith (\aid xyz -> mkAtom aid carbonAttributes carbonShells xyz)
              ring2C ring2CarbonCoords

    ring1HydrogenAtoms =
      zipWith (\aid xyz -> mkAtom aid hydrogenAttributes hydrogenShells xyz)
              ring1H ring1HydrogenCoords

    ring2HydrogenAtoms =
      zipWith (\aid xyz -> mkAtom aid hydrogenAttributes hydrogenShells xyz)
              ring2H ring2HydrogenCoords

    allAtoms = feAtom : (ring1CarbonAtoms ++ ring2CarbonAtoms ++ ring1HydrogenAtoms ++ ring2HydrogenAtoms)

    atomTable = M.fromList [(atomID a, a) | a <- allAtoms]

    -- σ adjacency (localised bonds): C–C rings + C–H
    ring1CCPairs = ringPairs ring1C
    ring2CCPairs = ringPairs ring2C
    ring1CHPairs = zip ring1C ring1H
    ring2CHPairs = zip ring2C ring2H

    sigmaFramework =
      mkEdges (ring1CCPairs ++ ring2CCPairs ++ ring1CHPairs ++ ring2CHPairs)

    -- Dietz-style bonding systems (electron pools)
    feToRing1 = [(fe, c) | c <- ring1C]
    feToRing2 = [(fe, c) | c <- ring2C]
    feToAll   = feToRing1 ++ feToRing2

    cp1Edges = mkEdges (feToRing1 ++ ring1CCPairs)
    cp2Edges = mkEdges (feToRing2 ++ ring2CCPairs)
    feBackEdges = mkEdges feToAll

    cp1PiSystem =
      mkBondingSystem (NonNegative 6) cp1Edges (Just "cp1_pi")

    cp2PiSystem =
      mkBondingSystem (NonNegative 6) cp2Edges (Just "cp2_pi")

    feBackDonationSystem =
      mkBondingSystem (NonNegative 6) feBackEdges (Just "fe_backdonation")
