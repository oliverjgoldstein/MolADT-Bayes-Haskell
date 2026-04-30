import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 7

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -5.461019594587542

predictiveSd :: Double
predictiveSd = 0.6784865788457562

targetError :: Double
targetError = 0.46101959458754216

score :: Double
score = -0.2621062289408206

formula :: String
formula = "CH3FO2"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.35)) (mkAngstrom 1.6532731788489269e-16) (mkAngstrom 3.0e-3), shells = elementShells C, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom (-0.7)) (mkAngstrom 1.1258330249197703) (mkAngstrom 0.11000000000000001), shells = elementShells F, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.6500000000000001) (mkAngstrom 1.12583302491977) (mkAngstrom 0.10700000000000001), shells = elementShells O, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.025)) (mkAngstrom 1.1691342951089927) (mkAngstrom 0.21100000000000002), shells = elementShells H, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.75)) (mkAngstrom 3.3677786976552215e-16) (mkAngstrom 1.2e-2), shells = elementShells H, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 4.99999999999996e-2) (mkAngstrom 8.660254037844406e-2) (mkAngstrom 0.21700000000000003), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 4)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 2) (AtomId 5)
      , Edge (AtomId 2) (AtomId 6)
      , Edge (AtomId 4) (AtomId 7)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
