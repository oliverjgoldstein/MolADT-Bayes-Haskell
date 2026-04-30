-- | Small catalogue of manually assembled molecules used across tests and examples.
module SampleMolecules
  ( hydrogen
  , oxygen
  , water
  , methane
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
  , SmilesBondStereo(..)
  , SmilesBondStereoDirection(..)
  , SmilesStereochemistry(..)
  , emptySmilesStereochemistry
  , mkAngstrom
  )
import Constants (elementAttributes, elementShells)

hydrogen :: Molecule
hydrogen = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.74) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        ]
  , localBonds =
      S.fromList
        [ Edge (AtomId 1) (AtomId 2)
        ]
  , systems =
      []
  , smilesStereochemistry = emptySmilesStereochemistry
  }

oxygen :: Molecule
oxygen = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 1.21) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
        ]
  , localBonds =
      S.fromList
        [ Edge (AtomId 1) (AtomId 2)
        ]
  , systems =
      []
  , smilesStereochemistry = emptySmilesStereochemistry
  }

water :: Molecule
water = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.96) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.32)) (mkAngstrom 0.9) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        ]
  , localBonds =
      S.fromList
        [ Edge (AtomId 1) (AtomId 2)
        , Edge (AtomId 1) (AtomId 3)
        ]
  , systems =
      []
  , smilesStereochemistry = emptySmilesStereochemistry
  }

methane :: Molecule
methane = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells C, formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.09) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.09)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 1.09) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.09)) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
        ]
  , localBonds =
      S.fromList
        [ Edge (AtomId 1) (AtomId 2)
        , Edge (AtomId 1) (AtomId 3)
        , Edge (AtomId 1) (AtomId 4)
        , Edge (AtomId 1) (AtomId 5)
        ]
  , systems =
      []
  , smilesStereochemistry = emptySmilesStereochemistry
  }
