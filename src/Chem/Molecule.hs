{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Molecule ADT built on Dietz constitution:
--   - atoms      : Map AtomId Atom (element data, charge, coordinates)
--   - localBonds : \963 adjacency as undirected edges (2e -> 1e per endpoint)
--   - systems    : Dietz bonding systems (delocalized/multicenter pools)
--   Distances/coordinates are stored in Angstroms.

module Chem.Molecule
  ( -- * Core types
    AtomicSymbol(..), ElementAttributes(..)
  , Angstrom(..), mkAngstrom, unAngstrom, Coordinate(..)
  , Shells
  , Atom(..)
  , SmilesAtomStereoClass(..)
  , SmilesBondStereoDirection(..)
  , SmilesAtomStereo(..)
  , SmilesBondStereo(..)
  , SmilesStereochemistry(..)
  , emptySmilesStereochemistry
  , Molecule(..)
    -- * Helpers
  , addSigma
  , distanceAngstrom
  , neighborsSigma
  , edgeSystems
  , effectiveOrder
  , prettyPrintShells
  , prettyPrintAtom
  , prettyPrintMolecule
  ) where

import           Control.DeepSeq (NFData)
import           GHC.Generics (Generic)
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import           Data.Set (Set)
import qualified Data.Set as S
import           Data.List (intercalate, sort, sortOn)
import           Data.Maybe (catMaybes)
import           Data.Char (toLower)
import           Data.Binary (Binary)
import           Text.Printf (printf)

import           Chem.Dietz
import           Chem.Molecule.Coordinate
import qualified Orbital as Orb

-- ===== Element + units =====

data AtomicSymbol = H | C | N | O | S | P | Si | F | Cl | Br | I | Fe | B | Na
  deriving (Eq, Ord, Show, Read, Generic, NFData)

data ElementAttributes = ElementAttributes
  { symbol       :: AtomicSymbol
  , atomicNumber :: Int
  , atomicWeight :: Double
  } deriving (Eq, Show, Read, Generic, NFData)

-- | Electronic shell structure for an atom.
--   Re-exported from "Orbital" to integrate with the molecular types.
type Shells = Orb.Shells

-- ===== Atoms =====

data Atom = Atom
  { atomID       :: AtomId
  , attributes   :: ElementAttributes
  , coordinate   :: Coordinate
  , shells       :: Shells
  , formalCharge :: Int       -- explicit charge; do NOT overload “unshared e−”
  } deriving (Eq, Show, Read, Generic, NFData)

data SmilesAtomStereoClass
  = StereoTetrahedral
  | StereoAllene
  | StereoSquarePlanar
  | StereoTrigonalBipyramidal
  | StereoOctahedral
  deriving (Eq, Ord, Show, Read, Generic, NFData)

data SmilesBondStereoDirection = BondUp | BondDown
  deriving (Eq, Ord, Show, Read, Generic, NFData)

data SmilesAtomStereo = SmilesAtomStereo
  { stereoCenter        :: AtomId
  , stereoClass         :: SmilesAtomStereoClass
  , stereoConfiguration :: Int
  , stereoToken         :: String
  } deriving (Eq, Show, Read, Generic, NFData)

data SmilesBondStereo = SmilesBondStereo
  { bondStereoStart     :: AtomId
  , bondStereoEnd       :: AtomId
  , bondStereoDirection :: SmilesBondStereoDirection
  } deriving (Eq, Show, Read, Generic, NFData)

data SmilesStereochemistry = SmilesStereochemistry
  { atomStereoAnnotations :: [SmilesAtomStereo]
  , bondStereoAnnotations :: [SmilesBondStereo]
  } deriving (Eq, Show, Read, Generic, NFData)

emptySmilesStereochemistry :: SmilesStereochemistry
emptySmilesStereochemistry = SmilesStereochemistry [] []

-- ===== Molecule (Dietz + \963) =====

data Molecule = Molecule
  { atoms      :: Map AtomId Atom             -- ^ V
  , localBonds :: Set Edge                    -- ^ \963 adjacency (2e bonds)
  , systems    :: [(SystemId, BondingSystem)] -- ^ B (each system is (s, E))
  , smilesStereochemistry :: SmilesStereochemistry
  } deriving (Eq, Show, Read, Generic, NFData)

-- ===== Small helpers =====

-- | Insert a \963 bond between two atoms (undirected).
addSigma :: AtomId -> AtomId -> Molecule -> Molecule
addSigma i j m = m { localBonds = S.insert (mkEdge i j) (localBonds m) }

-- | Euclidean distance between two atoms, returned in Angstroms.
distanceAngstrom :: Atom -> Atom -> Angstrom
distanceAngstrom a b =
  let Coordinate x1 y1 z1 = coordinate a
      Coordinate x2 y2 z2 = coordinate b
      dx = unAngstrom x1 - unAngstrom x2
      dy = unAngstrom y1 - unAngstrom y2
      dz = unAngstrom z1 - unAngstrom z2
  in mkAngstrom (sqrt (dx*dx + dy*dy + dz*dz))

-- | Sigma neighbors of a given atom (\963 bonds only).
neighborsSigma :: Molecule -> AtomId -> [AtomId]
neighborsSigma m i =
  [ if a == i then b else a
  | Edge a b <- S.toList (localBonds m)
  , a == i || b == i ]

-- | All Dietz bonding systems containing a given edge.
edgeSystems :: Molecule -> Edge -> [SystemId]
edgeSystems m e =
  [ sid
  | (sid, bs) <- systems m
  , e `S.member` memberEdges bs ]

-- | Effective bond order for an edge, combining \963 and delocalised systems.
effectiveOrder :: Molecule -> Edge -> Double
effectiveOrder m e = sigma + piContribution
  where
    sigma = if e `S.member` localBonds m then 1.0 else 0.0
    piContribution =
      sum [ fromIntegral (getNN (sharedElectrons bs))
              / (2.0 * fromIntegral (S.size (memberEdges bs)))
          | (_, bs) <- systems m
          , e `S.member` memberEdges bs
          ]

-- | Simple pretty printer for molecules.
prettyPrintMolecule :: Molecule -> String
prettyPrintMolecule m =
  renderLines $
    ["Molecule Report", "==============="]
      ++ summarySection atomList sigmaEdges systemList atomStereoList bondStereoList
      ++ [""]
      ++ sectionHeader "Atoms"
      ++ joinBlocks (map (formatAtomBlock m) atomList)
      ++ [""]
      ++ sectionHeader "Sigma Network"
      ++ sigmaSection
      ++ [""]
      ++ sectionHeader "Bonding Systems"
      ++ joinBlocks (map (formatSystemBlock m) systemList)
      ++ [""]
      ++ sectionHeader "SMILES Stereochemistry"
      ++ stereoSection
  where
    atomList   = M.toAscList (atoms m)
    sigmaEdges = sort (S.toList (localBonds m))
    systemList = sortOn fst (systems m)
    atomStereoList = sortOn stereoCenter (atomStereoAnnotations (smilesStereochemistry m))
    bondStereoList = sortOn (\item -> (bondStereoStart item, bondStereoEnd item, bondStereoDirection item)) (bondStereoAnnotations (smilesStereochemistry m))

    sigmaSection =
      case sigmaEdges of
        [] -> ["none"]
        _  -> [printf "%02d. %s" idx (formatBondLine m edge) | (idx, edge) <- zip [1 :: Int ..] sigmaEdges]

    stereoSection
      | null atomStereoList && null bondStereoList = ["none"]
      | otherwise = atomStereoSection ++ bondStereoSection

    atomStereoSection
      | null atomStereoList = []
      | otherwise = "atom-centered:" : indentBlock 2 (map formatAtomStereo atomStereoList)

    bondStereoSection
      | null bondStereoList = []
      | otherwise =
          (if null atomStereoList then [] else [""])
            ++ ["bond-directed:"]
            ++ indentBlock 2 (map (formatBondStereo m) bondStereoList)

-- | Pretty printer for an atom, including electron configuration.
prettyPrintAtom :: Atom -> String
prettyPrintAtom atom = renderLines (atomLines atom [])

prettyPrintShells :: Shells -> String
prettyPrintShells = renderLines . prettyShellLines

-- | Render Angstrom coordinates with explicit decimal values.
formatCoord :: Coordinate -> String
formatCoord (Coordinate x y z) =
  let showA :: Angstrom -> String
      showA = printf "% .4f" . unAngstrom
  in "(" ++ intercalate ", " [showA x, showA y, showA z] ++ ")"

-- ===== Pretty-print helpers =====

summarySection
  :: [(AtomId, Atom)]
  -> [Edge]
  -> [(SystemId, BondingSystem)]
  -> [SmilesAtomStereo]
  -> [SmilesBondStereo]
  -> [String]
summarySection atomList sigmaEdges systemList atomStereoList bondStereoList =
  [ summaryLine "atoms" (show (length atomList))
  , summaryLine "sigma bonds" (show (length sigmaEdges))
  , summaryLine "bonding systems" (show (length systemList))
  , summaryLine "net charge" (printf "%+d" (sum (map (formalCharge . snd) atomList)))
  , summaryLine "composition" (molecularFormula atomList)
  , summaryLine "stereo flags" stereoSummary
  ]
  where
    stereoParts =
      [ if null atomStereoList then Nothing else Just (show (length atomStereoList) ++ " atom")
      , if null bondStereoList then Nothing else Just (show (length bondStereoList) ++ " bond")
      ]
    stereoSummary =
      case catMaybes stereoParts of
        [] -> "none"
        xs -> intercalate ", " xs

summaryLine :: String -> String -> String
summaryLine label value = printf "%-16s %s" label value

sectionHeader :: String -> [String]
sectionHeader title = [title, replicate (length title) '-']

joinBlocks :: [[String]] -> [String]
joinBlocks [] = ["none"]
joinBlocks blocks = concat (zipWith addSpacer [0 :: Int ..] blocks)
  where
    addSpacer idx block
      | idx == 0 = block
      | otherwise = "" : block

molecularFormula :: [(AtomId, Atom)] -> String
molecularFormula atomList =
  case counts of
    [] -> "(empty)"
    _  -> unwords [ if n == 1 then sym else sym ++ show n | (sym, n) <- ordered ]
  where
    countsMap = foldr addSymbol M.empty atomList
    counts = M.toList countsMap
    ordered
      | M.member "C" countsMap =
          catMaybes
            [ fmap (\n -> ("C", n)) (M.lookup "C" countsMap)
            , fmap (\n -> ("H", n)) (M.lookup "H" countsMap)
            ]
            ++ [ (sym, n) | (sym, n) <- counts, sym /= "C", sym /= "H" ]
      | otherwise = counts

    addSymbol (_, atom) = M.insertWith (+) (show (symbol (attributes atom))) 1

renderLines :: [String] -> String
renderLines = intercalate "\n"

indentBlock :: Int -> [String] -> [String]
indentBlock n = map (replicate n ' ' ++)

formatAtomBlock :: Molecule -> (AtomId, Atom) -> [String]
formatAtomBlock m (aid, atom) = atomLines atom neighbourLine
  where
    atomsMap = atoms m
    neighbourIds = sort (neighborsSigma m aid)
    neighbourRefs = [ renderAtomRef (atomsMap M.! nid) | nid <- neighbourIds ]
    neighbourValue
      | null neighbourRefs = "none"
      | otherwise          = intercalate ", " neighbourRefs
    neighbourLine = [detailLine "sigma:" neighbourValue]

formatBondLine :: Molecule -> Edge -> String
formatBondLine m e =
  let atomsMap   = atoms m
      systemsList = systems m
      pair       = formatEdgeShort atomsMap e
      orderStr   = printf "order=%.2f" (effectiveOrder m e)
      systemRefs =
        [ formatSystemLabel sid bs
        | (sid, bs) <- sortOn fst systemsList
        , e `S.member` memberEdges bs
        ]
      systemSuffix =
        case systemRefs of
          [] -> ""
          _  -> "  systems=" ++ intercalate ", " systemRefs
  in pair ++ "  " ++ orderStr ++ systemSuffix

formatSystemBlock :: Molecule -> (SystemId, BondingSystem) -> [String]
formatSystemBlock m (sid, bs) = title : body
  where
    atomsMap = atoms m
    SystemId sidNum = sid
    electrons = getNN (sharedElectrons bs)
    title = maybe (printf "[#%d]" sidNum) (\lbl -> printf "[#%d] %s" sidNum lbl) (tag bs)

    atomRefs = [ renderAtomRef (atomsMap M.! aid)
               | aid <- S.toList (memberAtoms bs) ]
    atomsLine
      | null atomRefs = []
      | otherwise     = [printf "  member atoms:     %s" (intercalate ", " atomRefs)]

    edgesList = sort (S.toList (memberEdges bs))
    perEdgeContribution
      | null edgesList = Nothing
      | otherwise =
          let eCount = fromIntegral electrons :: Double
              eEdges = fromIntegral (length edgesList) :: Double
          in Just (eCount / (2 * eEdges))
    edgesSection =
      case edgesList of
        [] -> ["  member edges:     none"]
        _  ->
          let headerLine = case perEdgeContribution of
                              Nothing      -> "  member edges:"
                              Just contrib -> printf "  edge bonus:       +%.2f to each listed edge" contrib
              edgeLines  = "  member edges:" : indentBlock 4 (map (\edge -> "- " ++ formatEdgeShort atomsMap edge) edgesList)
          in headerLine : edgeLines

    body = atomsLine ++ edgesSection

atomLines :: Atom -> [String] -> [String]
atomLines atom extraDetail = header : indentBlock 2 detailLines
  where
    header = formatAtomHeader atom
    detailLines = baseDetails ++ extraDetail ++ shellSection

    baseDetails =
      [ detailLine "xyz:" (formatCoord (coordinate atom))
      , detailLine "charge:" (printf "%+d" (formalCharge atom))
      ]

    shellLines = prettyShellLines (shells atom)
    shellSection =
      case shellLines of
        [] -> []
        _  -> "shells:" : indentBlock 2 shellLines

detailLine :: String -> String -> String
detailLine label value = printf "%-8s %s" label value

formatAtomHeader :: Atom -> String
formatAtomHeader atom =
  let attr    = attributes atom
      symStr  = show (symbol attr)
      AtomId idx = atomID atom
      idxInt  = fromInteger idx :: Int
  in printf "[%s#%d] Z=%d  mass=%.4f u" symStr idxInt (atomicNumber attr) (atomicWeight attr)

renderAtomRef :: Atom -> String
renderAtomRef atom =
  let symStr = show (symbol (attributes atom))
      AtomId idx = atomID atom
  in symStr ++ "#" ++ show idx

formatEdgeShort :: Map AtomId Atom -> Edge -> String
formatEdgeShort atomMap (Edge i j) =
  renderAtomRef (atomMap M.! i) ++ " <-> " ++ renderAtomRef (atomMap M.! j)

formatSystemLabel :: SystemId -> BondingSystem -> String
formatSystemLabel sid bs =
  let SystemId sidNum = sid
      base = "#" ++ show sidNum
  in maybe base (\lbl -> base ++ "[" ++ lbl ++ "]") (tag bs)

formatAtomStereo :: SmilesAtomStereo -> String
formatAtomStereo stereo =
  let AtomId center = stereoCenter stereo
  in "center #" ++ show center ++ ": "
       ++ smilesAtomStereoClassCode (stereoClass stereo)
       ++ show (stereoConfiguration stereo)
       ++ " from token "
       ++ stereoToken stereo

formatBondStereo :: Molecule -> SmilesBondStereo -> String
formatBondStereo m stereo =
  let atomMap = atoms m
      left = renderAtomRef (atomMap M.! bondStereoStart stereo)
      right = renderAtomRef (atomMap M.! bondStereoEnd stereo)
  in left ++ " -> " ++ right ++ ": " ++ smilesBondStereoDirectionCode (bondStereoDirection stereo)

smilesAtomStereoClassCode :: SmilesAtomStereoClass -> String
smilesAtomStereoClassCode StereoTetrahedral = "TH"
smilesAtomStereoClassCode StereoAllene = "AL"
smilesAtomStereoClassCode StereoSquarePlanar = "SP"
smilesAtomStereoClassCode StereoTrigonalBipyramidal = "TB"
smilesAtomStereoClassCode StereoOctahedral = "OH"

smilesBondStereoDirectionCode :: SmilesBondStereoDirection -> String
smilesBondStereoDirectionCode BondUp = "/"
smilesBondStereoDirectionCode BondDown = "\\"

prettyShellLines :: Shells -> [String]
prettyShellLines = concatMap formatShell
  where
    formatShell sh =
      let n = Orb.principalQuantumNumber sh
          subs = catMaybes
            [ formatSubShell 's' (Orb.sSubShell sh)
            , formatSubShell 'p' (Orb.pSubShell sh)
            , formatSubShell 'd' (Orb.dSubShell sh)
            , formatSubShell 'f' (Orb.fSubShell sh) ]
          summaryBits = map fst subs
          body = concatMap snd subs
      in case body of
           [] -> [printf "n=%d (empty)" n]
           _  -> printf "n=%d :: %s" n (intercalate " | " summaryBits) : indentBlock 2 body

    formatSubShell :: Show subshellType
                   => Char
                   -> Maybe (Orb.SubShell subshellType)
                   -> Maybe (String, [String])
    formatSubShell _ Nothing = Nothing
    formatSubShell label (Just (Orb.SubShell orbitals)) =
      let totalElectrons = sum [ Orb.electronCount o | o <- orbitals ]
          header = printf "%c %de" label totalElectrons
          orbitalLines = map (\orbital -> "- " ++ formatOrbital orbital) orbitals
      in Just (header, orbitalLines)

    formatOrbital :: Show subshellType => Orb.Orbital subshellType -> String
    formatOrbital o =
      let base = printf "%s (%d e)" (map toLower (show (Orb.orbitalType o))) (Orb.electronCount o)
          orientationPart =
            maybe "" (\coord -> " @ " ++ formatOrientation coord) (Orb.orientation o)
          hybridPart =
            maybe "" (\hyb -> " hybrid " ++ formatHybrid hyb) (Orb.hybridComponents o)
      in base ++ orientationPart ++ hybridPart

formatOrientation :: Coordinate -> String
formatOrientation (Coordinate x y z) =
  let showA = printf "% .3f" . unAngstrom
  in "<" ++ intercalate ", " [showA x, showA y, showA z] ++ ">"

formatHybrid :: [(Double, Orb.PureOrbital)] -> String
formatHybrid = intercalate " + " . map formatComponent
  where
    formatComponent (coeff, pureOrb) =
      printf "%.2f×%s" coeff (formatPureOrbital pureOrb)

formatPureOrbital :: Orb.PureOrbital -> String
formatPureOrbital (Orb.PureSo _) = "s"
formatPureOrbital (Orb.PureP  p) = map toLower (show p)
formatPureOrbital (Orb.PureD  d) = map toLower (show d)
formatPureOrbital (Orb.PureF  f) = map toLower (show f)

instance Binary AtomicSymbol
instance Binary ElementAttributes
instance Binary Atom
instance Binary SmilesAtomStereoClass
instance Binary SmilesBondStereoDirection
instance Binary SmilesAtomStereo
instance Binary SmilesBondStereo
instance Binary SmilesStereochemistry
instance Binary Molecule
