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
predictedFreeSolv = -5.302732295715778

predictiveSd :: Double
predictiveSd = 0.755170182534323

targetError :: Double
targetError = 0.30273229571577787

score :: Double
score = -0.25480926299710543

formula :: String
formula = "C5H11ClO2"

molecule :: Molecule
molecule = either error id (validateMolecule rawMolecule)

rawMolecule :: Molecule
rawMolecule = Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom -1.35) (mkAngstrom 1.6532731788489269e-16) (mkAngstrom 3.0e-3), shells = elementShells C, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes Cl, coordinate = Coordinate (mkAngstrom 0.6500000000000001) (mkAngstrom 1.12583302491977) (mkAngstrom 0.10700000000000001), shells = elementShells Cl, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom -2.025) (mkAngstrom 1.1691342951089927) (mkAngstrom 0.21100000000000002), shells = elementShells C, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom -1.9500000000000006) (mkAngstrom -1.0392304845413258) (mkAngstrom 0.113), shells = elementShells O, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom -1.4) (mkAngstrom 8.66025403784445e-2) (mkAngstrom 0.42200000000000004), shells = elementShells C, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom -2.0999999999999996) (mkAngstrom 1.2990381056766587) (mkAngstrom 0.6360000000000001), shells = elementShells C, formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom -2.0999999999999996) (mkAngstrom 1.2990381056766587) (mkAngstrom 0.6360000000000001), shells = elementShells C, formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -2.75) (mkAngstrom 3.3677786976552215e-16) (mkAngstrom 1.2e-2), shells = elementShells H, formalCharge = 0 })
      , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -2.6250000000000004) (mkAngstrom 0.12990381056766664) (mkAngstrom 0.32100000000000006), shells = elementShells H, formalCharge = 0 })
      , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -1.4) (mkAngstrom 8.66025403784445e-2) (mkAngstrom 0.42200000000000004), shells = elementShells H, formalCharge = 0 })
      , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -0.6500000000000006) (mkAngstrom -1.0392304845413258) (mkAngstrom 0.125), shells = elementShells H, formalCharge = 0 })
      , (AtomId 13, Atom { atomID = AtomId 13, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -0.7249999999999998) (mkAngstrom 1.2557368354874368) (mkAngstrom 0.535), shells = elementShells H, formalCharge = 0 })
      , (AtomId 14, Atom { atomID = AtomId 14, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -2.7999999999999994) (mkAngstrom 2.5114736709748726) (mkAngstrom 0.8500000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 15, Atom { atomID = AtomId 15, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -3.3) (mkAngstrom 1.299038105676659) (mkAngstrom 0.6510000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 16, Atom { atomID = AtomId 16, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -2.725) (mkAngstrom 0.2165063509461107) (mkAngstrom 0.7520000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 17, Atom { atomID = AtomId 17, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -1.4499999999999997) (mkAngstrom 0.17320508075688856) (mkAngstrom 0.8530000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 18, Atom { atomID = AtomId 18, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -0.7499999999999996) (mkAngstrom 1.2990381056766587) (mkAngstrom 0.6540000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 19, Atom { atomID = AtomId 19, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -1.3999999999999995) (mkAngstrom 2.5114736709748726) (mkAngstrom 0.7550000000000001), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ mkEdge (AtomId 1) (AtomId 2)
      , mkEdge (AtomId 1) (AtomId 3)
      , mkEdge (AtomId 2) (AtomId 4)
      , mkEdge (AtomId 2) (AtomId 5)
      , mkEdge (AtomId 2) (AtomId 9)
      , mkEdge (AtomId 4) (AtomId 6)
      , mkEdge (AtomId 4) (AtomId 10)
      , mkEdge (AtomId 4) (AtomId 11)
      , mkEdge (AtomId 5) (AtomId 12)
      , mkEdge (AtomId 6) (AtomId 7)
      , mkEdge (AtomId 6) (AtomId 8)
      , mkEdge (AtomId 6) (AtomId 13)
      , mkEdge (AtomId 7) (AtomId 14)
      , mkEdge (AtomId 7) (AtomId 15)
      , mkEdge (AtomId 7) (AtomId 16)
      , mkEdge (AtomId 8) (AtomId 17)
      , mkEdge (AtomId 8) (AtomId 18)
      , mkEdge (AtomId 8) (AtomId 19)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
