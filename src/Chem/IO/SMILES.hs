{-# LANGUAGE BangPatterns #-}

module Chem.IO.SMILES
  ( parseSMILES
  , moleculeToSMILES
  ) where

import           Control.Monad (foldM, replicateM_)
import           Control.Monad.Except (Except, MonadError (throwError), runExcept)
import           Control.Monad.State.Strict (StateT, execStateT, get, gets, modify')
import qualified Data.Char as Char
import qualified Data.List as L
import qualified Data.Map.Strict as M
import qualified Data.Set as S

import           Chem.Dietz
import           Chem.Molecule
import           Chem.Molecule.Coordinate (Coordinate(..), mkAngstrom, unAngstrom)
import           Constants (elementAttributes)

data BondKind = BondSingle | BondDouble | BondTriple | BondAromatic
  deriving (Eq, Show)

data BondSpec = BondSpec
  { bondSpecKind      :: Maybe BondKind
  , bondSpecDirection :: Maybe SmilesBondStereoDirection
  } deriving (Eq, Show)

data AtomRef = AtomRef
  { refAtomId   :: AtomId
  , refAromatic :: Bool
  } deriving (Eq, Show)

data BracketAtom = BracketAtom
  { bracketSymbol        :: AtomicSymbol
  , bracketAromatic      :: Bool
  , bracketStereoClass   :: Maybe SmilesAtomStereoClass
  , bracketStereoConfig  :: Maybe Int
  , bracketStereoToken   :: Maybe String
  , bracketHydrogenCount :: Int
  , bracketCharge        :: Int
  } deriving (Eq, Show)

data RingOpen = RingOpen
  { ringAtom     :: AtomRef
  , ringBondSpec :: Maybe BondSpec
  } deriving (Eq, Show)

data ParseState = ParseState
  { psRemaining      :: !String
  , psIndex          :: !Int
  , psNextAtomIndex  :: !Integer
  , psAtoms          :: !(M.Map AtomId Atom)
  , psLocalBonds     :: !(S.Set Edge)
  , psSystems        :: ![BondingSystem]
  , psAtomStereo     :: ![SmilesAtomStereo]
  , psBondStereo     :: ![SmilesBondStereo]
  , psAromaticEdges  :: !(S.Set Edge)
  , psAromaticAtoms  :: !(S.Set AtomId)
  , psImplicitHydrogenHosts :: !(S.Set AtomId)
  , psBranchStack    :: ![AtomRef]
  , psRingOpens      :: !(M.Map Char RingOpen)
  }

type ParserM = StateT ParseState (Except String)

parseSMILES :: String -> Either String Molecule
parseSMILES rawText = do
  let text = trim rawText
      initialState = ParseState
        { psRemaining = text
        , psIndex = 0
        , psNextAtomIndex = 1
        , psAtoms = M.empty
        , psLocalBonds = S.empty
        , psSystems = []
        , psAtomStereo = []
        , psBondStereo = []
        , psAromaticEdges = S.empty
        , psAromaticAtoms = S.empty
        , psImplicitHydrogenHosts = S.empty
        , psBranchStack = []
        , psRingOpens = M.empty
        }
  if null text
    then Left "SMILES string is empty"
    else do
      st <- runExcept $ execStateT (parseLoop Nothing Nothing) initialState
      if not (null (psBranchStack st))
        then Left "Unclosed branch in SMILES"
        else
          if not (M.null (psRingOpens st))
            then Left "Unclosed ring digit in SMILES"
            else
              let normalizedSystems =
                    normalizeSMILESSystems
                      (psLocalBonds st)
                      (reverse (psSystems st))
                      (psAromaticEdges st)
                      (psAromaticAtoms st)
                  (enrichedAtoms, enrichedBonds) =
                    inferImplicitHydrogens
                      (psAtoms st)
                      (psLocalBonds st)
                      normalizedSystems
                      (psImplicitHydrogenHosts st)
                  assignedSystems = zipWith (\idx sys -> (SystemId idx, sys)) [1 ..] normalizedSystems
              in Right $
                   withLocalBondsAsSystems
                     (Molecule
                        { atoms = enrichedAtoms
                        , localBonds = enrichedBonds
                        , systems = assignedSystems
                        , smilesStereochemistry = SmilesStereochemistry
                            { atomStereoAnnotations = reverse (psAtomStereo st)
                            , bondStereoAnnotations = reverse (psBondStereo st)
                            }
                        })

parseLoop :: Maybe AtomRef -> Maybe BondSpec -> ParserM ()
parseLoop current pendingBond = do
  mChar <- currentChar
  case mChar of
    Nothing ->
      case pendingBond of
        Nothing -> pure ()
        Just _  -> throwError "SMILES ended after a bond symbol"
    Just '(' ->
      case current of
        Nothing -> throwError "Branch opened before any atom"
        Just atomRef -> do
          modify' $ \st -> st { psBranchStack = atomRef : psBranchStack st }
          advanceIndex 1
          parseLoop current pendingBond
    Just ')' -> do
      branchStack <- gets psBranchStack
      case branchStack of
        [] -> throwError "Unmatched ')'"
        (atomRef:rest) -> do
          modify' $ \st -> st { psBranchStack = rest }
          advanceIndex 1
          parseLoop (Just atomRef) pendingBond
    Just '.' -> do
      advanceIndex 1
      parseLoop Nothing Nothing
    Just char
      | Just bondKind <- bondKindFromChar char -> do
          advanceIndex 1
          updated <- liftEither (extendBondSpec pendingBond (Just bondKind) Nothing)
          parseLoop current (Just updated)
      | Just bondDirection <- bondDirectionFromChar char -> do
          advanceIndex 1
          updated <- liftEither (extendBondSpec pendingBond Nothing (Just bondDirection))
          parseLoop current (Just updated)
      | Char.isDigit char ->
          case current of
            Nothing -> throwError "Ring digit encountered before any atom"
            Just atomRef -> do
              handleRingDigit char atomRef pendingBond
              advanceIndex 1
              parseLoop current Nothing
      | otherwise -> do
          atomRef <- parseAtom
          case current of
            Nothing -> pure ()
            Just left -> connectAtoms left atomRef pendingBond
          parseLoop (Just atomRef) Nothing

parseAtom :: ParserM AtomRef
parseAtom = do
  mChar <- currentChar
  case mChar of
    Just '[' -> parseBracketAtom
    Just _   -> parseBareAtom
    Nothing  -> throwError "Expected atom, reached end of input"

parseBracketAtom :: ParserM AtomRef
parseBracketAtom = do
  st <- get
  let rest = case psRemaining st of
        [] -> []
        (_:suffix) -> suffix
      (content, suffix) = break (== ']') rest
  case suffix of
    [] -> throwError "Unclosed bracket atom"
    (_:_) -> do
      if null content
        then throwError "Empty bracket atom"
        else do
          bracketAtom <- liftEither (parseBracketContent content)
          advanceIndex (length content + 2)
          atom <- newAtom (bracketSymbol bracketAtom) (bracketCharge bracketAtom)
          if bracketAromatic bracketAtom
            then modify' $ \state -> state { psAromaticAtoms = S.insert (atomID atom) (psAromaticAtoms state) }
            else pure ()
          case (bracketStereoClass bracketAtom, bracketStereoConfig bracketAtom, bracketStereoToken bracketAtom) of
            (Just stereoClass, Just stereoConfig, Just stereoTokenText) ->
              modify' $ \state -> state
                { psAtomStereo =
                    SmilesAtomStereo
                      { stereoCenter = atomID atom
                      , stereoClass = stereoClass
                      , stereoConfiguration = stereoConfig
                      , stereoToken = stereoTokenText
                      } : psAtomStereo state
                }
            _ -> pure ()
          let atomRef = AtomRef (atomID atom) (bracketAromatic bracketAtom)
          replicateM_ (bracketHydrogenCount bracketAtom) $ do
            hydrogen <- newAtom H 0
            addBond (atomID atom) (atomID hydrogen) BondSingle
          pure atomRef

parseBareAtom :: ParserM AtomRef
parseBareAtom = do
  st <- get
  let rest = psRemaining st
  case rest of
    c1:c2:_ ->
      case atomicSymbolFromToken [c1, c2] of
        Just symbol -> do
          advanceIndex 2
          atom <- newAtom symbol 0
          if supportsImplicitHydrogens symbol
            then modify' $ \state -> state { psImplicitHydrogenHosts = S.insert (atomID atom) (psImplicitHydrogenHosts state) }
            else pure ()
          pure (AtomRef (atomID atom) False)
        Nothing ->
          case aromaticSymbolFromChar c1 of
            Just symbol -> do
              advanceIndex 1
              atom <- newAtom symbol 0
              modify' $ \state -> state
                { psAromaticAtoms = S.insert (atomID atom) (psAromaticAtoms state)
                , psImplicitHydrogenHosts = S.insert (atomID atom) (psImplicitHydrogenHosts state)
                }
              pure (AtomRef (atomID atom) True)
            Nothing ->
              case atomicSymbolFromToken [c1] of
                Just symbol -> do
                  advanceIndex 1
                  atom <- newAtom symbol 0
                  if supportsImplicitHydrogens symbol
                    then modify' $ \state -> state { psImplicitHydrogenHosts = S.insert (atomID atom) (psImplicitHydrogenHosts state) }
                    else pure ()
                  pure (AtomRef (atomID atom) False)
                Nothing -> throwError ("Unsupported SMILES atom token at index " ++ show (psIndex st))
    [c1] ->
      case aromaticSymbolFromChar c1 of
        Just symbol -> do
          advanceIndex 1
          atom <- newAtom symbol 0
          modify' $ \state -> state
            { psAromaticAtoms = S.insert (atomID atom) (psAromaticAtoms state)
            , psImplicitHydrogenHosts = S.insert (atomID atom) (psImplicitHydrogenHosts state)
            }
          pure (AtomRef (atomID atom) True)
        Nothing ->
          case atomicSymbolFromToken [c1] of
            Just symbol -> do
              advanceIndex 1
              atom <- newAtom symbol 0
              if supportsImplicitHydrogens symbol
                then modify' $ \state -> state { psImplicitHydrogenHosts = S.insert (atomID atom) (psImplicitHydrogenHosts state) }
                else pure ()
              pure (AtomRef (atomID atom) False)
            Nothing -> throwError ("Unsupported SMILES atom token at index " ++ show (psIndex st))
    [] -> throwError "Expected atom, reached end of input"

newAtom :: AtomicSymbol -> Int -> ParserM Atom
newAtom symbol charge = do
  st <- get
  let atomIdx = psNextAtomIndex st
      aid = AtomId atomIdx
      coord = Coordinate (mkAngstrom (fromIntegral atomIdx - 1.0)) (mkAngstrom 0.0) (mkAngstrom 0.0)
      attrs = elementAttributes symbol
      atom = Atom
        { atomID = aid
        , attributes = attrs
        , coordinate = coord
        , shells = defaultShells attrs
        , formalCharge = charge
        }
  modify' $ \s ->
    s
      { psNextAtomIndex = atomIdx + 1
      , psAtoms = M.insert aid atom (psAtoms s)
      }
  pure atom

handleRingDigit :: Char -> AtomRef -> Maybe BondSpec -> ParserM ()
handleRingDigit digit current pendingBond = do
  ringOpens <- gets psRingOpens
  case M.lookup digit ringOpens of
    Nothing ->
      modify' $ \st -> st { psRingOpens = M.insert digit (RingOpen current pendingBond) (psRingOpens st) }
    Just ringOpen -> do
      bondKind <- liftEither (resolveBondKind (bondSpecKind =<< ringBondSpec ringOpen) (bondSpecKind =<< pendingBond) (refAromatic (ringAtom ringOpen)) (refAromatic current))
      addBond (refAtomId (ringAtom ringOpen)) (refAtomId current) bondKind
      case bondSpecDirection =<< ringBondSpec ringOpen of
        Just direction ->
          modify' $ \st -> st
            { psBondStereo =
                SmilesBondStereo
                  { bondStereoStart = refAtomId (ringAtom ringOpen)
                  , bondStereoEnd = refAtomId current
                  , bondStereoDirection = direction
                  } : psBondStereo st
            }
        Nothing -> pure ()
      case bondSpecDirection =<< pendingBond of
        Just direction ->
          modify' $ \st -> st
            { psBondStereo =
                SmilesBondStereo
                  { bondStereoStart = refAtomId current
                  , bondStereoEnd = refAtomId (ringAtom ringOpen)
                  , bondStereoDirection = direction
                  } : psBondStereo st
            }
        Nothing -> pure ()
      modify' $ \st -> st { psRingOpens = M.delete digit (psRingOpens st) }

connectAtoms :: AtomRef -> AtomRef -> Maybe BondSpec -> ParserM ()
connectAtoms left right pendingBond =
  do
    addBond (refAtomId left) (refAtomId right) bondKind
    case bondSpecDirection =<< pendingBond of
      Just direction ->
        modify' $ \st -> st
          { psBondStereo =
              SmilesBondStereo
                { bondStereoStart = refAtomId left
                , bondStereoEnd = refAtomId right
                , bondStereoDirection = direction
                } : psBondStereo st
          }
      Nothing -> pure ()
  where
    bondKind = case bondSpecKind =<< pendingBond of
      Just explicit -> explicit
      Nothing       -> defaultBondKind left right

addBond :: AtomId -> AtomId -> BondKind -> ParserM ()
addBond left right bondKind = do
  let edge = mkEdge left right
  modify' $ \st -> st { psLocalBonds = S.insert edge (psLocalBonds st) }
  case bondKind of
    BondSingle ->
      modify' $ \st -> st
        { psSystems = mkBondingSystem (NonNegative 2) (S.singleton edge) (Just "single") : psSystems st }
    BondDouble ->
      modify' $ \st -> st
        { psSystems = mkBondingSystem (NonNegative 4) (S.singleton edge) (Just "double") : psSystems st }
    BondTriple ->
      modify' $ \st -> st
        { psSystems = mkBondingSystem (NonNegative 6) (S.singleton edge) (Just "triple") : psSystems st }
    BondAromatic ->
      modify' $ \st -> st
        { psSystems = mkBondingSystem (NonNegative 2) (S.singleton edge) (Just "single") : psSystems st
        , psAromaticEdges = S.insert edge (psAromaticEdges st)
        }

currentChar :: ParserM (Maybe Char)
currentChar = do
  st <- get
  pure $
    case psRemaining st of
      [] -> Nothing
      (char:_) -> Just char

advanceIndex :: Int -> ParserM ()
advanceIndex n =
  modify' $ \st ->
    st
      { psRemaining = drop n (psRemaining st)
      , psIndex = psIndex st + n
      }

parseBracketContent :: String -> Either String BracketAtom
parseBracketContent content = do
  (symbol, aromatic, rest1) <- parseBracketSymbol content
  (stereoInfo, rest2) <- parseBracketStereo rest1
  let (hydrogenCount, rest3) = parseBracketHydrogenCount rest2
  (charge, rest4) <- parseBracketCharge rest3
  if null rest4
    then Right BracketAtom
      { bracketSymbol = symbol
      , bracketAromatic = aromatic
      , bracketStereoClass = (\(cls, _, _) -> cls) <$> stereoInfo
      , bracketStereoConfig = (\(_, cfg, _) -> cfg) <$> stereoInfo
      , bracketStereoToken = (\(_, _, tok) -> tok) <$> stereoInfo
      , bracketHydrogenCount = hydrogenCount
      , bracketCharge = charge
      }
    else Left ("Unsupported bracket atom feature: [" ++ content ++ "]")

parseBracketSymbol :: String -> Either String (AtomicSymbol, Bool, String)
parseBracketSymbol content =
  case content of
    c1:c2:rest
      | Just symbol <- atomicSymbolFromToken [c1, c2] -> Right (symbol, False, rest)
    c1:rest
      | Just symbol <- aromaticSymbolFromChar c1      -> Right (symbol, True, rest)
      | Just symbol <- atomicSymbolFromToken [c1]     -> Right (symbol, False, rest)
    _ -> Left ("Unsupported bracket atom: [" ++ content ++ "]")

parseBracketHydrogenCount :: String -> (Int, String)
parseBracketHydrogenCount ('H':rest) =
  let (digits, suffix) = span Char.isDigit rest
      count = if null digits then 1 else read digits
  in (count, suffix)
parseBracketHydrogenCount rest = (0, rest)

parseBracketCharge :: String -> Either String (Int, String)
parseBracketCharge [] = Right (0, [])
parseBracketCharge input@(sign:rest)
  | sign `elem` "+-" =
      let signValue = if sign == '+' then 1 else -1
          (digits, suffix) = span Char.isDigit rest
      in if not (null digits)
           then Right (signValue * read digits, suffix)
           else
             let (sameSigns, remainder) = span (== sign) rest
                 magnitude = 1 + length sameSigns
             in if any (`elem` "+-") remainder
                  then Left ("Mixed charge syntax in bracket atom: [" ++ input ++ "]")
                  else Right (signValue * magnitude, remainder)
  | otherwise = Right (0, input)

parseBracketStereo :: String -> Either String (Maybe (SmilesAtomStereoClass, Int, String), String)
parseBracketStereo [] = Right (Nothing, [])
parseBracketStereo input@('@':'@':rest) = Right (Just (StereoTetrahedral, 2, "@@"), rest)
parseBracketStereo input@('@':rest) =
  case rest of
    [] -> Right (Just (StereoTetrahedral, 1, "@"), [])
    next:_ | next `elem` "H+-" -> Right (Just (StereoTetrahedral, 1, "@"), rest)
    _ ->
      let (cls, suffix) =
            case rest of
              'T':'H':xs -> (StereoTetrahedral, xs)
              'A':'L':xs -> (StereoAllene, xs)
              'S':'P':xs -> (StereoSquarePlanar, xs)
              'T':'B':xs -> (StereoTrigonalBipyramidal, xs)
              'O':'H':xs -> (StereoOctahedral, xs)
              _          -> (StereoTetrahedral, rest)
          (digits, suffix') = span Char.isDigit suffix
          config = if null digits then 1 else read digits
          consumed = length input - length suffix'
      in Right (Just (cls, config, take consumed input), suffix')
parseBracketStereo input = Right (Nothing, input)

defaultBondKind :: AtomRef -> AtomRef -> BondKind
defaultBondKind left right
  | refAromatic left && refAromatic right = BondAromatic
  | otherwise = BondSingle

resolveBondKind :: Maybe BondKind -> Maybe BondKind -> Bool -> Bool -> Either String BondKind
resolveBondKind left right leftAromatic rightAromatic =
  case (left, right) of
    (Just lhs, Just rhs)
      | lhs /= rhs -> Left "Conflicting bond specifications around ring closure"
      | otherwise  -> Right lhs
    (Just lhs, Nothing) -> Right lhs
    (Nothing, Just rhs) -> Right rhs
    (Nothing, Nothing)
      | leftAromatic && rightAromatic -> Right BondAromatic
      | otherwise                     -> Right BondSingle

extendBondSpec :: Maybe BondSpec -> Maybe BondKind -> Maybe SmilesBondStereoDirection -> Either String BondSpec
extendBondSpec current maybeKind maybeDirection =
  let spec = maybe (BondSpec Nothing Nothing) id current
  in case (maybeKind, maybeDirection) of
       (Just kind, _) ->
         case bondSpecKind spec of
           Just _  -> Left "Multiple bond symbols in sequence"
           Nothing -> Right (spec { bondSpecKind = Just kind })
       (_, Just direction) ->
         case bondSpecDirection spec of
           Just _  -> Left "Multiple directional bond symbols in sequence"
           Nothing -> Right (spec { bondSpecDirection = Just direction })
       _ -> Right spec

normalizeSMILESSystems :: S.Set Edge -> [BondingSystem] -> S.Set Edge -> S.Set AtomId -> [BondingSystem]
normalizeSMILESSystems localBonds' systems' aromaticCandidateEdges aromaticAtoms =
  retainedSystems ++ aromaticSystems
  where
    aromaticRings = S.fromList (detectAromaticSixRings aromaticCandidateEdges)
    lowercaseAromaticRings = S.fromList (detectLowercaseAromaticSixRings localBonds' aromaticCandidateEdges aromaticAtoms)
    piRings = S.unions [aromaticRings, lowercaseAromaticRings]
    ringEdges = S.unions (S.toList piRings)

    retainedSystems = systems'
    aromaticSystems =
      [ mkBondingSystem (NonNegative 6) ring (Just "pi_ring")
      | ring <- S.toAscList piRings
      ]

detectAromaticSixRings :: S.Set Edge -> [S.Set Edge]
detectAromaticSixRings edges =
  S.toAscList discovered
  where
    adjacency = adjacencyFromEdges edges
    discovered = S.fromList (concatMap (search . (:[])) (M.keys adjacency))

    search :: [AtomId] -> [S.Set Edge]
    search path =
      let current = last path
      in if length path == 6
           then
             [ ringEdges
             | neighbor <- M.findWithDefault [] current adjacency
             , neighbor == head path
             , let atoms = path ++ [head path]
             , let ringEdges = S.fromList (zipWith mkEdge atoms (tail atoms))
             , head path == minimum path
             ]
           else
             concat
               [ search (path ++ [neighbor])
               | neighbor <- M.findWithDefault [] current adjacency
               , neighbor `notElem` path
               ]

detectLowercaseAromaticSixRings :: S.Set Edge -> S.Set Edge -> S.Set AtomId -> [S.Set Edge]
detectLowercaseAromaticSixRings localBonds' aromaticCandidateEdges aromaticAtoms =
  S.toAscList discovered
  where
    adjacency = adjacencyFromEdges localBonds'
    discovered = S.fromList (concatMap (search . (:[])) (M.keys adjacency))

    search :: [AtomId] -> [S.Set Edge]
    search path =
      let current = last path
      in if length path == 6
           then
             [ ringEdges
             | neighbor <- M.findWithDefault [] current adjacency
             , neighbor == head path
             , let atoms = path ++ [head path]
             , let ringEdges = S.fromList (zipWith mkEdge atoms (tail atoms))
             , let aromaticCount = length [ atom | atom <- path, atom `S.member` aromaticAtoms ]
             , let aromaticEdgeCount = length [ edge | edge <- S.toList ringEdges, edge `S.member` aromaticCandidateEdges ]
             , aromaticCount >= 5
             , aromaticEdgeCount >= 4
             , head path == minimum path
             ]
           else
             concat
               [ search (path ++ [neighbor])
               | neighbor <- M.findWithDefault [] current adjacency
               , neighbor `notElem` path
               ]

adjacencyFromEdges :: S.Set Edge -> M.Map AtomId [AtomId]
adjacencyFromEdges edges =
  M.map L.sort $
    M.unionWith (++) forward backward
  where
    forward = M.fromListWith (++) [ (a, [b]) | Edge a b <- S.toAscList edges ]
    backward = M.fromListWith (++) [ (b, [a]) | Edge a b <- S.toAscList edges ]

inferImplicitHydrogens :: M.Map AtomId Atom -> S.Set Edge -> [BondingSystem] -> S.Set AtomId -> (M.Map AtomId Atom, S.Set Edge)
inferImplicitHydrogens atomMap sigmaEdges systems' hosts =
  (enrichedAtoms, enrichedBonds)
  where
    systemContributions =
      M.fromListWith (+)
        [ (aid, contribution)
        | system <- systems'
        , let edgeCount = S.size (memberEdges system)
        , edgeCount > 0
        , let contribution = fromIntegral (getNN (sharedElectrons system)) / (2.0 * fromIntegral edgeCount)
        , Edge a b <- S.toAscList (memberEdges system)
        , aid <- [a, b]
        ]

    hostCounts = zip (S.toAscList hosts) [0 :: Int ..]

    hydrogenSpecs =
      concat
        [ [ (host, offset)
          | offset <- [0 .. missing - 1]
          ]
        | (host, _) <- hostCounts
        , Just atom <- [M.lookup host atomMap]
        , symbol (attributes atom) /= H
        , formalCharge atom == 0
        , let currentUsed = M.findWithDefault 0.0 host systemContributions
        , let missing = implicitHydrogenCount (implicitHydrogenValence (symbol (attributes atom)) - currentUsed)
        , missing > 0
        ]

    startIndex = maybe 1 ((+ 1) . atomIdValue) (safeMaximum (M.keys atomMap))
    hydrogenIds = map (AtomId . (+ startIndex) . fromIntegral) [0 .. length hydrogenSpecs - 1]

    enrichedAtoms =
      foldl
        (\acc (hydrogenId, (host, offset)) ->
          case M.lookup host atomMap of
            Nothing -> acc
            Just hostAtom ->
              M.insert hydrogenId (inferredHydrogenAtom hydrogenId hostAtom offset) acc
        )
        atomMap
        (zip hydrogenIds hydrogenSpecs)

    enrichedBonds =
      foldl
        (\acc (hydrogenId, (host, _)) -> S.insert (mkEdge host hydrogenId) acc)
        sigmaEdges
        (zip hydrogenIds hydrogenSpecs)

implicitHydrogenCount :: Double -> Int
implicitHydrogenCount missingValence
  | missingValence <= 1e-9 = 0
  | rounded <= 0 = 0
  | abs (missingValence - fromIntegral rounded) > 1e-6 = 0
  | otherwise = rounded
  where
    rounded = round missingValence

implicitHydrogenValence :: AtomicSymbol -> Double
implicitHydrogenValence symbol =
  case symbol of
    B  -> 3.0
    Br -> 1.0
    C  -> 4.0
    Cl -> 1.0
    F  -> 1.0
    I  -> 1.0
    N  -> 3.0
    O  -> 2.0
    P  -> 3.0
    S  -> 2.0
    Si -> 4.0
    _  -> 0.0

isConventionalSingleEdgeSystem :: BondingSystem -> Bool
isConventionalSingleEdgeSystem system =
  S.size (memberEdges system) == 1
    && getNN (sharedElectrons system) `elem` [2, 4, 6]

inferredHydrogenAtom :: AtomId -> Atom -> Int -> Atom
inferredHydrogenAtom hydrogenId hostAtom offset =
  let attrs = elementAttributes H
  in
  Atom
    { atomID = hydrogenId
    , attributes = attrs
    , coordinate = inferredHydrogenCoordinate (coordinate hostAtom) offset
    , shells = defaultShells attrs
    , formalCharge = 0
    }

inferredHydrogenCoordinate :: Coordinate -> Int -> Coordinate
inferredHydrogenCoordinate (Coordinate x y z) offset =
  Coordinate
    (mkAngstrom (unAngstrom x))
    (mkAngstrom (unAngstrom y))
    (mkAngstrom (unAngstrom z + 0.12 * fromIntegral (offset + 1)))

safeMaximum :: Ord a => [a] -> Maybe a
safeMaximum [] = Nothing
safeMaximum xs = Just (maximum xs)

moleculeToSMILES :: Molecule -> Either String String
moleculeToSMILES molecule = do
  let (renderedAtoms, hydrogenCounts) = collapseTerminalHydrogens molecule
      renderedIds = M.keysSet renderedAtoms
  if M.null renderedAtoms
    then Left "Cannot render an empty molecule as SMILES"
    else do
      bondOrders <- renderBondOrders molecule renderedIds
      let adjacency = buildRenderAdjacency renderedIds bondOrders
          components = connectedComponents renderedIds adjacency
      renderedComponents <- mapM (renderComponent renderedAtoms hydrogenCounts adjacency bondOrders) components
      pure (L.intercalate "." renderedComponents)

collapseTerminalHydrogens :: Molecule -> (M.Map AtomId Atom, M.Map AtomId Int)
collapseTerminalHydrogens molecule =
  ( M.filterWithKey (\aid _ -> not (aid `S.member` suppressed)) (atoms molecule)
  , foldl addHydrogenCount zeroCounts (S.toList suppressed)
  )
  where
    zeroCounts = M.fromList [ (aid, 0) | aid <- M.keys (atoms molecule) ]
    systemAtoms = S.fromList
      [ aid
      | (_, system) <- allSystems molecule
      , not (isConventionalSingleEdgeSystem system)
      , aid <- S.toList (memberAtoms system)
      ]
    suppressed = S.fromList
      [ aid
      | (aid, atom) <- M.toAscList (atoms molecule)
      , symbol (attributes atom) == H
      , formalCharge atom == 0
      , not (aid `S.member` systemAtoms)
      , let incident = [ edge | edge@(Edge x y) <- S.toList (localBonds molecule), x == aid || y == aid ]
      , length incident == 1
      , let edge = head incident
      , let host = otherEndpoint aid edge
      , Just hostAtom <- [M.lookup host (atoms molecule)]
      , symbol (attributes hostAtom) /= H
      , formalCharge hostAtom == 0
      ]

    addHydrogenCount counts aid =
      let incident = [ edge | edge@(Edge x y) <- S.toList (localBonds molecule), x == aid || y == aid ]
          host = otherEndpoint aid (head incident)
      in M.adjust (+ 1) host counts

renderBondOrders :: Molecule -> S.Set AtomId -> Either String (M.Map Edge Int)
renderBondOrders molecule renderedIds = do
  let initialBondOrders = M.fromList
        [ (edge, 1)
        | edge@(Edge a b) <- S.toAscList (localBonds molecule)
        , a `S.member` renderedIds
        , b `S.member` renderedIds
        ]
  foldM applySystem initialBondOrders (allSystems molecule)
  where
    applySystem acc (_, system)
      | tag system == Just "pi_ring"
      , getNN (sharedElectrons system) == 6
      , S.size (memberEdges system) == 6 = do
          cycleAtoms <- orderedCycle (memberEdges system)
          pure $
            foldl
              (\m idx ->
                let edge = mkEdge (cycleAtoms !! idx) (cycleAtoms !! ((idx + 1) `mod` 6))
                    order = if even idx then 2 else 1
                in M.insert edge order m
              )
              acc
              [0 .. 5]
      | S.size (memberEdges system) == 1
      , getNN (sharedElectrons system) `elem` [2, 4, 6] =
          let edge = head (S.toAscList (memberEdges system))
          in if edge `M.member` acc
               then pure (M.insert edge (getNN (sharedElectrons system) `div` 2) acc)
               else pure acc
      | otherwise = Left "SMILES rendering only supports localized double/triple bonds and six-edge pi rings"

orderedCycle :: S.Set Edge -> Either String [AtomId]
orderedCycle ringEdges
  | M.size adjacency /= 6 = Left "pi_ring must be a simple six-membered cycle to render as SMILES"
  | any ((/= 2) . length) (M.elems adjacency) = Left "pi_ring must be a simple six-membered cycle to render as SMILES"
  | otherwise =
      case paths of
        [] -> Left "Failed to derive a six-membered cycle for pi_ring"
        _  -> Right (minimumByAtomPath paths)
  where
    adjacency = adjacencyFromEdges ringEdges
    start = minimum (M.keys adjacency)
    paths =
      [ path
      | neighbor <- M.findWithDefault [] start adjacency
      , Just path <- [walk [start, neighbor] start neighbor]
      ]

    walk path previous current =
      let nextCandidates = [ candidate | candidate <- M.findWithDefault [] current adjacency, candidate /= previous ]
      in case nextCandidates of
           [] -> Nothing
           (nextAtom:_) ->
             if nextAtom == start
               then if length path == 6 then Just path else Nothing
               else
                 if length path > 6
                   then Nothing
                   else walk (path ++ [nextAtom]) current nextAtom

    minimumByAtomPath = minimumByPath . map (\path -> (map atomIdValue path, path))
    minimumByPath xs = snd (minimum xs)

buildRenderAdjacency :: S.Set AtomId -> M.Map Edge Int -> M.Map AtomId [AtomId]
buildRenderAdjacency renderedIds bondOrders =
  M.fromSet neighbors renderedIds
  where
    neighbors aid =
      L.sort
        [ if a == aid then b else a
        | Edge a b <- M.keys bondOrders
        , a == aid || b == aid
        ]

connectedComponents :: S.Set AtomId -> M.Map AtomId [AtomId] -> [[AtomId]]
connectedComponents atomIds adjacency = go atomIds []
  where
    go remaining components
      | S.null remaining = reverse components
      | otherwise =
          let start = S.findMin remaining
              component = dfsComponent S.empty [start]
              remaining' = remaining `S.difference` component
          in go remaining' (S.toAscList component : components)

    dfsComponent visited [] = visited
    dfsComponent visited (aid:rest)
      | aid `S.member` visited = dfsComponent visited rest
      | otherwise =
          let neighbors = M.findWithDefault [] aid adjacency
          in dfsComponent (S.insert aid visited) (neighbors ++ rest)

renderComponent
  :: M.Map AtomId Atom
  -> M.Map AtomId Int
  -> M.Map AtomId [AtomId]
  -> M.Map Edge Int
  -> [AtomId]
  -> Either String String
renderComponent renderedAtoms hydrogenCounts adjacency bondOrders component = do
  let root = minimum component
      componentSet = S.fromList component
      (treeEdges, discovery) = buildTree componentSet adjacency root
      discoveryIndex = M.fromList (zip discovery [0 :: Int ..])
      ringEdges =
        [ edge
        | edge <- M.keys bondOrders
        , edge `S.notMember` treeEdges
        , let (a, b) = atomsOfEdge edge
        , a `S.member` componentSet
        , b `S.member` componentSet
        ]
      sortedRingEdges = L.sortOn (ringEdgeKey discoveryIndex) ringEdges
  if length sortedRingEdges > 9
    then Left "SMILES rendering currently supports at most 9 ring closures per component"
    else
      let (ringStarts, ringEnds) = assignRingDigits discoveryIndex sortedRingEdges bondOrders
      in pure (renderAtom root Nothing treeEdges ringStarts ringEnds)
  where
    renderAtom aid parent treeEdges ringStarts ringEnds =
      let atomLabel = renderAtomLabel (renderedAtoms M.! aid) (M.findWithDefault 0 aid hydrogenCounts)
          startTokens =
            concat
              [ bondSymbol order ++ show digit
              | (digit, order) <- M.findWithDefault [] aid ringStarts
              ]
          endTokens = concatMap show (M.findWithDefault [] aid ringEnds)
          children =
            L.sort
              [ neighbor
              | neighbor <- M.findWithDefault [] aid adjacency
              , mkEdge aid neighbor `S.member` treeEdges
              , Just neighbor /= parent
              ]
          childStrings =
            [ let edge = mkEdge aid child
                  chunk = bondSymbol (bondOrders M.! edge) ++ renderAtom child (Just aid) treeEdges ringStarts ringEnds
              in if idx == 0 then chunk else "(" ++ chunk ++ ")"
            | (idx, child) <- zip [0 :: Int ..] children
            ]
      in atomLabel ++ startTokens ++ endTokens ++ concat childStrings

buildTree :: S.Set AtomId -> M.Map AtomId [AtomId] -> AtomId -> (S.Set Edge, [AtomId])
buildTree componentSet adjacency root =
  let (_, edges, discovery) = go S.empty S.empty [] root Nothing
  in (edges, discovery)
  where
    go visited treeEdges discovery aid parent =
      let visited' = S.insert aid visited
          discovery' = discovery ++ [aid]
          neighbors =
            [ neighbor
            | neighbor <- M.findWithDefault [] aid adjacency
            , neighbor `S.member` componentSet
            , Just neighbor /= parent
            ]
      in foldl
           (\(vis, edges, disc) neighbor ->
             if neighbor `S.member` vis
               then (vis, edges, disc)
               else go vis (S.insert (mkEdge aid neighbor) edges) disc neighbor (Just aid)
           )
           (visited', treeEdges, discovery')
           neighbors

assignRingDigits
  :: M.Map AtomId Int
  -> [Edge]
  -> M.Map Edge Int
  -> (M.Map AtomId [(Int, Int)], M.Map AtomId [Int])
assignRingDigits discoveryIndex ringEdges bondOrders =
  foldl insertRing (M.empty, M.empty) (zip [1 :: Int ..] ringEdges)
  where
    insertRing (starts, ends) (digit, edge) =
      let (a, b) = atomsOfEdge edge
          (first, second) =
            if discoveryIndex M.! a <= discoveryIndex M.! b
              then (a, b)
              else (b, a)
          starts' = M.insertWith (++) first [(digit, bondOrders M.! edge)] starts
          ends' = M.insertWith (++) second [digit] ends
      in (starts', ends')

ringEdgeKey :: M.Map AtomId Int -> Edge -> (Int, Integer, Integer)
ringEdgeKey discoveryIndex edge =
  let (a, b) = atomsOfEdge edge
  in (min (discoveryIndex M.! a) (discoveryIndex M.! b), atomIdValue a, atomIdValue b)

renderAtomLabel :: Atom -> Int -> String
renderAtomLabel atom hydrogenCount =
  "[" ++ show (symbol (attributes atom)) ++ hydrogenPart ++ chargePart ++ "]"
  where
    hydrogenPart
      | hydrogenCount <= 0 = ""
      | hydrogenCount == 1 = "H"
      | otherwise          = "H" ++ show hydrogenCount
    chargePart
      | formalCharge atom == 1 = "+"
      | formalCharge atom > 1  = "+" ++ show (formalCharge atom)
      | formalCharge atom == -1 = "-"
      | formalCharge atom < -1 = "-" ++ show (abs (formalCharge atom))
      | otherwise = ""

bondSymbol :: Int -> String
bondSymbol 1 = ""
bondSymbol 2 = "="
bondSymbol 3 = "#"
bondSymbol n = error ("Unsupported SMILES bond order: " ++ show n)

atomIdValue :: AtomId -> Integer
atomIdValue (AtomId value) = value

otherEndpoint :: AtomId -> Edge -> AtomId
otherEndpoint aid (Edge a b)
  | aid == a   = b
  | otherwise  = a

bondKindFromChar :: Char -> Maybe BondKind
bondKindFromChar '-' = Just BondSingle
bondKindFromChar '=' = Just BondDouble
bondKindFromChar '#' = Just BondTriple
bondKindFromChar ':' = Just BondAromatic
bondKindFromChar _   = Nothing

bondDirectionFromChar :: Char -> Maybe SmilesBondStereoDirection
bondDirectionFromChar '/'  = Just BondUp
bondDirectionFromChar '\\' = Just BondDown
bondDirectionFromChar _    = Nothing

supportsImplicitHydrogens :: AtomicSymbol -> Bool
supportsImplicitHydrogens symbol =
  case symbol of
    B  -> True
    Br -> True
    C  -> True
    Cl -> True
    F  -> True
    I  -> True
    N  -> True
    O  -> True
    P  -> True
    S  -> True
    Si -> True
    _  -> False

atomicSymbolFromToken :: String -> Maybe AtomicSymbol
atomicSymbolFromToken "Br" = Just Br
atomicSymbolFromToken "Cl" = Just Cl
atomicSymbolFromToken "Fe" = Just Fe
atomicSymbolFromToken "Na" = Just Na
atomicSymbolFromToken "Si" = Just Si
atomicSymbolFromToken "B"  = Just B
atomicSymbolFromToken "C"  = Just C
atomicSymbolFromToken "F"  = Just F
atomicSymbolFromToken "H"  = Just H
atomicSymbolFromToken "I"  = Just I
atomicSymbolFromToken "N"  = Just N
atomicSymbolFromToken "O"  = Just O
atomicSymbolFromToken "P"  = Just P
atomicSymbolFromToken "S"  = Just S
atomicSymbolFromToken _    = Nothing

aromaticSymbolFromChar :: Char -> Maybe AtomicSymbol
aromaticSymbolFromChar 'b' = Just B
aromaticSymbolFromChar 'c' = Just C
aromaticSymbolFromChar 'n' = Just N
aromaticSymbolFromChar 'o' = Just O
aromaticSymbolFromChar 'p' = Just P
aromaticSymbolFromChar 's' = Just S
aromaticSymbolFromChar _   = Nothing

trim :: String -> String
trim = dropWhile Char.isSpace . dropWhileEnd Char.isSpace
  where
    dropWhileEnd predicate = reverse . dropWhile predicate . reverse

liftEither :: Either String a -> ParserM a
liftEither eitherValue =
  case eitherValue of
    Left err   -> throwError err
    Right val  -> pure val
