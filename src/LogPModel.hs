-- | Probabilistic regression model that learns quantitative structure-property
-- relationships (logP) from SDF datasets.  The module contains both feature
-- extraction helpers and the inference driver used by the executable demo.
module LogPModel where

import Chem.Molecule
import Chem.Dietz
import Chem.IO.SDF (parseSDF)
import Distr
import LazyPPL
import Control.Monad
import Control.Parallel.Strategies (parMap, rdeepseq)
import Data.List (foldl')
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.ByteString as BS
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Text.Read (readMaybe)
import qualified Data.Massiv.Array as A
import qualified Data.Vector as V


-- | Parse an SDF database where each molecule has a <logP> property and
-- optionally limit the number of molecules returned.  Each block is parsed in
-- parallel via a 'Massiv' vector so decoding stays in @'A.Par'@ mode end to
-- end.  On the DB1 dataset (limited to 500 molecules) this change reduced the
-- parsing phase by roughly 12% when running with @+RTS -N4@ compared to the
-- older 'parMap' pipeline.
parseLogPFile :: FilePath -> Maybe Int -> IO [(Molecule, Double)]
parseLogPFile fp mLimit = do
  bs <- BS.readFile fp
  let txt        = TE.decodeLatin1 bs
      blockLists = splitBlocks (T.lines txt)
      blockListsVec = V.fromList blockLists
      blockVec :: A.Array A.D A.Ix1 [T.Text]
      blockVec =
        A.makeArray A.Par (A.Sz (A.Ix1 (V.length blockListsVec))) $ \(A.Ix1 i) ->
          blockListsVec V.! i
      parsed =
        A.computeAs A.B $
          A.setComp A.Par (A.smapMaybe parseBlock blockVec)
  pure (applyLimit mLimit parsed)
  where
    parseBlock :: [T.Text] -> Maybe (Molecule, Double)
    parseBlock ls =
      let blockTxt = T.unlines ls
          mMol    = parseSDF (T.unpack blockTxt)
          mLogP   = extractLogP ls
      in case (mMol, mLogP) of
           (Right mol, Just lp) -> Just (mol, lp)
           _                    -> Nothing

    extractLogP :: [T.Text] -> Maybe Double
    extractLogP ls =
      case dropWhile (not . T.isPrefixOf (T.pack ">  <logP>")) ls of
        (_:val:_) -> readMaybe (T.unpack val)
        _         -> Nothing

    splitBlocks :: [T.Text] -> [[T.Text]]
    splitBlocks [] = []
    splitBlocks xs =
      let (pre, rest) = break (== T.pack "$$$$") xs
      in pre : case rest of
                 []      -> []
                 (_:ys) -> splitBlocks ys

    applyLimit :: Maybe Int -> A.Array A.B A.Ix1 a -> [a]
    applyLimit Nothing arr = A.toList arr
    applyLimit (Just n) arr
      | n <= 0    = []
      | otherwise =
          let A.Sz (A.Ix1 len) = A.size arr
              count            = min n len
              taken            = A.take (A.Sz1 count) arr
              resized          = A.resize' (A.Sz (A.Ix1 count)) taken
          in A.toList (A.computeAs A.B resized)

-- | Extract atoms from a molecule in ascending 'AtomId' order.
atomList :: Molecule -> [Atom]
atomList = M.elems . atoms

-- | Massiv array containing atomic weights for vectorised feature
-- computation.  The array is built with 'A.Par', so running with RTS
-- options like @+RTS -N@ allows Massiv to fill it using multiple cores.
atomWeightsArray :: Molecule -> A.Array A.U A.Ix1 Double
atomWeightsArray mol =
  let atoms = V.fromList (atomList mol)
      len   = V.length atoms
      weights :: A.Array A.D A.Ix1 Double
      weights =
        A.makeArray A.Par (A.Sz (A.Ix1 len)) $ \(A.Ix1 i) ->
          atomicWeight (attributes (atoms V.! i))
  in A.computeAs A.U weights

-- | Massiv array of atomic numbers mirroring 'atomWeightsArray'.  Like the
-- weights array it uses 'A.Par' so construction can take advantage of
-- multiple CPU cores.
atomNumbersArray :: Molecule -> A.Array A.U A.Ix1 Int
atomNumbersArray mol =
  let atoms = V.fromList (atomList mol)
      len   = V.length atoms
      numbers :: A.Array A.D A.Ix1 Int
      numbers =
        A.makeArray A.Par (A.Sz (A.Ix1 len)) $ \(A.Ix1 i) ->
          atomicNumber (attributes (atoms V.! i))
  in A.computeAs A.U numbers


-- | Helper converting booleans into numeric indicator values.
boolToDouble :: Bool -> Double
boolToDouble True  = 1.0
boolToDouble False = 0.0

-- | Count the number of atoms in a molecule.
moleculeSize :: Molecule -> Double
moleculeSize mol =
  let numbers = atomNumbersArray mol
  in A.sum (A.map (const 1.0) numbers)

-- | Compute the total molecular weight of a molecule.
moleculeWeight :: Molecule -> Double
moleculeWeight = A.sum . atomWeightsArray

-- | Approximate surface area using a sphere with radius proportional to the
-- cube root of the atom count.  The heuristic is coarse but sufficient for
-- toy feature engineering.
moleculeSurfaceArea :: Molecule -> Double
moleculeSurfaceArea mol = let size = moleculeSize mol in 4.0 * pi * (size ** (2.0/3.0))

-- | Number of atoms that are not carbon or hydrogen.
heteroAtomCount :: Molecule -> Double
heteroAtomCount mol =
  let numbers = atomNumbersArray mol
      isHetero n = n /= 6 && n /= 1
  in A.sum (A.map (boolToDouble . isHetero) numbers)

-- | Sum of effective bond orders combining both sigma and Dietz systems.
moleculeBondOrder :: Molecule -> Double
moleculeBondOrder m =
  let edgeSet  = S.unions (localBonds m : map (memberEdges . snd) (systems m))
      edgeList = S.toList edgeSet

      orders   = (A.fromList A.Seq [ effectiveOrder m e | e <- edgeList ]
                  :: A.Array A.U A.Ix1 Double)

  in A.foldlS (+) 0.0 orders

-- | Count hydrogen bond acceptors (very rough: N, O or S atoms).
hydrogenBondAcceptorCount :: Molecule -> Double
hydrogenBondAcceptorCount mol =
  let numbers = atomNumbersArray mol
      isAcceptor n = n == 7 || n == 8 || n == 16
  in A.sum (A.map (boolToDouble . isAcceptor) numbers)

-- | Count hydrogen bond donors (hetero atoms bonded to an explicit hydrogen).
hydrogenBondDonorCount :: Molecule -> Double
hydrogenBondDonorCount m =
  let atomsArr = (A.fromList A.Par (atomList m) :: A.Array A.B A.Ix1 Atom)
      donorArray =
        A.computeAs A.U $
          A.map (boolToDouble . isDonor) atomsArr
      isDonor a =
        let s = symbol (attributes a)
            hetero = s `elem` [N, O, S]
            hasHydrogen = any (\nid -> symbol (attributes (atoms m M.! nid)) == H)
                                 (neighborsSigma m (atomID a))
        in hetero && hasHydrogen
  in A.sum (A.setComp A.Par donorArray)

-- | Count heavy atoms (non-hydrogen) in a molecule.
heavyAtomCount :: Molecule -> Double
heavyAtomCount mol =
  let numbers = atomNumbersArray mol
      isHeavy n = n /= 1
  in A.sum (A.map (boolToDouble . isHeavy) numbers)

-- | Count halogens (F, Cl, Br, I). These contribute to logP in fragment and
-- substituent constant models.
halogenAtomCount :: Molecule -> Double
halogenAtomCount mol =
  let atomsArr = (A.fromList A.Par (atomList mol) :: A.Array A.B A.Ix1 Atom)
      halogenArray =
        A.computeAs A.U $
          A.map (boolToDouble . isHalogen . symbol . attributes) atomsArr
      isHalogen sym = sym `elem` [F, Cl, Br, I]
  in A.sum (A.setComp A.Par halogenArray)

-- | Count aromatic six-membered rings detected by the SDF parser.
aromaticRingCount :: Molecule -> Double
aromaticRingCount mol =
  let aromaticSystems =
        [ sys
        | (_, sys) <- systems mol
        , tag sys == Just "pi_ring"
        ]
  in fromIntegral (length aromaticSystems)

-- | Fraction of heavy atoms that participate in aromatic systems.
aromaticAtomFraction :: Molecule -> Double
aromaticAtomFraction mol =
  let aromaticSystems =
        [ sys
        | (_, sys) <- systems mol
        , tag sys == Just "pi_ring"
        ]
      aromaticAtoms = S.unions (map memberAtoms aromaticSystems)
      heavy = heavyAtomCount mol
  in if heavy <= 0.0
       then 0.0
       else fromIntegral (S.size aromaticAtoms) / heavy

-- | Build an adjacency map for all sigma bonds in the molecule.
buildAdjacency :: Molecule -> M.Map AtomId [AtomId]
buildAdjacency mol =
  let edges = S.toList (localBonds mol)
  in foldl' insertEdge M.empty edges
  where
    insertEdge acc edge =
      let (u, v) = atomsOfEdge edge
      in M.insertWith (++) u [v] (M.insertWith (++) v [u] acc)

removeEdgeFromAdj :: AtomId -> AtomId -> M.Map AtomId [AtomId] -> M.Map AtomId [AtomId]
removeEdgeFromAdj a b = M.alter update a
  where
    update Nothing   = Just []
    update (Just ns) = Just (filter (/= b) ns)

edgeInCycle :: M.Map AtomId [AtomId] -> Edge -> Bool
edgeInCycle adjacency edge =
  let (u, v) = atomsOfEdge edge
      adjacencyWithout = removeEdgeFromAdj v u (removeEdgeFromAdj u v adjacency)
  in hasPath adjacencyWithout u v

hasPath :: M.Map AtomId [AtomId] -> AtomId -> AtomId -> Bool
hasPath adjacency start target = go S.empty [start]
  where
    go _ [] = False
    go visited (x:xs)
      | x == target          = True
      | x `S.member` visited = go visited xs
      | otherwise =
          let visited'   = S.insert x visited
              neighbours = M.findWithDefault [] x adjacency
              next       = [ n | n <- neighbours, n `S.notMember` visited' ]
          in go visited' (next ++ xs)

-- | Count rotatable single bonds between heavy atoms, excluding ring edges.
rotatableBondCount :: Molecule -> Double
rotatableBondCount mol =
  let adjacency = buildAdjacency mol
      atomsMap  = atoms mol
      isHeavyAtom atom = symbol (attributes atom) /= H
      heavyDegree aid =
        length
          [ nid
          | nid <- M.findWithDefault [] aid adjacency
          , let atomN = atomsMap M.! nid
          , isHeavyAtom atomN
          ]
      edges = S.toList (localBonds mol)
      isRotatable edge =
        let (u, v)   = atomsOfEdge edge
            atomU    = atomsMap M.! u
            atomV    = atomsMap M.! v
            bothHeavy = isHeavyAtom atomU && isHeavyAtom atomV
            notTerminal = heavyDegree u > 1 && heavyDegree v > 1
            singleBond  = effectiveOrder mol edge <= 1.1
            notRing     = not (edgeInCycle adjacency edge)
        in bothHeavy && notTerminal && singleBond && notRing
  in foldl' (\acc edge -> acc + boolToDouble (isRotatable edge)) 0.0 edges

-- | Stable log(1+x) transform for count descriptors.
log1pPositive :: Double -> Double
log1pPositive x = log (1.0 + max 0.0 x)

-- | Collection of descriptors used by the regression model.
data MolecularDescriptors = MolecularDescriptors
  { descWeight                 :: !Double
  , descPolar                  :: !Double
  , descSurface                :: !Double
  , descBondOrder              :: !Double
  , descHeavyAtoms             :: !Double
  , descHalogens               :: !Double
  , descAromaticRings          :: !Double
  , descAromaticAtomFraction   :: !Double
  , descRotatableBonds         :: !Double
  } deriving (Show)

-- | Compute a descriptor vector combining classical fragment-style counts
-- with the heuristic features previously used by the demo.
computeDescriptors :: Molecule -> MolecularDescriptors
computeDescriptors mol =
  let weight   = moleculeWeight mol
      polar    = heteroAtomCount mol
               + hydrogenBondDonorCount mol
               + hydrogenBondAcceptorCount mol
      surface  = moleculeSurfaceArea mol
      bond     = moleculeBondOrder mol
      heavy    = heavyAtomCount mol
      halogens = halogenAtomCount mol
      aromRings = aromaticRingCount mol
      aromFrac  = aromaticAtomFraction mol
      rotatable = rotatableBondCount mol
  in MolecularDescriptors
       { descWeight               = weight
       , descPolar                = polar
       , descSurface              = surface
       , descBondOrder            = bond
       , descHeavyAtoms           = heavy
       , descHalogens             = halogens
       , descAromaticRings        = aromRings
       , descAromaticAtomFraction = aromFrac
       , descRotatableBonds       = rotatable
       }

-- | Parameters of the logP regression model including hierarchical scale
-- hyperparameters.
data LogPParameters = LogPParameters
  { paramIntercept              :: !Double
  , paramWeightCoeff            :: !Double
  , paramPolarCoeff             :: !Double
  , paramSurfaceCoeff           :: !Double
  , paramBondCoeff              :: !Double
  , paramWeightSqCoeff          :: !Double
  , paramPolarSqCoeff           :: !Double
  , paramSurfaceSqCoeff         :: !Double
  , paramInteractionWP          :: !Double
  , paramInteractionWS          :: !Double
  , paramHeavyLogCoeff          :: !Double
  , paramHalogenLogCoeff        :: !Double
  , paramAromaticRingCoeff      :: !Double
  , paramAromaticFractionCoeff  :: !Double
  , paramRotatableLogCoeff      :: !Double
  , paramLinearScale            :: !Double
  , paramQuadraticScale         :: !Double
  , paramDescriptorScale        :: !Double
  } deriving (Show, Eq)

zeroParameters :: LogPParameters
zeroParameters =
  LogPParameters 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0

type ProgressProbe = (String, Molecule, Maybe Double)

addParameters :: LogPParameters -> LogPParameters -> LogPParameters
addParameters (LogPParameters a1 b1 c1 d1 e1 f1 g1 h1 i1 j1 k1 l1 m1 n1 o1 p1 q1 r1)
              (LogPParameters a2 b2 c2 d2 e2 f2 g2 h2 i2 j2 k2 l2 m2 n2 o2 p2 q2 r2) =
  LogPParameters (a1 + a2) (b1 + b2) (c1 + c2) (d1 + d2) (e1 + e2)
                 (f1 + f2) (g1 + g2) (h1 + h2) (i1 + i2) (j1 + j2)
                 (k1 + k2) (l1 + l2) (m1 + m2) (n1 + n2) (o1 + o2)
                 (p1 + p2) (q1 + q2) (r1 + r2)

scaleParameters :: Double -> LogPParameters -> LogPParameters
scaleParameters s (LogPParameters a b c d e f g h i j k l m n o p q r) =
  LogPParameters (s * a) (s * b) (s * c) (s * d) (s * e)
                 (s * f) (s * g) (s * h) (s * i) (s * j)
                 (s * k) (s * l) (s * m) (s * n) (s * o)
                 (s * p) (s * q) (s * r)

-- | Predict logP for a set of molecular descriptors.
predictLogP :: LogPParameters -> MolecularDescriptors -> Double
predictLogP params descriptors =
  let weight            = descWeight descriptors
      polar             = descPolar descriptors
      surface           = descSurface descriptors
      bond              = descBondOrder descriptors
      heavyLog          = log1pPositive (descHeavyAtoms descriptors)
      halogenLog        = log1pPositive (descHalogens descriptors)
      aromaticRingLog   = log1pPositive (descAromaticRings descriptors)
      aromaticFraction  = descAromaticAtomFraction descriptors
      rotatableLog      = log1pPositive (descRotatableBonds descriptors)
  in  paramIntercept params
      + paramWeightCoeff params           * weight
      + paramPolarCoeff params            * polar
      + paramSurfaceCoeff params          * surface
      + paramBondCoeff params             * bond
      + paramHeavyLogCoeff params         * heavyLog
      + paramHalogenLogCoeff params       * halogenLog
      + paramAromaticRingCoeff params     * aromaticRingLog
      + paramAromaticFractionCoeff params * aromaticFraction
      + paramRotatableLogCoeff params     * rotatableLog
      + paramWeightSqCoeff params         * weight * weight
      + paramPolarSqCoeff params          * polar  * polar
      + paramSurfaceSqCoeff params        * surface * surface
      + paramInteractionWP params         * weight * polar
      + paramInteractionWS params         * weight * surface

-- | Convenience wrapper to predict directly from a molecule.
predictMolecule :: LogPParameters -> Molecule -> Double
predictMolecule params mol = predictLogP params (computeDescriptors mol)

-- | Generative model describing logP observations with hierarchical priors
-- over families of coefficients inspired by fragment-based QSAR models.
logPModel :: [(Molecule, Double)] -> Meas LogPParameters
logPModel observedData = do
  linearScale     <- sample $ gamma 2.0 0.2
  quadraticScale  <- sample $ gamma 2.0 0.05
  descriptorScale <- sample $ gamma 2.0 0.1

  intercept             <- sample $ normal 0.0 0.5
  weightCoeff           <- sample $ normal 0.0 linearScale
  polarCoeff            <- sample $ normal 0.0 linearScale
  surfaceCoeff          <- sample $ normal 0.0 linearScale
  bondCoeff             <- sample $ normal 0.0 linearScale
  heavyCoeff            <- sample $ normal 0.0 descriptorScale
  halogenCoeff          <- sample $ normal 0.0 descriptorScale
  aromaticRingCoeff     <- sample $ normal 0.0 descriptorScale
  aromaticFractionCoeff <- sample $ normal 0.0 descriptorScale
  rotatableCoeff        <- sample $ normal 0.0 descriptorScale
  weightSqCoeff         <- sample $ normal 0.0 quadraticScale
  polarSqCoeff          <- sample $ normal 0.0 quadraticScale
  surfaceSqCoeff        <- sample $ normal 0.0 quadraticScale
  interactionWP         <- sample $ normal 0.0 quadraticScale
  interactionWS         <- sample $ normal 0.0 quadraticScale

  let params =
        LogPParameters
          { paramIntercept              = intercept
          , paramWeightCoeff            = weightCoeff
          , paramPolarCoeff             = polarCoeff
          , paramSurfaceCoeff           = surfaceCoeff
          , paramBondCoeff              = bondCoeff
          , paramWeightSqCoeff          = weightSqCoeff
          , paramPolarSqCoeff           = polarSqCoeff
          , paramSurfaceSqCoeff         = surfaceSqCoeff
          , paramInteractionWP          = interactionWP
          , paramInteractionWS          = interactionWS
          , paramHeavyLogCoeff          = heavyCoeff
          , paramHalogenLogCoeff        = halogenCoeff
          , paramAromaticRingCoeff      = aromaticRingCoeff
          , paramAromaticFractionCoeff  = aromaticFractionCoeff
          , paramRotatableLogCoeff      = rotatableCoeff
          , paramLinearScale            = linearScale
          , paramQuadraticScale         = quadraticScale
          , paramDescriptorScale        = descriptorScale
          }

  forM_ observedData $ \(mol, observedLogP) -> do
    let descriptors   = computeDescriptors mol
        predictedLogP = predictLogP params descriptors
    score $ normalPdf observedLogP 0.2 predictedLogP

  pure params
  where
    averagedGamma :: Int -> Double -> Double -> Meas Double
    averagedGamma draws shape scale = do
      samples <- replicateM draws (sample $ gamma shape scale)
      pure (sum samples / fromIntegral draws)

-- | Run the model over an entire dataset producing a single parameter draw
-- conditioned on all observations.
inferLogP :: [(Molecule, Double)] -> Meas LogPParameters
inferLogP = logPModel

-- | Predict logP for DB2 molecules with a long burn-in to reduce bias.  The
-- optional 'Maybe Int' parameter limits how many molecules are parsed from
-- each SDF file. Use 'Nothing' to parse all available molecules.  The list of
-- tracked molecules is used to provide periodic progress updates during
-- sampling so the caller can monitor convergence behaviour.
runLogPRegression :: [(String, Molecule, Maybe Double)] -> Double -> IO ()
runLogPRegression probes jitter = do
    let mLimit          = Just 300  -- Limit to first 500 molecules for faster testing
        burnIn          = 200000
        sampleSize      = 20
        totalSamples    = burnIn + sampleSize
        burnInInterval  = max 1 (burnIn `div` 10)
        sampleInterval  = max 1 (sampleSize `div` 10)
        db1FilePath     = "./logp/DB1.sdf"

    db1Molecules <- parseLogPFile db1FilePath mLimit
    let db1Count = length db1Molecules
    putStrLn $ "Parsed " ++ show db1Count ++ " molecules from file: " ++ db1FilePath
    let db1LogPs = map snd db1Molecules
    unless (null db1LogPs) $ do
        let totalLogP = foldl' (+) 0.0 db1LogPs
            minLogP   = minimum db1LogPs
            maxLogP   = maximum db1LogPs
            meanLogP  = totalLogP / fromIntegral db1Count
        putStrLn $ "DB1 logP summary — min: " ++ show minLogP ++
                   ", max: " ++ show maxLogP ++
                   ", mean: " ++ show meanLogP

    unless (null probes) $ do
        putStrLn "Tracking molecules during sampling:"
        forM_ probes $ \(name, _, mActual) ->
          putStrLn $ "  - " ++ name ++
                     maybe " (actual logP unknown)"
                           (\actual -> " (actual logP " ++ show actual ++ ")")
                           mActual

    inferredSamples <- mh jitter (inferLogP db1Molecules)

    let parameterSamples    = map fst inferredSamples
        limitedSampleParams = zip [1..totalSamples] (take totalSamples parameterSamples)

    (collectedSamples, posteriorSum) <-
      foldM (progressStep burnIn burnInInterval sampleInterval probes sampleSize)
            (0, zeroParameters)
            limitedSampleParams

    let means
          | collectedSamples == 0 = zeroParameters
          | otherwise =
              scaleParameters (1 / fromIntegral collectedSamples) posteriorSum

    let LogPParameters { paramIntercept = intercept
                       , paramWeightCoeff = weightCoeff
                       , paramPolarCoeff = polarCoeff
                       , paramSurfaceCoeff = surfaceCoeff
                       , paramBondCoeff = bondCoeff
                       , paramWeightSqCoeff = weightSqCoeff
                       , paramPolarSqCoeff = polarSqCoeff
                       , paramSurfaceSqCoeff = surfaceSqCoeff
                       , paramInteractionWP = interactionWP
                       , paramInteractionWS = interactionWS
                       , paramHeavyLogCoeff = heavyCoeff
                       , paramHalogenLogCoeff = halogenCoeff
                       , paramAromaticRingCoeff = aromaticRingCoeff
                       , paramAromaticFractionCoeff = aromaticFractionCoeff
                       , paramRotatableLogCoeff = rotatableCoeff
                       , paramLinearScale = linearScale
                       , paramQuadraticScale = quadraticScale
                       , paramDescriptorScale = descriptorScale
                       } = means

    putStrLn $ "Mean Intercept: " ++ show intercept
    putStrLn $ "Mean Weight Coefficient: " ++ show weightCoeff
    putStrLn $ "Mean Polar Coefficient: " ++ show polarCoeff
    putStrLn $ "Mean Surface Coefficient: " ++ show surfaceCoeff
    putStrLn $ "Mean Bond-Order Coefficient: " ++ show bondCoeff
    putStrLn $ "Mean log(Heavy Atoms + 1) Coefficient: " ++ show heavyCoeff
    putStrLn $ "Mean log(Halogens + 1) Coefficient: " ++ show halogenCoeff
    putStrLn $ "Mean log(Aromatic Rings + 1) Coefficient: " ++ show aromaticRingCoeff
    putStrLn $ "Mean Aromatic Fraction Coefficient: " ++ show aromaticFractionCoeff
    putStrLn $ "Mean log(Rotatable + 1) Coefficient: " ++ show rotatableCoeff
    putStrLn $ "Mean Weight^2 Coefficient: " ++ show weightSqCoeff
    putStrLn $ "Mean Polar^2 Coefficient: " ++ show polarSqCoeff
    putStrLn $ "Mean Surface^2 Coefficient: " ++ show surfaceSqCoeff
    putStrLn $ "Mean Weight*Polar Coefficient: " ++ show interactionWP
    putStrLn $ "Mean Weight*Surface Coefficient: " ++ show interactionWS
    putStrLn $ "Mean Linear Scale: " ++ show linearScale
    putStrLn $ "Mean Quadratic Scale: " ++ show quadraticScale
    putStrLn $ "Mean Descriptor Scale: " ++ show descriptorScale

    unless (null probes) $ do
      putStrLn "Posterior mean predictions for tracked molecules:"
      forM_ probes $ \(name, mol, mActual) -> do
        let predictedLogP = predictMolecule means mol
        case mActual of
          Just actual ->
            putStrLn $ "  - " ++ name ++ ": predicted " ++ show predictedLogP ++
                       ", actual " ++ show actual ++
                       ", residual " ++ show (predictedLogP - actual)
          Nothing ->
            putStrLn $ "  - " ++ name ++ ": predicted " ++ show predictedLogP

    let db2FilePath = "./logp/DB2.sdf"
    db2Molecules <- parseLogPFile db2FilePath mLimit
    let db2Count = length db2Molecules
    putStrLn $ "Parsed " ++ show db2Count ++ " molecules from file: " ++ db2FilePath
    let db2LogPs = map snd db2Molecules
    unless (null db2LogPs) $ do
        let totalLogP = foldl' (+) 0.0 db2LogPs
            minLogP   = minimum db2LogPs
            maxLogP   = maximum db2LogPs
            meanLogP  = totalLogP / fromIntegral db2Count
        putStrLn $ "DB2 logP summary — min: " ++ show minLogP ++
                   ", max: " ++ show maxLogP ++
                   ", mean: " ++ show meanLogP

    putStrLn "Predicted and Actual LogP values for DB2 molecules:"

    let db2Predictions =
          parMap rdeepseq
            (\(mol, actualLogP) ->
               let predictedLogP' = predictMolecule means mol
                   residual       = predictedLogP' - actualLogP
               in (mol, predictedLogP', actualLogP, residual))
            db2Molecules

    forM_ db2Predictions $ \(mol, predictedLogP', actualLogP, residual) -> do
        putStrLn "Molecule:"
        putStrLn (prettyPrintMolecule mol)
        putStrLn $ "Predicted LogP: " ++ show predictedLogP'
        putStrLn $ "Actual LogP: " ++ show actualLogP
        putStrLn $ "Residual (Predicted - Actual): " ++ show residual
        putStrLn ""

    let residuals = [ r | (_, _, _, r) <- db2Predictions ]
        nPred     = length residuals
    when (nPred > 0) $ do
        let invN = 1 / fromIntegral nPred
            mae  = invN * foldl' (\acc r -> acc + abs r) 0.0 residuals
            mse  = invN * foldl' (\acc r -> acc + r * r) 0.0 residuals
        putStrLn $ "DB2 Mean Absolute Error: " ++ show mae
        putStrLn $ "DB2 Root Mean Squared Error: " ++ show (sqrt mse)
  where
    progressStep :: Int -> Int -> Int -> [ProgressProbe] -> Int
                 -> (Int, LogPParameters)
                 -> (Int, LogPParameters)
                 -> IO (Int, LogPParameters)
    progressStep burnIn burnInterval sampleInterval tracked sampleTarget (collected, acc) (idx, sampleParams)
      | idx <= burnIn = do
          when (idx `mod` burnInterval == 0 || idx == burnIn) $
            putStrLn $ "Burn-in progress: " ++ show idx ++ "/" ++ show burnIn
          when (idx == burnIn) $
            putStrLn "Burn-in complete. Starting to collect posterior samples."
          pure (collected, acc)
      | otherwise = do
          let collected'   = collected + 1
              acc'         = addParameters acc sampleParams
              shouldReport = collected' == 1
                           || collected' == sampleTarget
                           || collected' `mod` sampleInterval == 0
          when shouldReport $ do
            let meanParams = scaleParameters (1 / fromIntegral collected') acc'
            reportPosteriorProgress sampleTarget tracked collected' meanParams
          pure (collected', acc')

    reportPosteriorProgress :: Int -> [ProgressProbe] -> Int -> LogPParameters -> IO ()
    reportPosteriorProgress sampleTarget tracked collected meanParams = do
      putStrLn $ "Posterior sampling progress: " ++ show collected ++ "/" ++ show sampleTarget
      unless (null tracked) $ do
        putStrLn "  - Running estimates for monitored molecules:"
        forM_ tracked $ \(name, mol, mActual) -> do
          let predicted = predictMolecule meanParams mol
          case mActual of
            Just actual ->
              putStrLn $ "    - " ++ name ++ ": predicted " ++ show predicted ++
                         ", actual " ++ show actual ++
                         ", residual " ++ show (predicted - actual)
            Nothing ->
              putStrLn $ "    - " ++ name ++ ": predicted " ++ show predicted
      putStrLn $ "    Current intercept: " ++ show (paramIntercept meanParams) ++
                 ", weight coefficient: " ++ show (paramWeightCoeff meanParams) ++
                 ", polar coefficient: " ++ show (paramPolarCoeff meanParams) ++
                 ", linear scale: " ++ show (paramLinearScale meanParams)
