{-# LANGUAGE ScopedTypeVariables #-}

-- | Property-based tests targeting the molecular validator.  The suite checks
-- invariants of the benzene example under structural transformations.
module Main (main) where

import Test.QuickCheck
import ExampleMolecules.Benzene (benzene)
import Chem.IO.SMILES (parseSMILES)
import Chem.Molecule
import Chem.Dietz
import Chem.Validate (validateMolecule, usedElectronsAt)
import qualified Data.Map.Strict as M
import qualified Data.Set as S

-- | Relabel a molecule according to a permutation of its 'AtomId's.  All
-- structural data (atoms, bonds and Dietz systems) are updated consistently.
relabelMolecule :: Molecule -> [AtomId] -> Molecule
relabelMolecule m perm = Molecule atoms' bonds' systems' (smilesStereochemistry m)
  where
    oldIds   = M.keys (atoms m)
    mapping  = M.fromList (zip oldIds perm)
    rename i = mapping M.! i

    atoms' = M.fromList
      [ (rename i, a { atomID = rename i })
      | (i, a) <- M.toList (atoms m) ]

    bonds' = S.fromList
      [ mkEdge (rename i) (rename j)
      | Edge i j <- S.toList (localBonds m) ]

    systems' =
      [ ( sid
        , mkBondingSystem (sharedElectrons bs)
                          (S.fromList [ mkEdge (rename i) (rename j)
                                       | Edge i j <- S.toList (memberEdges bs) ])
                          (tag bs))
      | (sid, bs) <- systems m
      ]

-- | Property: validation result is invariant under AtomId relabelling.
prop_permInvariant :: Property
prop_permInvariant = forAll genPerm $ \perm ->
  let mol' = relabelMolecule benzene perm
  in isRight (validateMolecule mol') === isRight (validateMolecule benzene)
  where
    genPerm = shuffle (M.keys (atoms benzene))
    isRight (Right _) = True
    isRight _         = False

-- | Property: each ring carbon gains one electron from the \(\pi\) system in
-- addition to its local \(\sigma\) bonds (total of four electrons).
prop_benzeneElectronAccounting :: Property
prop_benzeneElectronAccounting = conjoin
  [ counterexample ("Atom " ++ show i) $
      let sigma  = fromIntegral (length (neighborsSigma benzene i))
          total  = usedElectronsAt benzene i
          system = total - sigma
      in system === 1.0 .&&. total === 4.0
  | i <- ringCarbons ]
  where
    ringCarbons = map AtomId [1..6]

-- | Execute the QuickCheck properties defined above.
main :: IO ()
main = do
  quickCheck prop_permInvariant
  quickCheck prop_benzeneElectronAccounting
  case parseSMILES "CC1(C)CN(C(=O)Nc2cc3ccccc3nn2)C[C@@]2(CCOC2)O1" of
    Left err -> error ("Unexpected parse failure in documented ZINC validation case: " ++ err)
    Right mol ->
      case validateMolecule mol of
        Left err ->
          if err == "Atom 11 exceeds maximum valence"
            then pure ()
            else error ("Unexpected validation failure message: " ++ err)
        Right _ ->
          error "Expected documented ZINC validation failure, but validation unexpectedly succeeded"
