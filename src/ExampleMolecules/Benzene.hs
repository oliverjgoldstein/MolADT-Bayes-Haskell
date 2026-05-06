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
  , ElementAttributes(..)
  , Coordinate(..)
  , Molecule(..)
  , SmilesAtomStereo(..)
  , SmilesAtomStereoClass(..)
  , SmilesBondStereo(..)
  , SmilesBondStereoDirection(..)
  , SmilesStereochemistry(..)
  , emptySmilesStereochemistry
  , mkAngstrom
  , withLocalBondsAsSystems
  )
import Constants (elementAttributes)

benzene :: Molecule
benzene = withLocalBondsAsSystems $ Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.2131)) (mkAngstrom (-0.6884)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.2028)) (mkAngstrom 0.7064) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.03e-2)) (mkAngstrom (-1.3948)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.04e-2) (mkAngstrom 1.3948) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.2028) (mkAngstrom (-0.7063)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.2131) (mkAngstrom 0.6884) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.1577)) (mkAngstrom (-1.2244)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.1393)) (mkAngstrom 1.2564) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.84e-2)) (mkAngstrom (-2.4809)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.84e-2) (mkAngstrom 2.4808) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.1394) (mkAngstrom (-1.2563)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.1577) (mkAngstrom 1.2245) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        ]
  , localBonds =
      S.fromList
        [ Edge (AtomId 1) (AtomId 2)
        , Edge (AtomId 1) (AtomId 6)
        , Edge (AtomId 1) (AtomId 7)
        , Edge (AtomId 2) (AtomId 3)
        , Edge (AtomId 2) (AtomId 8)
        , Edge (AtomId 3) (AtomId 4)
        , Edge (AtomId 3) (AtomId 9)
        , Edge (AtomId 4) (AtomId 5)
        , Edge (AtomId 4) (AtomId 10)
        , Edge (AtomId 5) (AtomId 6)
        , Edge (AtomId 5) (AtomId 11)
        , Edge (AtomId 6) (AtomId 12)
        ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 6) (S.fromList [Edge (AtomId 1) (AtomId 2), Edge (AtomId 1) (AtomId 6), Edge (AtomId 2) (AtomId 3), Edge (AtomId 3) (AtomId 4), Edge (AtomId 4) (AtomId 5), Edge (AtomId 5) (AtomId 6)]) (Just "pi_ring"))
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }


benzenePretty :: Molecule
benzenePretty = benzene
