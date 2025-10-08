{-# LANGUAGE OverloadedStrings #-}

-- | Validation routines for Dietz-based molecules.  The validator enforces
-- structural invariants (existing atoms, symmetric bond maps, reasonable
-- valence counts) and returns the molecule unchanged on success.
module Chem.Validate
  ( validateMolecule
  , usedElectronsAt
  ) where

import           Chem.Molecule
import           Chem.Dietz
import           Constants (getMaxBondsSymbol)
import qualified Data.Map.Strict as M
import qualified Data.Set        as S
import           Control.Monad   (foldM)

-- | Total electrons used at an atom, combining σ bonds and Dietz pools.
-- Uses the Dietz pool formula: e_S(v) = s * deg_S(v) / (2*|E_S|).
usedElectronsAt :: Molecule -> AtomId -> Double
usedElectronsAt m v = sigma + system
  where
    sigma = fromIntegral (length (neighborsSigma m v))
    system = sum [ ePart v bs | (_, bs) <- systems m ]

    ePart :: AtomId -> BondingSystem -> Double
    ePart a bs =
      let degSv = fromIntegral $ length
                    [ ()
                    | Edge x y <- S.toList (memberEdges bs)
                    , x == a || y == a ]
          s = fromIntegral (getNN (sharedElectrons bs))
          totalEdges = fromIntegral (S.size (memberEdges bs))
      in if totalEdges == 0 then 0 else s * degSv / (2 * totalEdges)

type BondMap = M.Map (AtomId, AtomId) Double

-- | Validate a molecule according to Dietz bonding rules.
validateMolecule :: Molecule -> Either String Molecule
validateMolecule m = do
  let atomIDsList = M.keys (atoms m)
      atomSet     = S.fromList atomIDsList

  sigmaMap <- foldM (accumulateBond atomSet 2.0) M.empty (S.toList (localBonds m))
  let addSystem acc (_, bs) = addSystemBonds atomSet bs acc
  fullMap <- foldM addSystem sigmaMap (systems m)
  ensureSymmetric fullMap
  ensureValence m atomSet fullMap
  pure m

-- | Insert a bond contribution into the directed bond map, performing the
-- endpoint and self-bond checks mandated by the validator specification.
accumulateBond :: S.Set AtomId -> Double -> BondMap -> Edge -> Either String BondMap
accumulateBond atomSet value acc (Edge i j)
  | i == j = Left $ "Atom " ++ showAtomId i ++ " is bonded to itself"
  | not (i `S.member` atomSet) || not (j `S.member` atomSet)
      = Left "Bond references non-existent atom"
  | otherwise = Right $ addDirected i j value (addDirected j i value acc)
  where
    showAtomId (AtomId n) = show n

-- | Accumulate contributions from a Dietz bonding system by distributing the
-- shared electrons across its member edges.
addSystemBonds :: S.Set AtomId -> BondingSystem -> BondMap -> Either String BondMap
addSystemBonds atomSet bs acc
  | edgeCount == 0 = Right acc
  | otherwise      = foldM insertEdge acc (S.toList (memberEdges bs))
  where
    edgeCount = S.size (memberEdges bs)
    contribution = fromIntegral (getNN (sharedElectrons bs))
                 / fromIntegral edgeCount

    insertEdge m (Edge i j)
      | i == j = Left $ "Atom " ++ showAtomId i ++ " is bonded to itself"
      | not (i `S.member` atomSet) || not (j `S.member` atomSet)
          = Left "Bond references non-existent atom"
      | otherwise = Right $ addDirected i j contribution (addDirected j i contribution m)

    showAtomId (AtomId n) = show n

-- | Ensure that for every directed bond entry (i,j) there exists a mirrored
-- entry (j,i) with the same contribution.
ensureSymmetric :: BondMap -> Either String ()
ensureSymmetric bonds = foldM check () (M.toList bonds)
  where
    check _ ((i,j), val) =
      case M.lookup (j,i) bonds of
        Nothing   -> Left "Bond map is not symmetric"
        Just val' ->
          if approxEqual val val'
            then Right ()
            else Left "Bond map is not symmetric"

-- | Verify that each atom respects its maximum valence according to the
-- element-specific bound.
ensureValence :: Molecule -> S.Set AtomId -> BondMap -> Either String ()
ensureValence mol atomSet bonds =
  foldM check () (S.toList atomSet)
  where
    atomMap = atoms mol
    contributions i =
      [ val
      | ((a,_), val) <- M.toList bonds
      , a == i ]

    check _ aid =
      case M.lookup aid atomMap of
        Nothing -> Left "Bond references non-existent atom"
        Just atom ->
          let total    = sum (contributions aid)
              used     = total / 2.0
              maxVal   = getMaxBondsSymbol (symbol (attributes atom))
          in if used <= maxVal + 1e-9
                then Right ()
                else Left $ "Atom " ++ showAtomId aid ++ " exceeds maximum valence"

    showAtomId (AtomId n) = show n

-- | Insert a directed bond contribution, summing if an entry already exists.
addDirected :: AtomId -> AtomId -> Double -> BondMap -> BondMap
addDirected i j value = M.insertWith (+) (i, j) value

-- | Approximate equality used when comparing symmetric bond contributions.
approxEqual :: Double -> Double -> Bool
approxEqual a b = abs (a - b) <= 1e-9
