import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 6

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -4.605238292910419

predictiveSd :: Double
predictiveSd = 0.6918705803457222

targetError :: Double
targetError = 0.3947617070895806

score :: Double
score = -0.24827094844757117

formula :: String
formula = "C3H6F2O2"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.7)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 1.48) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom 0.9545941546018392) (mkAngstrom (-1.7)) (mkAngstrom 0.9545941546018392), shells = defaultShells (elementAttributes F), formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.7)) (mkAngstrom (-1.43)), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.7)) (mkAngstrom (-2.86)), shells = defaultShells (elementAttributes O), formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom 0.779422863405995) (mkAngstrom (-2.479422863405995)) (mkAngstrom (-3.639422863405995)), shells = defaultShells (elementAttributes F), formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.09) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.09)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.6293117934166922)) (mkAngstrom (-2.329311793416692)) (mkAngstrom 0.6293117934166922), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 2.44) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.09) (mkAngstrom (-1.7)) (mkAngstrom (-1.43)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 13, Atom { atomID = AtomId 13, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-2.79)) (mkAngstrom (-1.43)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 3)
      , Edge (AtomId 1) (AtomId 8)
      , Edge (AtomId 1) (AtomId 9)
      , Edge (AtomId 2) (AtomId 4)
      , Edge (AtomId 2) (AtomId 5)
      , Edge (AtomId 2) (AtomId 10)
      , Edge (AtomId 3) (AtomId 11)
      , Edge (AtomId 5) (AtomId 6)
      , Edge (AtomId 5) (AtomId 12)
      , Edge (AtomId 5) (AtomId 13)
      , Edge (AtomId 6) (AtomId 7)
      ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 2)]) Just ("single"))
      , (SystemId 2, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 3)]) Just ("single"))
      , (SystemId 3, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 4)]) Just ("single"))
      , (SystemId 4, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 5)]) Just ("single"))
      , (SystemId 5, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 5) (AtomId 6)]) Just ("single"))
      , (SystemId 6, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 6) (AtomId 7)]) Just ("single"))
      , (SystemId 7, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 8)]) Just ("single"))
      , (SystemId 8, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 9)]) Just ("single"))
      , (SystemId 9, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 10)]) Just ("single"))
      , (SystemId 10, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 3) (AtomId 11)]) Just ("single"))
      , (SystemId 11, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 5) (AtomId 12)]) Just ("single"))
      , (SystemId 12, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 5) (AtomId 13)]) Just ("single"))
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
