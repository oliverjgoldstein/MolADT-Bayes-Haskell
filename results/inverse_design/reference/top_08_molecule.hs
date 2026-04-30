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
predictedFreeSolv = -4.927086720844784

predictiveSd :: Double
predictiveSd = 0.837141276965959

targetError :: Double
targetError = 7.291327915521606e-2

score :: Double
score = -0.26711387706782524

formula :: String
formula = "C4H9F2NO3"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells C, formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.7)) (mkAngstrom 0.0), shells = elementShells C, formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 1.48) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes N, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.7)) (mkAngstrom (-1.43)), shells = elementShells N, formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.7)) (mkAngstrom (-2.86)), shells = elementShells O, formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom 0.779422863405995) (mkAngstrom (-2.479422863405995)) (mkAngstrom (-3.639422863405995)), shells = elementShells F, formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 2.96) (mkAngstrom 0.0), shells = elementShells O, formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom (-1.35)) (mkAngstrom (-1.7)) (mkAngstrom (-1.43)), shells = elementShells F, formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.77) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells C, formalCharge = 0 })
      , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-1.54)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells C, formalCharge = 0 })
      , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.6293117934166922)) (mkAngstrom (-2.329311793416692)) (mkAngstrom 0.6293117934166922), shells = elementShells H, formalCharge = 0 })
      , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.7707463914933368) (mkAngstrom (-1.7)) (mkAngstrom 0.7707463914933368), shells = elementShells H, formalCharge = 0 })
      , (AtomId 13, Atom { atomID = AtomId 13, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 3.92) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      , (AtomId 14, Atom { atomID = AtomId 14, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.8600000000000003) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      , (AtomId 15, Atom { atomID = AtomId 15, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.77) (mkAngstrom 1.09) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      , (AtomId 16, Atom { atomID = AtomId 16, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.77) (mkAngstrom 0.0) (mkAngstrom 1.09), shells = elementShells H, formalCharge = 0 })
      , (AtomId 17, Atom { atomID = AtomId 17, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-2.63)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = elementShells H, formalCharge = 0 })
      , (AtomId 18, Atom { atomID = AtomId 18, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.54)) (mkAngstrom 0.7707463914933368) (mkAngstrom 0.7707463914933368), shells = elementShells H, formalCharge = 0 })
      , (AtomId 19, Atom { atomID = AtomId 19, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.54)) (mkAngstrom 0.0) (mkAngstrom (-1.09)), shells = elementShells H, formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 3)
      , Edge (AtomId 1) (AtomId 9)
      , Edge (AtomId 1) (AtomId 10)
      , Edge (AtomId 2) (AtomId 4)
      , Edge (AtomId 2) (AtomId 11)
      , Edge (AtomId 2) (AtomId 12)
      , Edge (AtomId 3) (AtomId 7)
      , Edge (AtomId 4) (AtomId 5)
      , Edge (AtomId 4) (AtomId 8)
      , Edge (AtomId 5) (AtomId 6)
      , Edge (AtomId 7) (AtomId 13)
      , Edge (AtomId 9) (AtomId 14)
      , Edge (AtomId 9) (AtomId 15)
      , Edge (AtomId 9) (AtomId 16)
      , Edge (AtomId 10) (AtomId 17)
      , Edge (AtomId 10) (AtomId 18)
      , Edge (AtomId 10) (AtomId 19)
      ]
  , systems =
      [ 
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
