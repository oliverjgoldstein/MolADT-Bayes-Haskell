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
predictedFreeSolv = -4.988482674147555

predictiveSd :: Double
predictiveSd = 0.7741037514993538

targetError :: Double
targetError = 1.1517325852445026e-2

score :: Double
score = -0.23480467338255614

formula :: String
formula = "CH3ClFNO2"

molecule :: Molecule
molecule = either error id (validateMolecule rawMolecule)

rawMolecule :: Molecule
rawMolecule = Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes Cl, coordinate = Coordinate (mkAngstrom -0.6749999999999997) (mkAngstrom 1.1691342951089925) (mkAngstrom 0.20800000000000002), shells = elementShells Cl, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.6) (mkAngstrom -1.0392304845413263) (mkAngstrom 0.20500000000000002), shells = elementShells O, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes N, coordinate = Coordinate (mkAngstrom -0.10000000000000064) (mkAngstrom -2.2516660498395398) (mkAngstrom 0.30900000000000005), shells = elementShells N, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom 0.5499999999999995) (mkAngstrom -1.1258330249197697) (mkAngstrom 0.41600000000000004), shells = elementShells F, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.1499999999999995) (mkAngstrom -2.2516660498395398) (mkAngstrom 0.31500000000000006), shells = elementShells C, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.7999999999999996) (mkAngstrom -1.1258330249197697) (mkAngstrom 0.42200000000000004), shells = elementShells H, formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.47499999999999976) (mkAngstrom -1.0825317547305473) (mkAngstrom 0.5230000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -0.25000000000000044) (mkAngstrom -2.2516660498395398) (mkAngstrom 0.32400000000000007), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ mkEdge (AtomId 1) (AtomId 2)
      , mkEdge (AtomId 1) (AtomId 3)
      , mkEdge (AtomId 3) (AtomId 4)
      , mkEdge (AtomId 4) (AtomId 5)
      , mkEdge (AtomId 4) (AtomId 6)
      , mkEdge (AtomId 6) (AtomId 7)
      , mkEdge (AtomId 6) (AtomId 8)
      , mkEdge (AtomId 6) (AtomId 9)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
