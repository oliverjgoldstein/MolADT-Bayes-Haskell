import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 5

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -5.2980510718712

predictiveSd :: Double
predictiveSd = 0.751880540007125

targetError :: Double
targetError = 0.2980510718711997

score :: Double
score = -0.25242225613191355

formula :: String
formula = "C6H12Cl2O2"

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
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom -1.9499999999999997) (mkAngstrom 1.0392304845413267) (mkAngstrom 0.223), shells = elementShells C, formalCharge = 0 })
      , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes Cl, coordinate = Coordinate (mkAngstrom -1.2749999999999997) (mkAngstrom -0.12990381056766553) (mkAngstrom 0.44600000000000006), shells = elementShells Cl, formalCharge = 0 })
      , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -0.625) (mkAngstrom 1.1691342951089927) (mkAngstrom 0.23500000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -1.4249999999999998) (mkAngstrom 2.208364779650319) (mkAngstrom 0.3360000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 13, Atom { atomID = AtomId 13, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -2.575) (mkAngstrom 4.330127018922281e-2) (mkAngstrom 0.339), shells = elementShells H, formalCharge = 0 })
      , (AtomId 14, Atom { atomID = AtomId 14, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -2.7) (mkAngstrom 8.660254037844466e-2) (mkAngstrom 0.44900000000000007), shells = elementShells H, formalCharge = 0 })
      , (AtomId 15, Atom { atomID = AtomId 15, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -2.7750000000000004) (mkAngstrom 0.12990381056766687) (mkAngstrom 0.7640000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 16, Atom { atomID = AtomId 16, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -1.3999999999999997) (mkAngstrom 8.660254037844473e-2) (mkAngstrom 0.8650000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 17, Atom { atomID = AtomId 17, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -0.8999999999999997) (mkAngstrom 1.2990381056766587) (mkAngstrom 0.6660000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 18, Atom { atomID = AtomId 18, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -1.4749999999999996) (mkAngstrom 2.3815698604072066) (mkAngstrom 0.7670000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 19, Atom { atomID = AtomId 19, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -2.749999999999999) (mkAngstrom 2.4248711305964292) (mkAngstrom 0.8680000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 20, Atom { atomID = AtomId 20, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -3.4499999999999997) (mkAngstrom 1.299038105676659) (mkAngstrom 0.6690000000000002), shells = elementShells H, formalCharge = 0 })
      , (AtomId 21, Atom { atomID = AtomId 21, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -2.6500000000000004) (mkAngstrom -0.173205080756887) (mkAngstrom 0.357), shells = elementShells H, formalCharge = 0 })
      , (AtomId 22, Atom { atomID = AtomId 22, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom -1.3499999999999996) (mkAngstrom 4.440892098500626e-16) (mkAngstrom 0.4580000000000001), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ mkEdge (AtomId 1) (AtomId 2)
      , mkEdge (AtomId 1) (AtomId 3)
      , mkEdge (AtomId 2) (AtomId 4)
      , mkEdge (AtomId 2) (AtomId 5)
      , mkEdge (AtomId 2) (AtomId 9)
      , mkEdge (AtomId 4) (AtomId 6)
      , mkEdge (AtomId 4) (AtomId 11)
      , mkEdge (AtomId 4) (AtomId 12)
      , mkEdge (AtomId 5) (AtomId 13)
      , mkEdge (AtomId 6) (AtomId 7)
      , mkEdge (AtomId 6) (AtomId 8)
      , mkEdge (AtomId 6) (AtomId 14)
      , mkEdge (AtomId 7) (AtomId 15)
      , mkEdge (AtomId 7) (AtomId 16)
      , mkEdge (AtomId 7) (AtomId 17)
      , mkEdge (AtomId 8) (AtomId 18)
      , mkEdge (AtomId 8) (AtomId 19)
      , mkEdge (AtomId 8) (AtomId 20)
      , mkEdge (AtomId 9) (AtomId 10)
      , mkEdge (AtomId 9) (AtomId 21)
      , mkEdge (AtomId 9) (AtomId 22)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
