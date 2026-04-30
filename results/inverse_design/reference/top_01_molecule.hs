import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 1

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -5.145585023586179

predictiveSd :: Double
predictiveSd = 0.6670796321426066

targetError :: Double
targetError = 0.14558502358617886

score :: Double
score = -0.19138694610661025

formula :: String
formula = "CH3ClO2"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.48)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells C, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom (-2.96)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes Cl, coordinate = Coordinate (mkAngstrom (-4.38)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells Cl, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.96) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.48)) (mkAngstrom 1.09) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.48)) (mkAngstrom (-1.09)) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 5)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 2) (AtomId 6)
      , Edge (AtomId 2) (AtomId 7)
      , Edge (AtomId 3) (AtomId 4)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
