-- | Ferrocene (Fe(C5H5)2) as an explicit Dietz-style molecule.
module ExampleMolecules.Ferrocene (ferrocenePretty) where

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

ferrocenePretty :: Molecule
ferrocenePretty = Molecule
  { atoms =
      M.fromList
        [ (feId, fe)
        , (c2Id, c2)
        , (c3Id, c3)
        , (c4Id, c4)
        , (c5Id, c5)
        , (c6Id, c6)
        , (c7Id, c7)
        , (c8Id, c8)
        , (c9Id, c9)
        , (c10Id, c10)
        , (c11Id, c11)
        , (h12Id, h12)
        , (h13Id, h13)
        , (h14Id, h14)
        , (h15Id, h15)
        , (h16Id, h16)
        , (h17Id, h17)
        , (h18Id, h18)
        , (h19Id, h19)
        , (h20Id, h20)
        , (h21Id, h21)
        ]
  , localBonds =
      S.fromList
        [ canonicalEdge c2Id c3Id
        , canonicalEdge c3Id c4Id
        , canonicalEdge c4Id c5Id
        , canonicalEdge c5Id c6Id
        , canonicalEdge c6Id c2Id
        , canonicalEdge c2Id h12Id
        , canonicalEdge c3Id h13Id
        , canonicalEdge c4Id h14Id
        , canonicalEdge c5Id h15Id
        , canonicalEdge c6Id h16Id
        , canonicalEdge c7Id c8Id
        , canonicalEdge c8Id c9Id
        , canonicalEdge c9Id c10Id
        , canonicalEdge c10Id c11Id
        , canonicalEdge c11Id c7Id
        , canonicalEdge c7Id h17Id
        , canonicalEdge c8Id h18Id
        , canonicalEdge c9Id h19Id
        , canonicalEdge c10Id h20Id
        , canonicalEdge c11Id h21Id
        ]
  , systems =
      [ (SystemId 1, cp1PiSystem)
      , (SystemId 2, cp2PiSystem)
      , (SystemId 3, feBackDonationSystem)
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
  where
    feId = AtomId 1
    c2Id = AtomId 2
    c3Id = AtomId 3
    c4Id = AtomId 4
    c5Id = AtomId 5
    c6Id = AtomId 6
    c7Id = AtomId 7
    c8Id = AtomId 8
    c9Id = AtomId 9
    c10Id = AtomId 10
    c11Id = AtomId 11
    h12Id = AtomId 12
    h13Id = AtomId 13
    h14Id = AtomId 14
    h15Id = AtomId 15
    h16Id = AtomId 16
    h17Id = AtomId 17
    h18Id = AtomId 18
    h19Id = AtomId 19
    h20Id = AtomId 20
    h21Id = AtomId 21

    feAttributes = elementAttributes Fe
    carbonAttributes = elementAttributes C
    hydrogenAttributes = elementAttributes H
    feShells = elementShells Fe
    carbonShells = elementShells C
    hydrogenShells = elementShells H

    fe = Atom
      { atomID = feId
      , attributes = feAttributes
      , coordinate = Coordinate (mkAngstrom 0.0000) (mkAngstrom 0.0000) (mkAngstrom 0.0000)
      , shells = feShells
      , formalCharge = 0
      }
    c2 = Atom
      { atomID = c2Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 1.1800) (mkAngstrom 0.0000) (mkAngstrom 1.6600)
      , shells = carbonShells
      , formalCharge = 0
      }
    c3 = Atom
      { atomID = c3Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 0.3647) (mkAngstrom 1.1220) (mkAngstrom 1.6600)
      , shells = carbonShells
      , formalCharge = 0
      }
    c4 = Atom
      { atomID = c4Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-0.9547)) (mkAngstrom 0.6935) (mkAngstrom 1.6600)
      , shells = carbonShells
      , formalCharge = 0
      }
    c5 = Atom
      { atomID = c5Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-0.9547)) (mkAngstrom (-0.6935)) (mkAngstrom 1.6600)
      , shells = carbonShells
      , formalCharge = 0
      }
    c6 = Atom
      { atomID = c6Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 0.3647) (mkAngstrom (-1.1220)) (mkAngstrom 1.6600)
      , shells = carbonShells
      , formalCharge = 0
      }
    c7 = Atom
      { atomID = c7Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 0.9547) (mkAngstrom 0.6935) (mkAngstrom (-1.6600))
      , shells = carbonShells
      , formalCharge = 0
      }
    c8 = Atom
      { atomID = c8Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-0.3647)) (mkAngstrom 1.1220) (mkAngstrom (-1.6600))
      , shells = carbonShells
      , formalCharge = 0
      }
    c9 = Atom
      { atomID = c9Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-1.1800)) (mkAngstrom 0.0000) (mkAngstrom (-1.6600))
      , shells = carbonShells
      , formalCharge = 0
      }
    c10 = Atom
      { atomID = c10Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-0.3647)) (mkAngstrom (-1.1220)) (mkAngstrom (-1.6600))
      , shells = carbonShells
      , formalCharge = 0
      }
    c11 = Atom
      { atomID = c11Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 0.9547) (mkAngstrom (-0.6935)) (mkAngstrom (-1.6600))
      , shells = carbonShells
      , formalCharge = 0
      }
    h12 = Atom
      { atomID = h12Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 2.2700) (mkAngstrom 0.0000) (mkAngstrom 1.6600)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h13 = Atom
      { atomID = h13Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 0.7016) (mkAngstrom 2.1582) (mkAngstrom 1.6600)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h14 = Atom
      { atomID = h14Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-1.8364)) (mkAngstrom 1.3338) (mkAngstrom 1.6600)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h15 = Atom
      { atomID = h15Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-1.8364)) (mkAngstrom (-1.3338)) (mkAngstrom 1.6600)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h16 = Atom
      { atomID = h16Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 0.7016) (mkAngstrom (-2.1582)) (mkAngstrom 1.6600)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h17 = Atom
      { atomID = h17Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 1.8364) (mkAngstrom 1.3338) (mkAngstrom (-1.6600))
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h18 = Atom
      { atomID = h18Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-0.7016)) (mkAngstrom 2.1582) (mkAngstrom (-1.6600))
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h19 = Atom
      { atomID = h19Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-2.2700)) (mkAngstrom 0.0000) (mkAngstrom (-1.6600))
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h20 = Atom
      { atomID = h20Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom (-0.7016)) (mkAngstrom (-2.1582)) (mkAngstrom (-1.6600))
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h21 = Atom
      { atomID = h21Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom 1.8364) (mkAngstrom (-1.3338)) (mkAngstrom (-1.6600))
      , shells = hydrogenShells
      , formalCharge = 0
      }

    cp1PiEdges =
      S.fromList
        [ canonicalEdge feId c2Id
        , canonicalEdge feId c3Id
        , canonicalEdge feId c4Id
        , canonicalEdge feId c5Id
        , canonicalEdge feId c6Id
        , canonicalEdge c2Id c3Id
        , canonicalEdge c3Id c4Id
        , canonicalEdge c4Id c5Id
        , canonicalEdge c5Id c6Id
        , canonicalEdge c6Id c2Id
        ]

    cp2PiEdges =
      S.fromList
        [ canonicalEdge feId c7Id
        , canonicalEdge feId c8Id
        , canonicalEdge feId c9Id
        , canonicalEdge feId c10Id
        , canonicalEdge feId c11Id
        , canonicalEdge c7Id c8Id
        , canonicalEdge c8Id c9Id
        , canonicalEdge c9Id c10Id
        , canonicalEdge c10Id c11Id
        , canonicalEdge c11Id c7Id
        ]

    feBackDonationEdges =
      S.fromList
        [ canonicalEdge feId c2Id
        , canonicalEdge feId c3Id
        , canonicalEdge feId c4Id
        , canonicalEdge feId c5Id
        , canonicalEdge feId c6Id
        , canonicalEdge feId c7Id
        , canonicalEdge feId c8Id
        , canonicalEdge feId c9Id
        , canonicalEdge feId c10Id
        , canonicalEdge feId c11Id
        ]

    cp1PiSystem =
      mkBondingSystem (NonNegative 6) cp1PiEdges (Just "cp1_pi")

    cp2PiSystem =
      mkBondingSystem (NonNegative 6) cp2PiEdges (Just "cp2_pi")

    feBackDonationSystem =
      mkBondingSystem (NonNegative 6) feBackDonationEdges (Just "fe_backdonation")

canonicalEdge :: AtomId -> AtomId -> Edge
canonicalEdge left right
  | left <= right = Edge left right
  | otherwise = Edge right left
