import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 4

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -4.63980316038687

predictiveSd :: Double
predictiveSd = 0.7006008380911776

targetError :: Double
targetError = 0.3601968396131303

score :: Double
score = -0.24318330319990852

formula :: String
formula = "CH3ClO3"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.48)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom (-2.96)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes Cl, coordinate = Coordinate (mkAngstrom (-4.38)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes Cl), formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 1.48) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.48)) (mkAngstrom 1.09) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.48)) (mkAngstrom (-1.09)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.44) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 5)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 2) (AtomId 6)
      , Edge (AtomId 2) (AtomId 7)
      , Edge (AtomId 3) (AtomId 4)
      , Edge (AtomId 5) (AtomId 8)
      ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 2)]) Just ("single"))
      , (SystemId 2, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 3)]) Just ("single"))
      , (SystemId 3, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 3) (AtomId 4)]) Just ("single"))
      , (SystemId 4, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 5)]) Just ("single"))
      , (SystemId 5, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 6)]) Just ("single"))
      , (SystemId 6, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 7)]) Just ("single"))
      , (SystemId 7, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 5) (AtomId 8)]) Just ("single"))
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
