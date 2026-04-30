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
predictedFreeSolv = -5.336462831471596

predictiveSd :: Double
predictiveSd = 0.7606589938890932

targetError :: Double
targetError = 0.3364628314715956

score :: Double
score = -0.26412665493502346

formula :: String
formula = "CH3F2NO2"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes N, coordinate = Coordinate (mkAngstrom (-0.7000000000000006)) (mkAngstrom (-1.2124355652982137)) (mkAngstrom 0.10400000000000001), shells = elementShells N, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom (-5.000000000000049e-2)) (mkAngstrom (-8.660254037844362e-2)) (mkAngstrom 0.21100000000000002), shells = elementShells F, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom (-0.10000000000000064)) (mkAngstrom (-2.2516660498395398)) (mkAngstrom 0.30900000000000005), shells = elementShells F, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.6) (mkAngstrom (-1.0392304845413263)) (mkAngstrom 0.20500000000000002), shells = elementShells O, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.85) (mkAngstrom (-1.0392304845413263)) (mkAngstrom 0.21100000000000002), shells = elementShells C, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.5) (mkAngstrom 8.660254037844384e-2) (mkAngstrom 0.31800000000000006), shells = elementShells H, formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.1750000000000003) (mkAngstrom 0.1299038105676662) (mkAngstrom 0.41900000000000004), shells = elementShells H, formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.4500000000000002) (mkAngstrom (-1.039230484541326)) (mkAngstrom 0.22000000000000003), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 5)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 2) (AtomId 4)
      , Edge (AtomId 5) (AtomId 6)
      , Edge (AtomId 6) (AtomId 7)
      , Edge (AtomId 6) (AtomId 8)
      , Edge (AtomId 6) (AtomId 9)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
