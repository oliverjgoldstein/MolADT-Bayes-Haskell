{-# LANGUAGE MultiParamTypeClasses #-}

-- | Minimal algebraic structure for molecular symmetry examples.
--
-- Transformations such as rotations, translations, and atom relabelings are
-- often the group elements. A molecule is usually the value acted on by that
-- group. This module keeps the machinery small, but the type classes give
-- model code a Haskell-native place to state group and group-action laws.
module Group where
import Chem.Molecule
import Chem.Molecule.Coordinate (Coordinate(..), mkAngstrom)
import Chem.Dietz ()

-- | A simple rotation representation for molecules storing the rotation
-- axis and angle (in radians) alongside the affected 'Molecule'.
data MoleculeRotation = MoleculeRotation Molecule Coordinate Double deriving (Show)

class Group g where
  -- | Group operation combining two elements.
  mul :: g -> g -> g
  -- | Inverse of a group element.
  inv :: g -> g
  -- | Identity element for the group.
  e :: g -> g

-- | A group action on a value.
--
-- Laws for a lawful instance:
--
-- @
-- act (e g) x       == x
-- act (mul g h) x   == act g (act h x)
-- act (inv g) (act g x) == x
-- @
--
-- For geometric molecular models, this is the shape used to say that
-- rotations or relabelings act on 'Molecule' values while preserving the
-- chemistry that should be invariant.
class Group g => ActsOn g a where
  act :: g -> a -> a

-- | Compose and invert rotations by manipulating their angles.  We reuse the
-- first rotation's axis so that repeated compositions stay anchored to the
-- same reference frame.
instance Group MoleculeRotation where
  mul (MoleculeRotation mol1 axis1 angle1) (MoleculeRotation _ axis2 angle2) =
    combineRotations mol1 axis1 angle1 axis2 angle2
  inv (MoleculeRotation mol axis angle) = MoleculeRotation mol axis (-angle)
  e (MoleculeRotation mol _ _) = MoleculeRotation mol (Coordinate (mkAngstrom 0) (mkAngstrom 0) (mkAngstrom 0)) 0 -- Identity rotation

-- | Combine two successive rotations by adding their angles around the first
-- axis.  The function is agnostic of the actual 3D geometry; higher-fidelity
-- models would convert to rotation matrices instead.
combineRotations :: Molecule -> Coordinate -> Double -> Coordinate -> Double -> MoleculeRotation
combineRotations mol axis1 angle1 _ angle2 = MoleculeRotation mol axis1 (angle1 + angle2)
