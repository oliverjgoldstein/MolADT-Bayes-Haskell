-- | Diborane (B2H6) with two explicit 3c-2e bridge systems.
module ExampleMolecules.Diborane (diboranePretty) where

import qualified Data.Map.Strict as M
import qualified Data.Set as S

import Chem.Dietz
  ( AtomId(..)
  , Edge(..)
  , NonNegative(..)
  , SystemId(..)
  , mkBondingSystem
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

diboranePretty :: Molecule
diboranePretty = Molecule
  { atoms =
      M.fromList
        [ (b1Id, b1)
        , (b2Id, b2)
        , (h3Id, h3)
        , (h4Id, h4)
        , (h5Id, h5)
        , (h6Id, h6)
        , (h7Id, h7)
        , (h8Id, h8)
        ]
  , localBonds =
      S.fromList
        [ canonicalEdge b1Id b2Id
        , canonicalEdge b1Id h5Id
        , canonicalEdge b1Id h6Id
        , canonicalEdge b2Id h7Id
        , canonicalEdge b2Id h8Id
        ]
  , systems =
      [ (SystemId 1, bridgeH3System)
      , (SystemId 2, bridgeH4System)
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
  where
    b1Id = AtomId 1
    b2Id = AtomId 2
    h3Id = AtomId 3
    h4Id = AtomId 4
    h5Id = AtomId 5
    h6Id = AtomId 6
    h7Id = AtomId 7
    h8Id = AtomId 8

    boronAttributes = elementAttributes B
    hydrogenAttributes = elementAttributes H
    boronShells = elementShells B
    hydrogenShells = elementShells H

    b1 = Atom
      { atomID = b1Id
      , attributes = boronAttributes
      , coordinate = Coordinate (mkAngstrom (-0.8850)) (mkAngstrom 0.0000) (mkAngstrom 0.0000)
      , shells = boronShells
      , formalCharge = 0
      }
    b2 = Atom
      { atomID = b2Id
      , attributes = boronAttributes
      , coordinate = Coordinate (mkAngstrom 0.8850) (mkAngstrom 0.0000) (mkAngstrom 0.0000)
      , shells = boronShells
      , formalCharge = 0
      }
    h3 = Atom
      { atomID = h3Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 0.0000) (mkAngstrom 0.0000) (mkAngstrom 0.9928)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h4 = Atom
      { atomID = h4Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 0.0000) (mkAngstrom 0.0000) (mkAngstrom (-0.9928))
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h5 = Atom
      { atomID = h5Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-0.8850)) (mkAngstrom 1.1900) (mkAngstrom 0.0000)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h6 = Atom
      { atomID = h6Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-0.8850)) (mkAngstrom (-1.1900)) (mkAngstrom 0.0000)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h7 = Atom
      { atomID = h7Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 0.8850) (mkAngstrom 1.1900) (mkAngstrom 0.0000)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h8 = Atom
      { atomID = h8Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 0.8850) (mkAngstrom (-1.1900)) (mkAngstrom 0.0000)
      , shells = hydrogenShells
      , formalCharge = 0
      }

    bridgeH3Edges =
      S.fromList
        [ canonicalEdge b1Id h3Id
        , canonicalEdge b2Id h3Id
        ]

    bridgeH4Edges =
      S.fromList
        [ canonicalEdge b1Id h4Id
        , canonicalEdge b2Id h4Id
        ]

    bridgeH3System =
      mkBondingSystem (NonNegative 2) bridgeH3Edges (Just "bridge_h3_3c2e")

    bridgeH4System =
      mkBondingSystem (NonNegative 2) bridgeH4Edges (Just "bridge_h4_3c2e")

canonicalEdge :: AtomId -> AtomId -> Edge
canonicalEdge left right
  | left <= right = Edge left right
  | otherwise = Edge right left
