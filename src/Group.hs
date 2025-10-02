-- | Minimal group structure capturing rigid rotations applied to molecules.
-- The implementation is intentionally simplistic and does not attempt to
-- normalise axes; it merely demonstrates how symmetry operations could be
-- modelled.
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
