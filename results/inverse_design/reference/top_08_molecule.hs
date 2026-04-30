import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 8

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -4.891450189140026

predictiveSd :: Double
predictiveSd = 0.8251338339292482

targetError :: Double
targetError = 0.10854981085997384

score :: Double
score = -0.2631536713918218

formula :: String
formula = "CH3ClO"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes Cl, coordinate = Coordinate (mkAngstrom (-0.7000000000000006)) (mkAngstrom (-1.2124355652982137)) (mkAngstrom 0.10400000000000001), shells = elementShells Cl, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.35)) (mkAngstrom 1.6532731788489269e-16) (mkAngstrom 3.0e-3), shells = elementShells C, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.0500000000000007)) (mkAngstrom (-1.2124355652982135)) (mkAngstrom 0.10700000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.7500000000000001)) (mkAngstrom (-1.039230484541326)) (mkAngstrom 0.20800000000000002), shells = elementShells H, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.10000000000000009)) (mkAngstrom 1.6532731788489269e-16) (mkAngstrom 9.000000000000001e-3), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 3)
      , Edge (AtomId 3) (AtomId 4)
      , Edge (AtomId 3) (AtomId 5)
      , Edge (AtomId 3) (AtomId 6)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
