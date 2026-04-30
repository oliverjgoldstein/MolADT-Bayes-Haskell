-- | Hand-crafted morphine skeleton expressed directly as a Dietz-style
-- molecule. The atom numbering follows the non-cyclic morphine sketch in the
-- classic ring-closure figure:
--
--   CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5
--
-- In that sketch, the five broken edges that later become SMILES ring
-- closures are ordinary sigma edges here:
--   1 -> (1, 11)
--   2 -> (2, 8)
--   3 -> (7, 18)
--   4 -> (9, 21)
--   5 -> (10, 16)
module ExampleMolecules.Morphine
  ( morphinePretty
  , morphineRingClosureSmiles
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
  , SmilesAtomStereo(..)
  , SmilesAtomStereoClass(..)
  , SmilesStereochemistry(..)
  , mkAngstrom
  )
import Constants (elementAttributes, elementShells)

morphineRingClosureSmiles :: String
morphineRingClosureSmiles = "CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5"

morphinePretty :: Molecule
morphinePretty = Molecule
  { atoms =
      M.fromList
        [ (o1Id, o1)
        , (c2Id, c2)
        , (c3Id, c3)
        , (o4Id, o4)
        , (c5Id, c5)
        , (c6Id, c6)
        , (c7Id, c7)
        , (c8Id, c8)
        , (c9Id, c9)
        , (c10Id, c10)
        , (c11Id, c11)
        , (c12Id, c12)
        , (o13Id, o13)
        , (c14Id, c14)
        , (c15Id, c15)
        , (c16Id, c16)
        , (c17Id, c17)
        , (c18Id, c18)
        , (n19Id, n19)
        , (c20Id, c20)
        , (c21Id, c21)
        ]
  , localBonds =
      S.fromList
        [ canonicalEdge o1Id c2Id
        , canonicalEdge o1Id c11Id
        , canonicalEdge c2Id c3Id
        , canonicalEdge c2Id c8Id
        , canonicalEdge c3Id o4Id
        , canonicalEdge c3Id c5Id
        , canonicalEdge c5Id c6Id
        , canonicalEdge c6Id c7Id
        , canonicalEdge c7Id c8Id
        , canonicalEdge c7Id c18Id
        , canonicalEdge c8Id c9Id
        , canonicalEdge c8Id c10Id
        , canonicalEdge c9Id c21Id
        , canonicalEdge c10Id c11Id
        , canonicalEdge c10Id c16Id
        , canonicalEdge c11Id c12Id
        , canonicalEdge c12Id o13Id
        , canonicalEdge c12Id c14Id
        , canonicalEdge c14Id c15Id
        , canonicalEdge c15Id c16Id
        , canonicalEdge c16Id c17Id
        , canonicalEdge c17Id c18Id
        , canonicalEdge c18Id n19Id
        , canonicalEdge n19Id c20Id
        , canonicalEdge n19Id c21Id
        ]
  , systems =
      [ (SystemId 1, alkeneBridgeSystem)
      , (SystemId 2, phenylPiRingSystem)
      ]
  , smilesStereochemistry =
      SmilesStereochemistry
        { atomStereoAnnotations =
            [ SmilesAtomStereo c2Id StereoTetrahedral 1 "@"
            , SmilesAtomStereo c3Id StereoTetrahedral 2 "@@"
            , SmilesAtomStereo c7Id StereoTetrahedral 1 "@"
            , SmilesAtomStereo c8Id StereoTetrahedral 1 "@"
            , SmilesAtomStereo c18Id StereoTetrahedral 1 "@"
            ]
        , bondStereoAnnotations = []
        }
  }
  where
    o1Id = AtomId 1
    c2Id = AtomId 2
    c3Id = AtomId 3
    o4Id = AtomId 4
    c5Id = AtomId 5
    c6Id = AtomId 6
    c7Id = AtomId 7
    c8Id = AtomId 8
    c9Id = AtomId 9
    c10Id = AtomId 10
    c11Id = AtomId 11
    c12Id = AtomId 12
    o13Id = AtomId 13
    c14Id = AtomId 14
    c15Id = AtomId 15
    c16Id = AtomId 16
    c17Id = AtomId 17
    c18Id = AtomId 18
    n19Id = AtomId 19
    c20Id = AtomId 20
    c21Id = AtomId 21

    oxygenAttributes = elementAttributes O
    carbonAttributes = elementAttributes C
    nitrogenAttributes = elementAttributes N
    oxygenShells = elementShells O
    carbonShells = elementShells C
    nitrogenShells = elementShells N

    o1 = Atom
      { atomID = o1Id
      , attributes = oxygenAttributes
      , coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0)
      , shells = oxygenShells
      , formalCharge = 0
      }
    c2 = Atom
      { atomID = c2Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 1.0) (mkAngstrom 0.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c3 = Atom
      { atomID = c3Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 2.0) (mkAngstrom 0.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    o4 = Atom
      { atomID = o4Id
      , attributes = oxygenAttributes
      , coordinate = Coordinate (mkAngstrom 2.0) (mkAngstrom (-0.4)) (mkAngstrom 0.0)
      , shells = oxygenShells
      , formalCharge = 0
      }
    c5 = Atom
      { atomID = c5Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 3.0) (mkAngstrom 0.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c6 = Atom
      { atomID = c6Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 4.0) (mkAngstrom 0.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c7 = Atom
      { atomID = c7Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 5.0) (mkAngstrom 0.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c8 = Atom
      { atomID = c8Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 1.8) (mkAngstrom 2.0) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c9 = Atom
      { atomID = c9Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 2.8) (mkAngstrom 2.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c10 = Atom
      { atomID = c10Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 3.8) (mkAngstrom 2.0) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c11 = Atom
      { atomID = c11Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 0.8) (mkAngstrom 2.0) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c12 = Atom
      { atomID = c12Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 1.2) (mkAngstrom 3.2) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    o13 = Atom
      { atomID = o13Id
      , attributes = oxygenAttributes
      , coordinate = Coordinate (mkAngstrom 0.4) (mkAngstrom 4.0) (mkAngstrom 0.0)
      , shells = oxygenShells
      , formalCharge = 0
      }
    c14 = Atom
      { atomID = c14Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 2.4) (mkAngstrom 3.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c15 = Atom
      { atomID = c15Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 3.6) (mkAngstrom 3.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c16 = Atom
      { atomID = c16Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 4.2) (mkAngstrom 2.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c17 = Atom
      { atomID = c17Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 5.4) (mkAngstrom 2.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c18 = Atom
      { atomID = c18Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 6.2) (mkAngstrom 1.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    n19 = Atom
      { atomID = n19Id
      , attributes = nitrogenAttributes
      , coordinate = Coordinate (mkAngstrom 7.2) (mkAngstrom 1.8) (mkAngstrom 0.0)
      , shells = nitrogenShells
      , formalCharge = 0
      }
    c20 = Atom
      { atomID = c20Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 8.2) (mkAngstrom 2.4) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c21 = Atom
      { atomID = c21Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom 6.0) (mkAngstrom 2.8) (mkAngstrom 0.0)
      , shells = carbonShells
      , formalCharge = 0
      }

    alkeneBridgeEdges =
      S.fromList
        [ canonicalEdge c5Id c6Id
        ]

    phenylPiRingEdges =
      S.fromList
        [ canonicalEdge c10Id c11Id
        , canonicalEdge c11Id c12Id
        , canonicalEdge c12Id c14Id
        , canonicalEdge c14Id c15Id
        , canonicalEdge c15Id c16Id
        , canonicalEdge c10Id c16Id
        ]

    alkeneBridgeSystem =
      mkBondingSystem (NonNegative 2) alkeneBridgeEdges (Just "alkene_bridge")

    phenylPiRingSystem =
      mkBondingSystem (NonNegative 6) phenylPiRingEdges (Just "phenyl_pi_ring")

canonicalEdge :: AtomId -> AtomId -> Edge
canonicalEdge left right
  | left <= right = Edge left right
  | otherwise = Edge right left
