-- | Ferrocene (Fe(C5H5)2) as an explicit Dietz-style molecule.
module ExampleMolecules.Ferrocene
  ( ferrocenePretty
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

ferrocenePretty :: Molecule
ferrocenePretty = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes Fe, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells Fe, formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.18) (mkAngstrom 0.0) (mkAngstrom 1.66), shells = elementShells C, formalCharge = 0 })
        , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.3647) (mkAngstrom 1.122) (mkAngstrom 1.66), shells = elementShells C, formalCharge = 0 })
        , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-0.9547)) (mkAngstrom 0.6935) (mkAngstrom 1.66), shells = elementShells C, formalCharge = 0 })
        , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-0.9547)) (mkAngstrom (-0.6935)) (mkAngstrom 1.66), shells = elementShells C, formalCharge = 0 })
        , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.3647) (mkAngstrom (-1.122)) (mkAngstrom 1.66), shells = elementShells C, formalCharge = 0 })
        , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.9547) (mkAngstrom 0.6935) (mkAngstrom (-1.66)), shells = elementShells C, formalCharge = 0 })
        , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-0.3647)) (mkAngstrom 1.122) (mkAngstrom (-1.66)), shells = elementShells C, formalCharge = 0 })
        , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.18)) (mkAngstrom 0.0) (mkAngstrom (-1.66)), shells = elementShells C, formalCharge = 0 })
        , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-0.3647)) (mkAngstrom (-1.122)) (mkAngstrom (-1.66)), shells = elementShells C, formalCharge = 0 })
        , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.9547) (mkAngstrom (-0.6935)) (mkAngstrom (-1.66)), shells = elementShells C, formalCharge = 0 })
        , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.27) (mkAngstrom 0.0) (mkAngstrom 1.66), shells = elementShells H, formalCharge = 0 })
        , (AtomId 13, Atom { atomID = AtomId 13, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.7016) (mkAngstrom 2.1582) (mkAngstrom 1.66), shells = elementShells H, formalCharge = 0 })
        , (AtomId 14, Atom { atomID = AtomId 14, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.8364)) (mkAngstrom 1.3338) (mkAngstrom 1.66), shells = elementShells H, formalCharge = 0 })
        , (AtomId 15, Atom { atomID = AtomId 15, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.8364)) (mkAngstrom (-1.3338)) (mkAngstrom 1.66), shells = elementShells H, formalCharge = 0 })
        , (AtomId 16, Atom { atomID = AtomId 16, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.7016) (mkAngstrom (-2.1582)) (mkAngstrom 1.66), shells = elementShells H, formalCharge = 0 })
        , (AtomId 17, Atom { atomID = AtomId 17, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.8364) (mkAngstrom 1.3338) (mkAngstrom (-1.66)), shells = elementShells H, formalCharge = 0 })
        , (AtomId 18, Atom { atomID = AtomId 18, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.7016)) (mkAngstrom 2.1582) (mkAngstrom (-1.66)), shells = elementShells H, formalCharge = 0 })
        , (AtomId 19, Atom { atomID = AtomId 19, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.27)) (mkAngstrom 0.0) (mkAngstrom (-1.66)), shells = elementShells H, formalCharge = 0 })
        , (AtomId 20, Atom { atomID = AtomId 20, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.7016)) (mkAngstrom (-2.1582)) (mkAngstrom (-1.66)), shells = elementShells H, formalCharge = 0 })
        , (AtomId 21, Atom { atomID = AtomId 21, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.8364) (mkAngstrom (-1.3338)) (mkAngstrom (-1.66)), shells = elementShells H, formalCharge = 0 })
        ]
  , localBonds =
      S.fromList
        [ Edge (AtomId 2) (AtomId 3)
        , Edge (AtomId 2) (AtomId 6)
        , Edge (AtomId 2) (AtomId 12)
        , Edge (AtomId 3) (AtomId 4)
        , Edge (AtomId 3) (AtomId 13)
        , Edge (AtomId 4) (AtomId 5)
        , Edge (AtomId 4) (AtomId 14)
        , Edge (AtomId 5) (AtomId 6)
        , Edge (AtomId 5) (AtomId 15)
        , Edge (AtomId 6) (AtomId 16)
        , Edge (AtomId 7) (AtomId 8)
        , Edge (AtomId 7) (AtomId 11)
        , Edge (AtomId 7) (AtomId 17)
        , Edge (AtomId 8) (AtomId 9)
        , Edge (AtomId 8) (AtomId 18)
        , Edge (AtomId 9) (AtomId 10)
        , Edge (AtomId 9) (AtomId 19)
        , Edge (AtomId 10) (AtomId 11)
        , Edge (AtomId 10) (AtomId 20)
        , Edge (AtomId 11) (AtomId 21)
        ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 6) (S.fromList [Edge (AtomId 1) (AtomId 2), Edge (AtomId 1) (AtomId 3), Edge (AtomId 1) (AtomId 4), Edge (AtomId 1) (AtomId 5), Edge (AtomId 1) (AtomId 6), Edge (AtomId 2) (AtomId 3), Edge (AtomId 2) (AtomId 6), Edge (AtomId 3) (AtomId 4), Edge (AtomId 4) (AtomId 5), Edge (AtomId 5) (AtomId 6)]) (Just "cp1_pi"))
      , (SystemId 2, mkBondingSystem (NonNegative 6) (S.fromList [Edge (AtomId 1) (AtomId 7), Edge (AtomId 1) (AtomId 8), Edge (AtomId 1) (AtomId 9), Edge (AtomId 1) (AtomId 10), Edge (AtomId 1) (AtomId 11), Edge (AtomId 7) (AtomId 8), Edge (AtomId 7) (AtomId 11), Edge (AtomId 8) (AtomId 9), Edge (AtomId 9) (AtomId 10), Edge (AtomId 10) (AtomId 11)]) (Just "cp2_pi"))
      , (SystemId 3, mkBondingSystem (NonNegative 6) (S.fromList [Edge (AtomId 1) (AtomId 2), Edge (AtomId 1) (AtomId 3), Edge (AtomId 1) (AtomId 4), Edge (AtomId 1) (AtomId 5), Edge (AtomId 1) (AtomId 6), Edge (AtomId 1) (AtomId 7), Edge (AtomId 1) (AtomId 8), Edge (AtomId 1) (AtomId 9), Edge (AtomId 1) (AtomId 10), Edge (AtomId 1) (AtomId 11)]) (Just "fe_backdonation"))
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
