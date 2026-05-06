-- | Centralised physical and chemical constants used throughout the
-- molecular models.  Having a dedicated module keeps the domain knowledge
-- (bond lengths, valence limits, atomic metadata) in one place so other
-- modules can focus on behaviour.
module Constants where

import Chem.Molecule (AtomicSymbol(..), ElementAttributes(..), Angstrom(..), Shells, mkAngstrom)
import Chem.Dietz ()
import qualified Orbital as Orb
import qualified Data.Map.Strict as M

-- | Takes the bond order and two atomic symbols and gives the equilibrium
-- bond length between them (in Angstrom).  Only a small subset of common
-- covalent bonds are included; the lookup is symmetric in the atom labels.
type EquilibriumBondLength = Angstrom

equilibriumBondLengths :: Integer -> AtomicSymbol -> AtomicSymbol -> Maybe EquilibriumBondLength
equilibriumBondLengths bondOrder symbol1 symbol2 =
    M.lookup (bondOrder, s1, s2) bondLengthMap
  where
    (s1, s2) = normalize symbol1 symbol2

-- | Order a pair of atomic symbols to normalise map lookups.
normalize :: AtomicSymbol -> AtomicSymbol -> (AtomicSymbol, AtomicSymbol)
normalize a b
    | a <= b    = (a, b)
    | otherwise = (b, a)

-- | Lookup table for equilibrium bond lengths keyed by bond order and the
-- normalised pair of atomic symbols.
bondLengthMap :: M.Map (Integer, AtomicSymbol, AtomicSymbol) EquilibriumBondLength
bondLengthMap = M.fromList $ concat [order1, order2, order3]
  where
    order1 =
      [ ((1, H, H), mkAngstrom 0.74)
      , ((1, H, C), mkAngstrom 1.09)
      , ((1, H, N), mkAngstrom 1.01)
      , ((1, H, O), mkAngstrom 0.96)
      , ((1, H, Fe), mkAngstrom 1.52)
      , ((1, H, B), mkAngstrom 1.19)
      , ((1, C, C), mkAngstrom 1.54)
      , ((1, C, N), mkAngstrom 1.47)
      , ((1, C, O), mkAngstrom 1.43)
      , ((1, C, Fe), mkAngstrom 1.84)
      , ((1, C, B), mkAngstrom 1.55)
      , ((1, N, N), mkAngstrom 1.45)
      , ((1, N, O), mkAngstrom 1.40)
      , ((1, N, Fe), mkAngstrom 1.76)
      , ((1, N, B), mkAngstrom 1.55)
      , ((1, O, O), mkAngstrom 1.48)
      , ((1, O, Fe), mkAngstrom 1.70)
      , ((1, O, B), mkAngstrom 1.49)
      , ((1, Fe, Fe), mkAngstrom 2.48)
      , ((1, Fe, B), mkAngstrom 2.03)
      , ((1, B, B), mkAngstrom 1.59)
      ]
    order2 =
      [ ((2, H, H), mkAngstrom 0.74)
      , ((2, H, C), mkAngstrom 1.06)
      , ((2, H, N), mkAngstrom 1.01)
      , ((2, H, O), mkAngstrom 0.96)
      , ((2, H, Fe), mkAngstrom 1.52)
      , ((2, H, B), mkAngstrom 1.19)
      , ((2, C, C), mkAngstrom 1.34)
      , ((2, C, N), mkAngstrom 1.27)
      , ((2, C, O), mkAngstrom 1.20)
      , ((2, C, Fe), mkAngstrom 1.64)
      , ((2, C, B), mkAngstrom 1.37)
      , ((2, N, N), mkAngstrom 1.25)
      , ((2, N, O), mkAngstrom 1.20)
      , ((2, N, Fe), mkAngstrom 1.64)
      , ((2, N, B), mkAngstrom 1.33)
      , ((2, O, O), mkAngstrom 1.21)
      , ((2, O, Fe), mkAngstrom 1.58)
      , ((2, O, B), mkAngstrom 1.26)
      , ((2, Fe, Fe), mkAngstrom 2.26)
      , ((2, Fe, B), mkAngstrom 1.89)
      , ((2, B, B), mkAngstrom 1.59)
      ]
    order3 =
      [ ((3, H, H), mkAngstrom 0.74)
      , ((3, H, C), mkAngstrom 1.06)
      , ((3, H, N), mkAngstrom 1.01)
      , ((3, H, O), mkAngstrom 0.96)
      , ((3, H, Fe), mkAngstrom 1.52)
      , ((3, H, B), mkAngstrom 1.19)
      , ((3, C, C), mkAngstrom 1.20)
      , ((3, C, N), mkAngstrom 1.14)
      , ((3, C, O), mkAngstrom 1.13)
      , ((3, C, Fe), mkAngstrom 1.44)
      , ((3, C, B), mkAngstrom 1.19)
      , ((3, N, N), mkAngstrom 1.10)
      , ((3, N, O), mkAngstrom 1.06)
      , ((3, N, Fe), mkAngstrom 1.50)
      , ((3, N, B), mkAngstrom 1.20)
      , ((3, O, O), mkAngstrom 1.21)
      , ((3, O, Fe), mkAngstrom 1.58)
      , ((3, O, B), mkAngstrom 1.20)
      , ((3, Fe, Fe), mkAngstrom 2.26)
      , ((3, Fe, B), mkAngstrom 1.89)
      , ((3, B, B), mkAngstrom 1.59)
      ]

-- | Typical minimum and maximum number of electrons used in bonding for an
-- element.  The second component provides the upper limit used during
-- validation when checking that an atom does not exceed its usual electron
-- count according to a simple valence heuristic.
nominalValence :: AtomicSymbol -> (Int, Int)
nominalValence symbol = case symbol of
    H  -> (2, 2)
    C  -> (8, 8)
    N  -> (6, 6)
    O  -> (4, 4)
    F  -> (2, 2)
    P  -> (6, 10)
    Si -> (8, 8)
    S  -> (4, 12)
    Cl -> (2, 2)
    Br -> (2, 2)
    B  -> (6, 6)
    Fe -> (0, 12)
    I  -> (2, 2)
    Na -> (2, 2)

-- | Maximum number of bonds typically formed by an element, derived from the
-- upper electron count in 'nominalValence'.
getMaxBondsSymbol :: AtomicSymbol -> Double
getMaxBondsSymbol sym =
    let (_, maxElectrons) = nominalValence sym
    in fromIntegral maxElectrons / 2.0

-- | Tabulate atomic numbers, atomic weights, and default shell data for the
-- supported elements.
elementAttributes O = ElementAttributes O 8 15.999 (Just Orb.oxygen)
elementAttributes H = ElementAttributes H 1 1.008 (Just Orb.hydrogen)
elementAttributes N = ElementAttributes N 7 14.007 (Just Orb.nitrogen)
elementAttributes C = ElementAttributes C 6 12.011 (Just Orb.carbon)
elementAttributes B = ElementAttributes B 5 10.811 (Just Orb.boron)
elementAttributes Fe = ElementAttributes Fe 26 55.845 (Just Orb.iron)
elementAttributes F = ElementAttributes F 9 18.998 (Just Orb.fluorine)
elementAttributes Cl = ElementAttributes Cl 17 35.453 (Just Orb.chlorine)
elementAttributes S = ElementAttributes S 16 32.065 (Just Orb.sulfur)
elementAttributes Br = ElementAttributes Br 35 79.904 (Just Orb.bromine)
elementAttributes P = ElementAttributes P 15 30.974 (Just Orb.phosphorus)
elementAttributes Si = ElementAttributes Si 14 28.085 (Just Orb.silicon)
elementAttributes I = ElementAttributes I 53 126.904 (Just Orb.iodine)
elementAttributes Na = ElementAttributes Na 11 22.990 (Just Orb.sodium)

-- | Compatibility accessor for older code. New atom construction can take
-- shells from 'defaultShells' on 'elementAttributes'.
elementShells :: AtomicSymbol -> Shells
elementShells = defaultShells . elementAttributes
