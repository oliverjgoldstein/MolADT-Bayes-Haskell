-- | Hand-crafted benzene expressed directly with the core molecule datatypes.
module ExampleMolecules.Benzene
  ( benzene
  , benzenePretty
  ) where

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
import ExampleMolecules.BenzenePretty (benzenePretty)

benzene :: Molecule
benzene = Molecule
  { atoms =
      M.fromList
        [ (c1Id, c1)
        , (c2Id, c2)
        , (c3Id, c3)
        , (c4Id, c4)
        , (c5Id, c5)
        , (c6Id, c6)
        , (h7Id, h7)
        , (h8Id, h8)
        , (h9Id, h9)
        , (h10Id, h10)
        , (h11Id, h11)
        , (h12Id, h12)
        ]
  , localBonds =
      S.fromList
        [ canonicalEdge c1Id c2Id
        , canonicalEdge c2Id c3Id
        , canonicalEdge c3Id c4Id
        , canonicalEdge c4Id c5Id
        , canonicalEdge c5Id c6Id
        , canonicalEdge c6Id c1Id
        , canonicalEdge c1Id h7Id
        , canonicalEdge c2Id h8Id
        , canonicalEdge c3Id h9Id
        , canonicalEdge c4Id h10Id
        , canonicalEdge c5Id h11Id
        , canonicalEdge c6Id h12Id
        ]
  , systems =
      [ (SystemId 1, piRingSystem)
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
  where
    c1Id = AtomId 1
    c2Id = AtomId 2
    c3Id = AtomId 3
    c4Id = AtomId 4
    c5Id = AtomId 5
    c6Id = AtomId 6
    h7Id = AtomId 7
    h8Id = AtomId 8
    h9Id = AtomId 9
    h10Id = AtomId 10
    h11Id = AtomId 11
    h12Id = AtomId 12

    carbonAttributes = elementAttributes C
    hydrogenAttributes = elementAttributes H
    carbonShells = elementShells C
    hydrogenShells = elementShells H

    c1 = Atom
      { atomID = c1Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-1.2131)) (mkAngstrom (-0.6884)) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c2 = Atom
      { atomID = c2Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-1.2028)) (mkAngstrom 0.7064) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c3 = Atom
      { atomID = c3Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-0.0103)) (mkAngstrom (-1.3948)) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c4 = Atom
      { atomID = c4Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 0.0104) (mkAngstrom 1.3948) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c5 = Atom
      { atomID = c5Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 1.2028) (mkAngstrom (-0.7063)) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c6 = Atom
      { atomID = c6Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 1.2131) (mkAngstrom 0.6884) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    h7 = Atom
      { atomID = h7Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-2.1577)) (mkAngstrom (-1.2244)) (mkAngstrom 0.0)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h8 = Atom
      { atomID = h8Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-2.1393)) (mkAngstrom 1.2564) (mkAngstrom 0.0)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h9 = Atom
      { atomID = h9Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-0.0184)) (mkAngstrom (-2.4809)) (mkAngstrom 0.0)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h10 = Atom
      { atomID = h10Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 0.0184) (mkAngstrom 2.4808) (mkAngstrom 0.0)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h11 = Atom
      { atomID = h11Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 2.1394) (mkAngstrom (-1.2563)) (mkAngstrom 0.0)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h12 = Atom
      { atomID = h12Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 2.1577) (mkAngstrom 1.2245) (mkAngstrom 0.0)
      , shells = hydrogenShells
      , formalCharge = 0
      }

    piRingEdges =
      S.fromList
        [ canonicalEdge c1Id c2Id
        , canonicalEdge c2Id c3Id
        , canonicalEdge c3Id c4Id
        , canonicalEdge c4Id c5Id
        , canonicalEdge c5Id c6Id
        , canonicalEdge c6Id c1Id
        ]

    piRingSystem =
      mkBondingSystem (NonNegative 6) piRingEdges (Just "pi_ring")

canonicalEdge :: AtomId -> AtomId -> Edge
canonicalEdge left right
  | left <= right = Edge left right
  | otherwise = Edge right left
