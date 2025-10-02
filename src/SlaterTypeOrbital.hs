-- | Probabilistic utilities centred on Slater-type orbitals (STOs).  The
-- routines provide both analytic properties (normalisation, radial density)
-- and sampling support used in generative examples.
module SlaterTypeOrbital where

import Orbital (PureOrbital(..))
import Chem.Molecule.Coordinate (Coordinate(..), mkAngstrom)
import Chem.Dietz ()
import LazyPPL (Prob, Meas, sample)
import Distr (gamma, uniformbounded)

-- | A Slater Type Orbital parameterised by principal quantum number,
-- effective charge and angular component.
data SlaterTypeOrbital = SlaterTypeOrbital
  { stoPrincipalQuantumNumber :: Int
  , stoZeta                   :: Double
  , stoAngularComponent       :: PureOrbital
  } deriving (Show, Eq, Read)

-- | Closed-form normalisation constant for the radial part of the STO.
normConstant :: SlaterTypeOrbital -> Double
normConstant (SlaterTypeOrbital n z _) =
  let fact = fromIntegral (product [1 .. 2 * n])
  in (2 * z) ** (fromIntegral n + 0.5) / sqrt fact

-- | Radial part of the STO wavefunction.
radialPart :: SlaterTypeOrbital -> Double -> Double
radialPart sto@(SlaterTypeOrbital n z _) r =
  normConstant sto * r ** fromIntegral (n - 1) * exp (-z * r)

-- | Radial probability density @r^2 |R(r)|^2@.
radialPdf :: SlaterTypeOrbital -> Double -> Double
radialPdf sto r =
  let rp = radialPart sto r
  in rp * rp * r * r

-- | Sample a radial distance using the equivalence with the gamma
-- distribution for STOs.
sampleRadius :: SlaterTypeOrbital -> Prob Double
sampleRadius (SlaterTypeOrbital n z _) =
  gamma (fromIntegral (2 * n + 1)) (1 / (2 * z))

-- | Sample a three-dimensional coordinate from the orbital assuming a
-- uniform angular distribution over the sphere.
sampleCoordinate :: SlaterTypeOrbital -> Meas Coordinate
sampleCoordinate sto = do
  r <- sample $ sampleRadius sto
  theta <- sample $ uniformbounded 0 (2 * pi)
  phi <- sample $ uniformbounded 0 pi
  let x = r * sin phi * cos theta
      y = r * sin phi * sin theta
      z = r * cos phi
  return (Coordinate (mkAngstrom x) (mkAngstrom y) (mkAngstrom z))
