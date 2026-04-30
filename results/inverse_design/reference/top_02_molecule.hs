import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 2

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -4.799204492375627

predictiveSd :: Double
predictiveSd = 0.695689131346972

targetError :: Double
targetError = 0.20079550762437304

score :: Double
score = -0.2109496340834528

formula :: String
formula = "C2H5ClO3"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.43)) (mkAngstrom 0.0), shells = elementShells C, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-3.2)) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom (-1.43)) (mkAngstrom (-1.43)) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes Cl, coordinate = Coordinate (mkAngstrom (-2.8499999999999996)) (mkAngstrom (-1.43)) (mkAngstrom 0.0), shells = elementShells Cl, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-3.2)) (mkAngstrom (-1.54)), shells = elementShells C, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.96) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.09) (mkAngstrom (-1.43)) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-3.2)) (mkAngstrom (-2.63)), shells = elementShells H, formalCharge = 0 })
      , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.09) (mkAngstrom (-3.2)) (mkAngstrom (-1.54)), shells = elementShells H, formalCharge = 0 })
      , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.7707463914933368)) (mkAngstrom (-2.4292536085066634)) (mkAngstrom (-1.54)), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 7)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 2) (AtomId 4)
      , Edge (AtomId 2) (AtomId 8)
      , Edge (AtomId 3) (AtomId 6)
      , Edge (AtomId 4) (AtomId 5)
      , Edge (AtomId 6) (AtomId 9)
      , Edge (AtomId 6) (AtomId 10)
      , Edge (AtomId 6) (AtomId 11)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
