import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 10

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -4.591912022708634

predictiveSd :: Double
predictiveSd = 0.745406043357791

targetError :: Double
targetError = 0.40808797729136614

score :: Double
score = -0.27446715452737447

formula :: String
formula = "C3H8O3"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 1.48) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 2.96) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.43)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 4.4399999999999995) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.54) (mkAngstrom 1.48) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.09)) (mkAngstrom 1.48) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-2.52)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.09) (mkAngstrom (-1.43)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.43)) (mkAngstrom 1.09), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 5.3999999999999995) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.63) (mkAngstrom 1.48) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 13, Atom { atomID = AtomId 13, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.54) (mkAngstrom 2.2507463914933368) (mkAngstrom 0.7707463914933368), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 14, Atom { atomID = AtomId 14, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.54) (mkAngstrom 1.48) (mkAngstrom (-1.09)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 4)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 2) (AtomId 6)
      , Edge (AtomId 2) (AtomId 7)
      , Edge (AtomId 3) (AtomId 5)
      , Edge (AtomId 4) (AtomId 8)
      , Edge (AtomId 4) (AtomId 9)
      , Edge (AtomId 4) (AtomId 10)
      , Edge (AtomId 5) (AtomId 11)
      , Edge (AtomId 6) (AtomId 12)
      , Edge (AtomId 6) (AtomId 13)
      , Edge (AtomId 6) (AtomId 14)
      ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 2)]) Just ("single"))
      , (SystemId 2, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 3)]) Just ("single"))
      , (SystemId 3, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 4)]) Just ("single"))
      , (SystemId 4, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 3) (AtomId 5)]) Just ("single"))
      , (SystemId 5, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 6)]) Just ("single"))
      , (SystemId 6, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 7)]) Just ("single"))
      , (SystemId 7, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 4) (AtomId 8)]) Just ("single"))
      , (SystemId 8, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 4) (AtomId 9)]) Just ("single"))
      , (SystemId 9, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 4) (AtomId 10)]) Just ("single"))
      , (SystemId 10, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 5) (AtomId 11)]) Just ("single"))
      , (SystemId 11, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 6) (AtomId 12)]) Just ("single"))
      , (SystemId 12, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 6) (AtomId 13)]) Just ("single"))
      , (SystemId 13, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 6) (AtomId 14)]) Just ("single"))
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
