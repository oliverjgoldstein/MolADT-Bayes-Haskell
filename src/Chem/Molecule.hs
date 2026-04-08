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
  intercalate "\n\n" (header : [atomsSection, bondsSection, systemsSection, stereoSection])
  where
    atomList   = M.toAscList (atoms m)
    sigmaEdges = sort (S.toList (localBonds m))
    systemList = sortOn fst (systems m)
    atomStereoList = sortOn stereoCenter (atomStereoAnnotations (smilesStereochemistry m))
    bondStereoList = sortOn (\item -> (bondStereoStart item, bondStereoEnd item, bondStereoDirection item)) (bondStereoAnnotations (smilesStereochemistry m))

    header =
      "Molecule with " ++ intercalate ", "
        [ countLabel (length atomList) "atom" "atoms"
        , countLabel (length sigmaEdges) "σ bond" "σ bonds"
        , countLabel (length systemList) "bonding system" "bonding systems" ]

    atomsSection =
      case atomList of
        [] -> "Atoms: (none)"
        _  -> "Atoms (" ++ show (length atomList) ++ "):\n"
              ++ intercalate "\n\n"
                   [ renderLines (indentBlock 2 (formatAtomBlock m entry))
                   | entry <- atomList ]

    bondsSection =
      case sigmaEdges of
        [] -> "σ bonds: (none)"
        _  -> "σ bonds (" ++ show (length sigmaEdges) ++ "):\n"
              ++ renderLines (indentBlock 2 (map (formatBondLine m) sigmaEdges))

    systemsSection =
      case systemList of
        [] -> "Bonding systems: (none)"
        _  -> "Bonding systems (" ++ show (length systemList) ++ "):\n"
              ++ intercalate "\n\n"
                   [ renderLines (indentBlock 2 (formatSystemBlock m entry))
                   | entry <- systemList ]

    stereoSection
      | null atomStereoList && null bondStereoList = "SMILES stereochemistry: (none)"
      | otherwise =
          "SMILES stereochemistry:\n"
            ++ renderLines (indentBlock 2 (atomStereoSection ++ bondStereoSection))

    atomStereoSection
      | null atomStereoList = []
      | otherwise = "Atom-centered:" : indentBlock 2 (map formatAtomStereo atomStereoList)

    bondStereoSection
      | null bondStereoList = []
      | otherwise =
          (if null atomStereoList then [] else [""])
            ++ ["Bond-directed:"]
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

countLabel :: Int -> String -> String -> String
countLabel n singular plural =
  show n ++ " " ++ if n == 1 then singular else plural

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
    neighbourLine = [detailLine "σ neighbours:" neighbourValue]

formatBondLine :: Molecule -> Edge -> String
formatBondLine m e =
  let atomsMap   = atoms m
      systemsList = systems m
      pair       = formatEdgeShort atomsMap e
      orderStr   = printf "%.2f" (effectiveOrder m e)
      systemRefs =
        [ formatSystemLabel sid bs
        | (sid, bs) <- sortOn fst systemsList
        , e `S.member` memberEdges bs
        ]
      systemSuffix =
        case systemRefs of
          [] -> ""
          _  -> "; systems: " ++ intercalate ", " systemRefs
  in pair ++ " (order " ++ orderStr ++ systemSuffix ++ ")"

formatSystemBlock :: Molecule -> (SystemId, BondingSystem) -> [String]
formatSystemBlock m (sid, bs) = header : indentBlock 2 body
  where
    atomsMap = atoms m
    SystemId sidNum = sid
    electrons = getNN (sharedElectrons bs)
    labelSuffix = maybe "" (\lbl -> " [" ++ lbl ++ "]") (tag bs)
    header = printf "System %d%s: %d shared electrons" sidNum labelSuffix electrons

    atomRefs = [ renderAtomRef (atomsMap M.! aid)
               | aid <- S.toList (memberAtoms bs) ]
    atomsLine
      | null atomRefs = []
      | otherwise     = ["Atoms: " ++ intercalate ", " atomRefs]

    edgesList = sort (S.toList (memberEdges bs))
    perEdgeContribution
      | null edgesList = Nothing
      | otherwise =
          let eCount = fromIntegral electrons :: Double
              eEdges = fromIntegral (length edgesList) :: Double
          in Just (eCount / (2 * eEdges))
    edgesSection =
      case edgesList of
        [] -> []
        _  ->
          let headerLine = case perEdgeContribution of
                              Nothing      -> "Edges:"
                              Just contrib -> printf "Edges (+%.2f to bond order each):" contrib
              edgeLines  = indentBlock 2 (map (formatEdgeShort atomsMap) edgesList)
          in headerLine : edgeLines

    body = atomsLine ++ edgesSection

atomLines :: Atom -> [String] -> [String]
atomLines atom extraDetail = header : indentBlock 2 detailLines
  where
    header = formatAtomHeader atom
    detailLines = baseDetails ++ extraDetail ++ shellSection

    baseDetails =
      [ detailLine "Coordinates (Å):" (formatCoord (coordinate atom))
      , detailLine "Formal charge:" (printf "%+d" (formalCharge atom))
      ]

    shellLines = prettyShellLines (shells atom)
    shellSection =
      case shellLines of
        [] -> []
        _  -> "Electron shells:" : indentBlock 2 shellLines

detailLine :: String -> String -> String
detailLine label value = printf "%-18s %s" label value

formatAtomHeader :: Atom -> String
formatAtomHeader atom =
  let attr    = attributes atom
      symStr  = show (symbol attr)
      AtomId idx = atomID atom
      idxInt  = fromInteger idx :: Int
  in printf "%s #%d (Z=%d, %.4f u)" symStr idxInt (atomicNumber attr) (atomicWeight attr)

renderAtomRef :: Atom -> String
renderAtomRef atom =
  let symStr = show (symbol (attributes atom))
      AtomId idx = atomID atom
  in symStr ++ "#" ++ show idx

formatEdgeShort :: Map AtomId Atom -> Edge -> String
formatEdgeShort atomMap (Edge i j) =
  renderAtomRef (atomMap M.! i) ++ " ↔ " ++ renderAtomRef (atomMap M.! j)

formatSystemLabel :: SystemId -> BondingSystem -> String
formatSystemLabel sid bs =
  let SystemId sidNum = sid
      base = "#" ++ show sidNum
  in maybe base (\lbl -> base ++ " [" ++ lbl ++ "]") (tag bs)

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
          body = concat subs
      in case body of
           [] -> [printf "n=%d (empty)" n]
           _  -> printf "n=%d" n : indentBlock 2 body

    formatSubShell :: Show subshellType
                   => Char
                   -> Maybe (Orb.SubShell subshellType)
                   -> Maybe [String]
    formatSubShell _ Nothing = Nothing
    formatSubShell label (Just (Orb.SubShell orbitals)) =
      let totalElectrons = sum [ Orb.electronCount o | o <- orbitals ]
          header = printf "%c: %d e" label totalElectrons
          orbitalLines = indentBlock 2 (map formatOrbital orbitals)
      in Just (header : orbitalLines)

    formatOrbital :: Show subshellType => Orb.Orbital subshellType -> String
    formatOrbital o =
      let base = printf "%s (%d e)" (show (Orb.orbitalType o)) (Orb.electronCount o)
          orientationPart =
            maybe "" (\coord -> ", orientation " ++ formatOrientation coord) (Orb.orientation o)
          hybridPart =
            maybe "" (\hyb -> ", hybrid " ++ formatHybrid hyb) (Orb.hybridComponents o)
      in base ++ orientationPart ++ hybridPart

formatOrientation :: Coordinate -> String
formatOrientation (Coordinate x y z) =
  let showA = printf "% .3f" . unAngstrom
  in "⟨" ++ intercalate ", " [showA x, showA y, showA z] ++ "⟩"

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
