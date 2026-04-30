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
predictedFreeSolv = -5.015322512936849

predictiveSd :: Double
predictiveSd = 0.6646475750126406

targetError :: Double
targetError = 1.5322512936848831e-2

score :: Double
score = -0.1830124672341186

formula :: String
formula = "C2H4ClFO2"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.35)) (mkAngstrom 1.6532731788489269e-16) (mkAngstrom 3.0e-3), shells = elementShells C, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom (-0.7)) (mkAngstrom 1.1258330249197703) (mkAngstrom 0.11000000000000001), shells = elementShells F, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes Cl, coordinate = Coordinate (mkAngstrom 0.6500000000000001) (mkAngstrom 1.12583302491977) (mkAngstrom 0.10700000000000001), shells = elementShells Cl, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-2.025)) (mkAngstrom 1.1691342951089927) (mkAngstrom 0.21100000000000002), shells = elementShells C, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom (-1.9500000000000006)) (mkAngstrom (-1.0392304845413258)) (mkAngstrom 0.113), shells = elementShells O, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.4)) (mkAngstrom 8.66025403784445e-2) (mkAngstrom 0.42200000000000004), shells = elementShells H, formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.7249999999999999)) (mkAngstrom 1.1691342951089927) (mkAngstrom 0.22300000000000003), shells = elementShells H, formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.3499999999999996)) (mkAngstrom 2.338268590217985) (mkAngstrom 0.32400000000000007), shells = elementShells H, formalCharge = 0 })
      , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.6500000000000004)) (mkAngstrom 0.17320508075688834) (mkAngstrom 0.327), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 4)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 2) (AtomId 5)
      , Edge (AtomId 2) (AtomId 6)
      , Edge (AtomId 5) (AtomId 7)
      , Edge (AtomId 5) (AtomId 8)
      , Edge (AtomId 5) (AtomId 9)
      , Edge (AtomId 6) (AtomId 10)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
