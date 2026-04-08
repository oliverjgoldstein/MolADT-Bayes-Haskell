module ExampleMolecules.BenzenePretty (benzenePretty) where

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

benzenePretty :: Molecule
benzenePretty = Molecule
  { atoms = atomTable
  , localBonds = sigmaFramework
  , systems = [(SystemId 1, piRingSystem)]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
  where
    c1Id = AtomId 1
    c2Id = AtomId 2
    c3Id = AtomId 3
    c4Id = AtomId 4
    c5Id = AtomId 5
    c6Id = AtomId 6
    h7Id  = AtomId 7
    h8Id  = AtomId 8
    h9Id  = AtomId 9
    h10Id = AtomId 10
    h11Id = AtomId 11
    h12Id = AtomId 12

    carbonAttributes   = elementAttributes C
    hydrogenAttributes = elementAttributes H
    carbonShells       = elementShells C
    hydrogenShells     = elementShells H

    c1 = Atom
      { atomID = c1Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-1.2131)) (mkAngstrom (-0.6884)) (mkAngstrom   0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c2 = Atom
      { atomID = c2Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-1.2028)) (mkAngstrom   0.7064) (mkAngstrom   0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c3 = Atom
      { atomID = c3Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom (-0.0103)) (mkAngstrom (-1.3948)) (mkAngstrom   0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c4 = Atom
      { atomID = c4Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom   0.0104) (mkAngstrom   1.3948) (mkAngstrom   0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c5 = Atom
      { atomID = c5Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom   1.2028) (mkAngstrom (-0.7063)) (mkAngstrom   0.0)
      , shells = carbonShells
      , formalCharge = 0
      }
    c6 = Atom
      { atomID = c6Id
      , attributes = carbonAttributes
      , coordinate = Coordinate (mkAngstrom   1.2131) (mkAngstrom   0.6884) (mkAngstrom   0.0)
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
      , coordinate = Coordinate (mkAngstrom (-2.1393)) (mkAngstrom   1.2564) (mkAngstrom 0.0)
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
      , coordinate = Coordinate (mkAngstrom   0.0184) (mkAngstrom   2.4808) (mkAngstrom 0.0)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h11 = Atom
      { atomID = h11Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom   2.1394) (mkAngstrom (-1.2563)) (mkAngstrom 0.0)
      , shells = hydrogenShells
      , formalCharge = 0
      }
    h12 = Atom
      { atomID = h12Id
      , attributes = hydrogenAttributes
      , coordinate = Coordinate (mkAngstrom   2.1577) (mkAngstrom   1.2245) (mkAngstrom 0.0)
      , shells = hydrogenShells
      , formalCharge = 0
      }

    atomTable =
      M.insert (atomID h12) h12 $
      M.insert (atomID h11) h11 $
      M.insert (atomID h10) h10 $
      M.insert (atomID h9)  h9  $
      M.insert (atomID h8)  h8  $
      M.insert (atomID h7)  h7  $
      M.insert (atomID c6)  c6  $
      M.insert (atomID c5)  c5  $
      M.insert (atomID c4)  c4  $
      M.insert (atomID c3)  c3  $
      M.insert (atomID c2)  c2  $
      M.insert (atomID c1)  c1  M.empty

    sigmaFramework =
      S.insert (mkEdge c1Id c2Id) $
      S.insert (mkEdge c2Id c3Id) $
      S.insert (mkEdge c3Id c4Id) $
      S.insert (mkEdge c4Id c5Id) $
      S.insert (mkEdge c5Id c6Id) $
      S.insert (mkEdge c6Id c1Id) $
      S.insert (mkEdge c1Id h7Id) $
      S.insert (mkEdge c2Id h8Id) $
      S.insert (mkEdge c3Id h9Id) $
      S.insert (mkEdge c4Id h10Id) $
      S.insert (mkEdge c5Id h11Id) $
      S.insert (mkEdge c6Id h12Id) S.empty

    piRingEdges =
      S.insert (mkEdge c1Id c2Id) $
      S.insert (mkEdge c2Id c3Id) $
      S.insert (mkEdge c3Id c4Id) $
      S.insert (mkEdge c4Id c5Id) $
      S.insert (mkEdge c5Id c6Id) $
      S.insert (mkEdge c6Id c1Id) S.empty

    piRingSystem = mkBondingSystem (NonNegative 6) piRingEdges (Just "pi_ring")
