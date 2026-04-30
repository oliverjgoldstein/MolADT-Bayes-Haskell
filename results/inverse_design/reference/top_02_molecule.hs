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
predictedFreeSolv = -5.176776993106886

predictiveSd :: Double
predictiveSd = 0.6682225904411353

targetError :: Double
targetError = 0.17677699310688588

score :: Double
score = -0.1953826423973722

formula :: String
formula = "C2H6O"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.35)) (mkAngstrom 1.6532731788489269e-16) (mkAngstrom 3.0e-3), shells = elementShells C, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-0.7)) (mkAngstrom 1.1258330249197703) (mkAngstrom 0.11000000000000001), shells = elementShells C, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.6749999999999997)) (mkAngstrom 1.1691342951089925) (mkAngstrom 0.20800000000000002), shells = elementShells H, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.75)) (mkAngstrom 3.3677786976552215e-16) (mkAngstrom 1.2e-2), shells = elementShells H, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.9500000000000006)) (mkAngstrom (-1.0392304845413258)) (mkAngstrom 0.113), shells = elementShells H, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-7.499999999999996e-2)) (mkAngstrom 4.330127018922214e-2) (mkAngstrom 0.32100000000000006), shells = elementShells H, formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.6000000000000001) (mkAngstrom 1.1258330249197703) (mkAngstrom 0.12200000000000001), shells = elementShells H, formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.49999999999998e-2)) (mkAngstrom 2.2949673200287624) (mkAngstrom 0.22300000000000003), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 4)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 2) (AtomId 5)
      , Edge (AtomId 2) (AtomId 6)
      , Edge (AtomId 3) (AtomId 7)
      , Edge (AtomId 3) (AtomId 8)
      , Edge (AtomId 3) (AtomId 9)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
