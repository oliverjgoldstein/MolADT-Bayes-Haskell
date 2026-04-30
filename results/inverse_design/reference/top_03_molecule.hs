import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 3

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -4.965759314767471

predictiveSd :: Double
predictiveSd = 0.7398006413096903

targetError :: Double
targetError = 3.424068523252899e-2

score :: Double
score = -0.21863621056954843

formula :: String
formula = "C3H7F2NO"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes N, coordinate = Coordinate (mkAngstrom (-0.7000000000000006)) (mkAngstrom (-1.2124355652982137)) (mkAngstrom 0.10400000000000001), shells = elementShells N, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom (-5.000000000000049e-2)) (mkAngstrom (-8.660254037844362e-2)) (mkAngstrom 0.21100000000000002), shells = elementShells F, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom (-0.10000000000000064)) (mkAngstrom (-2.2516660498395398)) (mkAngstrom 0.30900000000000005), shells = elementShells F, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.6) (mkAngstrom (-1.0392304845413263)) (mkAngstrom 0.20500000000000002), shells = elementShells C, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.85) (mkAngstrom (-1.0392304845413263)) (mkAngstrom 0.21100000000000002), shells = elementShells C, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.2499999999999996) (mkAngstrom (-2.078460969082652)) (mkAngstrom 0.32100000000000006), shells = elementShells C, formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-7.499999999999973e-2)) (mkAngstrom 0.1299038105676662) (mkAngstrom 0.41300000000000003), shells = elementShells H, formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.7999999999999999)) (mkAngstrom (-1.039230484541326)) (mkAngstrom 0.21400000000000002), shells = elementShells H, formalCharge = 0 })
      , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.2499999999999996) (mkAngstrom (-2.078460969082652)) (mkAngstrom 0.32100000000000006), shells = elementShells H, formalCharge = 0 })
      , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.475) (mkAngstrom (-2.1217622392718747)) (mkAngstrom 0.42200000000000004), shells = elementShells H, formalCharge = 0 })
      , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.55) (mkAngstrom (-2.078460969082652)) (mkAngstrom 0.3330000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 13, Atom { atomID = AtomId 13, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.9249999999999998) (mkAngstrom (-0.9093266739736598)) (mkAngstrom 0.43400000000000005), shells = elementShells H, formalCharge = 0 })
      , (AtomId 14, Atom { atomID = AtomId 14, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.5499999999999999) (mkAngstrom (-0.8660254037844379)) (mkAngstrom 0.5350000000000001), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 5)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 2) (AtomId 4)
      , Edge (AtomId 5) (AtomId 6)
      , Edge (AtomId 5) (AtomId 8)
      , Edge (AtomId 5) (AtomId 9)
      , Edge (AtomId 6) (AtomId 7)
      , Edge (AtomId 6) (AtomId 10)
      , Edge (AtomId 6) (AtomId 11)
      , Edge (AtomId 7) (AtomId 12)
      , Edge (AtomId 7) (AtomId 13)
      , Edge (AtomId 7) (AtomId 14)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
