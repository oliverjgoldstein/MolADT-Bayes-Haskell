-- | Hand-crafted description of benzene expressed with the core molecule
-- datatypes.  The module is useful both for unit tests and as a readable
-- example of how Dietz bonding systems are assembled.  The goal of this
-- module is pedagogy as much as correctness, so we deliberately trade a few
-- extra lines of code for clearer naming and a more direct mirroring of the
-- chemical structure.
module ExampleMolecules.Benzene
  ( benzene
  , benzenePretty
  ) where

import Chem.Molecule
import Chem.Dietz
import Constants (elementAttributes, elementShells)
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import ExampleMolecules.BenzenePretty (benzenePretty)

-- | Canonical benzene example consisting of six carbons and six hydrogens.
-- The ring carbons form both a sigma cycle and a delocalised \(\pi\)-system.
benzene :: Molecule
benzene = Molecule
  { atoms =
      M.fromList
        [ ( atomId
          , Atom { atomID       = atomId
                 , attributes   = elementAttributes sym
                 , coordinate   = Coordinate (mkAngstrom x)
                                               (mkAngstrom y)
                                               (mkAngstrom z)
                 , shells       = elementShells sym
                 , formalCharge = 0
                 }
          )
        | (i, sym, x, y, z) <- atomsData
        , let atomId = AtomId i
        ]
  , localBonds =
      S.fromList [edgeFromPair pair | pair <- sigmaEdges]
  , systems =
      [(SystemId 1, piSystem)]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
  where
    piSystem =
      mkBondingSystem
        (NonNegative (length ringCarbonIds))
        (S.fromList [edgeFromPair pair | pair <- ringEdges])
        (Just "pi_ring")

    edgeFromPair (a, b) = canonicalEdge (AtomId a) (AtomId b)

    canonicalEdge left right
      | left <= right = Edge left right
      | otherwise = Edge right left

    -- Carbon atoms occupy indices 1–6, hydrogens 7–12.
    ringCarbonIds = [1 .. 6]
    hydrogenIds   = [7 .. 12]

    ringEdges = zip ringCarbonIds (rotate ringCarbonIds)
    carbonHydrogenEdges = zip ringCarbonIds hydrogenIds
    sigmaEdges = ringEdges ++ carbonHydrogenEdges

    rotate [] = []
    rotate (x:xs) = xs ++ [x]

-- | Experimental geometry for the carbon ring (C1–C6) and hydrogens (H7–H12).
atomsData :: [(Integer, AtomicSymbol, Double, Double, Double)]
atomsData =
  [ ( 1, C, -1.2131, -0.6884, 0.0)
  , ( 2, C, -1.2028,  0.7064, 0.0)
  , ( 3, C, -0.0103, -1.3948, 0.0)
  , ( 4, C,  0.0104,  1.3948, 0.0)
  , ( 5, C,  1.2028, -0.7063, 0.0)
  , ( 6, C,  1.2131,  0.6884, 0.0)
  , ( 7, H, -2.1577, -1.2244, 0.0)
  , ( 8, H, -2.1393,  1.2564, 0.0)
  , ( 9, H, -0.0184, -2.4809, 0.0)
  , (10, H,  0.0184,  2.4808, 0.0)
  , (11, H,  2.1394, -1.2563, 0.0)
  , (12, H,  2.1577,  1.2245, 0.0)]
