import Chem.Dietz
import Chem.Molecule
import Chem.Molecule.Coordinate
import Chem.Validate
import Constants
import qualified Data.Map.Strict as M
import qualified Data.Set as S

rank :: Int
rank = 9

targetFreeSolv :: Double
targetFreeSolv = -5.0

seedMolecule :: String
seedMolecule = "water"

predictedFreeSolv :: Double
predictedFreeSolv = -5.229650381360657

predictiveSd :: Double
predictiveSd = 0.8116103195009864

targetError :: Double
targetError = 0.22965038136065719

score :: Double
score = -0.26891816329969187

formula :: String
formula = "C6H13ClF2N2O"

molecule :: Molecule
molecule = either error id (validateMolecule (Molecule
  { atoms = M.fromList
      [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
      , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes N, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.43)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes N), formalCharge = 0 })
      , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 1.48) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 2.96) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.43)) (mkAngstrom (-1.54)), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.54) (mkAngstrom (-1.43)) (mkAngstrom (-1.54)), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes N, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-2.9699999999999998)) (mkAngstrom (-1.54)), shells = defaultShells (elementAttributes N), formalCharge = 0 })
      , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom (-0.84870489570875)) (mkAngstrom (-3.8187048957087497)) (mkAngstrom (-0.6912951042912501)), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom (-1.54)) (mkAngstrom 1.48) (mkAngstrom 0.0), shells = defaultShells (elementAttributes F), formalCharge = 0 })
      , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.0889444430272832) (mkAngstrom (-1.43)) (mkAngstrom 1.0889444430272832), shells = defaultShells (elementAttributes C), formalCharge = 0 })
      , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes F, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 4.3100000000000005) (mkAngstrom 0.0), shells = defaultShells (elementAttributes F), formalCharge = 0 })
      , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes Cl, coordinate = Coordinate (mkAngstrom 1.77) (mkAngstrom 1.48) (mkAngstrom 0.0), shells = defaultShells (elementAttributes Cl), formalCharge = 0 })
      , (AtomId 13, Atom { atomID = AtomId 13, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.7707463914933368) (mkAngstrom 2.96) (mkAngstrom 0.7707463914933368), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 14, Atom { atomID = AtomId 14, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 2.96) (mkAngstrom (-1.09)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 15, Atom { atomID = AtomId 15, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.6293117934166922)) (mkAngstrom (-0.8006882065833077)) (mkAngstrom (-2.1693117934166923)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 16, Atom { atomID = AtomId 16, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 2.63) (mkAngstrom (-1.43)) (mkAngstrom (-1.54)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 17, Atom { atomID = AtomId 17, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.54) (mkAngstrom (-0.33999999999999986)) (mkAngstrom (-1.54)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 18, Atom { atomID = AtomId 18, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.54) (mkAngstrom (-1.43)) (mkAngstrom (-2.63)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 19, Atom { atomID = AtomId 19, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.5831237718815221) (mkAngstrom (-3.5531237718815216)) (mkAngstrom (-2.123123771881522)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 20, Atom { atomID = AtomId 20, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.4780166891254423)) (mkAngstrom (-4.448016689125442)) (mkAngstrom (-6.1983310874557884e-2)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 21, Atom { atomID = AtomId 21, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-7.795850421541317e-2)) (mkAngstrom (-3.8187048957087497)) (mkAngstrom 7.945128720208672e-2), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 22, Atom { atomID = AtomId 22, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.6194512872020868)) (mkAngstrom (-3.047958504215413)) (mkAngstrom (-0.6912951042912501)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 23, Atom { atomID = AtomId 23, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.85969083452062) (mkAngstrom (-1.43)) (mkAngstrom 1.85969083452062), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 24, Atom { atomID = AtomId 24, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.7182562364439753) (mkAngstrom (-2.059311793416692)) (mkAngstrom 0.459632649610591), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      , (AtomId 25, Atom { atomID = AtomId 25, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.459632649610591) (mkAngstrom (-2.059311793416692)) (mkAngstrom 1.7182562364439753), shells = defaultShells (elementAttributes H), formalCharge = 0 })
      ]
  , localBonds = S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 3)
      , Edge (AtomId 2) (AtomId 5)
      , Edge (AtomId 2) (AtomId 10)
      , Edge (AtomId 3) (AtomId 4)
      , Edge (AtomId 3) (AtomId 9)
      , Edge (AtomId 3) (AtomId 12)
      , Edge (AtomId 4) (AtomId 11)
      , Edge (AtomId 4) (AtomId 13)
      , Edge (AtomId 4) (AtomId 14)
      , Edge (AtomId 5) (AtomId 6)
      , Edge (AtomId 5) (AtomId 7)
      , Edge (AtomId 5) (AtomId 15)
      , Edge (AtomId 6) (AtomId 16)
      , Edge (AtomId 6) (AtomId 17)
      , Edge (AtomId 6) (AtomId 18)
      , Edge (AtomId 7) (AtomId 8)
      , Edge (AtomId 7) (AtomId 19)
      , Edge (AtomId 8) (AtomId 20)
      , Edge (AtomId 8) (AtomId 21)
      , Edge (AtomId 8) (AtomId 22)
      , Edge (AtomId 10) (AtomId 23)
      , Edge (AtomId 10) (AtomId 24)
      , Edge (AtomId 10) (AtomId 25)
      ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 2)]) Just ("single"))
      , (SystemId 2, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 3)]) Just ("single"))
      , (SystemId 3, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 3) (AtomId 4)]) Just ("single"))
      , (SystemId 4, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 5)]) Just ("single"))
      , (SystemId 5, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 5) (AtomId 6)]) Just ("single"))
      , (SystemId 6, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 5) (AtomId 7)]) Just ("single"))
      , (SystemId 7, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 7) (AtomId 8)]) Just ("single"))
      , (SystemId 8, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 3) (AtomId 9)]) Just ("single"))
      , (SystemId 9, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 2) (AtomId 10)]) Just ("single"))
      , (SystemId 10, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 4) (AtomId 11)]) Just ("single"))
      , (SystemId 11, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 3) (AtomId 12)]) Just ("single"))
      , (SystemId 12, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 4) (AtomId 13)]) Just ("single"))
      , (SystemId 13, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 4) (AtomId 14)]) Just ("single"))
      , (SystemId 14, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 5) (AtomId 15)]) Just ("single"))
      , (SystemId 15, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 6) (AtomId 16)]) Just ("single"))
      , (SystemId 16, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 6) (AtomId 17)]) Just ("single"))
      , (SystemId 17, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 6) (AtomId 18)]) Just ("single"))
      , (SystemId 18, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 7) (AtomId 19)]) Just ("single"))
      , (SystemId 19, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 8) (AtomId 20)]) Just ("single"))
      , (SystemId 20, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 8) (AtomId 21)]) Just ("single"))
      , (SystemId 21, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 8) (AtomId 22)]) Just ("single"))
      , (SystemId 22, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 10) (AtomId 23)]) Just ("single"))
      , (SystemId 23, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 10) (AtomId 24)]) Just ("single"))
      , (SystemId 24, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 10) (AtomId 25)]) Just ("single"))
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }))
