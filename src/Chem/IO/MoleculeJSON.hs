{-# LANGUAGE OverloadedStrings #-}

module Chem.IO.MoleculeJSON
  ( moleculeToJSON
  , moleculeFromJSON
  ) where

import           Control.Monad (unless, when)
import qualified Data.Aeson as A
import           Data.Aeson ((.:), (.:?), (.=))
import           Data.Aeson.Types (Parser, parseEither, (.!=))
import qualified Data.ByteString.Lazy as BL
import qualified Data.Map.Strict as M
import qualified Data.Scientific as Scientific
import qualified Data.Set as S
import qualified Data.Text as T

import           Chem.Dietz
import           Chem.Molecule
import           Chem.Molecule.Coordinate
import           Constants (elementShells)
import qualified Orbital as Orb

moleculeToJSON :: Molecule -> BL.ByteString
moleculeToJSON = A.encode . moleculeToValue

moleculeFromJSON :: BL.ByteString -> Either String Molecule
moleculeFromJSON payload = do
  value <- A.eitherDecode payload
  parseEither parseMoleculeValue value

moleculeToValue :: Molecule -> A.Value
moleculeToValue molecule =
  A.object
    [ "atoms" .=
        [ A.object
            [ "atom_id" .= atomIdValue atomId
            , "atom" .= atomValue atom
            ]
        | (atomId, atom) <- M.toAscList (atoms molecule)
        ]
    , "local_bonds" .= map edgeValue (S.toAscList (localBonds molecule))
    , "systems" .=
        [ A.object
            [ "system_id" .= systemIdValue systemId
            , "bonding_system" .= bondingSystemValue bondingSystem
            ]
        | (systemId, bondingSystem) <- systems molecule
        ]
    , "smiles_stereochemistry" .= smilesStereochemistryValue (smilesStereochemistry molecule)
    ]

atomIdValue :: AtomId -> A.Value
atomIdValue (AtomId value) = A.object ["value" .= value]

systemIdValue :: SystemId -> A.Value
systemIdValue (SystemId value) = A.object ["value" .= value]

nonNegativeValue :: NonNegative -> A.Value
nonNegativeValue (NonNegative value) = A.object ["value" .= value]

edgeValue :: Edge -> A.Value
edgeValue (Edge atomA atomB) =
  A.object
    [ "a" .= atomIdValue atomA
    , "b" .= atomIdValue atomB
    ]

bondingSystemValue :: BondingSystem -> A.Value
bondingSystemValue bondingSystem =
  A.object
    [ "shared_electrons" .= nonNegativeValue (sharedElectrons bondingSystem)
    , "member_atoms" .= map atomIdValue (S.toAscList (memberAtoms bondingSystem))
    , "member_edges" .= map edgeValue (S.toAscList (memberEdges bondingSystem))
    , "tag" .= tag bondingSystem
    ]

elementAttributesValue :: ElementAttributes -> A.Value
elementAttributesValue attrs =
  A.object
    [ "symbol" .= atomicSymbolText (symbol attrs)
    , "atomic_number" .= atomicNumber attrs
    , "atomic_weight" .= atomicWeight attrs
    ]

coordinateValue :: Coordinate -> A.Value
coordinateValue (Coordinate coordX coordY coordZ) =
  A.object
    [ "x" .= angstromValue coordX
    , "y" .= angstromValue coordY
    , "z" .= angstromValue coordZ
    ]

angstromValue :: Angstrom -> A.Value
angstromValue distance = A.object ["value" .= unAngstrom distance]

atomValue :: Atom -> A.Value
atomValue atom =
  A.object
    [ "atom_id" .= atomIdValue (atomID atom)
    , "attributes" .= elementAttributesValue (attributes atom)
    , "coordinate" .= coordinateValue (coordinate atom)
    , "shells" .= map shellValue (shells atom)
    , "formal_charge" .= formalCharge atom
    ]

shellValue :: Orb.Shell -> A.Value
shellValue shell =
  A.object
    [ "principal_quantum_number" .= Orb.principalQuantumNumber shell
    , "s_subshell" .= maybe A.Null subShellSoValue (Orb.sSubShell shell)
    , "p_subshell" .= maybe A.Null subShellPValue (Orb.pSubShell shell)
    , "d_subshell" .= maybe A.Null subShellDValue (Orb.dSubShell shell)
    , "f_subshell" .= maybe A.Null subShellFValue (Orb.fSubShell shell)
    ]

subShellSoValue :: Orb.SubShell Orb.So -> A.Value
subShellSoValue = subShellValue orbitalSoValue

subShellPValue :: Orb.SubShell Orb.P -> A.Value
subShellPValue = subShellValue orbitalPValue

subShellDValue :: Orb.SubShell Orb.D -> A.Value
subShellDValue = subShellValue orbitalDValue

subShellFValue :: Orb.SubShell Orb.F -> A.Value
subShellFValue = subShellValue orbitalFValue

subShellValue :: (orbitalType -> A.Value) -> Orb.SubShell orbitalType -> A.Value
subShellValue renderOrbitalType subShell =
  A.object
    [ "orbitals" .= map (orbitalValue renderOrbitalType) (Orb.orbitals subShell)
    ]

orbitalValue :: (orbitalType -> A.Value) -> Orb.Orbital orbitalType -> A.Value
orbitalValue renderOrbitalType orbital =
  A.object
    [ "orbital_type" .= renderOrbitalType (Orb.orbitalType orbital)
    , "electron_count" .= Orb.electronCount orbital
    , "orientation" .= maybe A.Null coordinateValue (Orb.orientation orbital)
    , "hybrid_components" .= maybe A.Null hybridComponentsValue (Orb.hybridComponents orbital)
    ]

hybridComponentsValue :: [(Double, Orb.PureOrbital)] -> A.Value
hybridComponentsValue hybridComponents =
  A.toJSON
    [ A.object
        [ "weight" .= weight
        , "pure_orbital" .= pureOrbitalValue pureOrbital
        ]
    | (weight, pureOrbital) <- hybridComponents
    ]

pureOrbitalValue :: Orb.PureOrbital -> A.Value
pureOrbitalValue pureOrbital =
  case pureOrbital of
    Orb.PureSo orbital ->
      A.object
        [ "kind" .= ("s" :: T.Text)
        , "orbital" .= orbitalSoValue orbital
        ]
    Orb.PureP orbital ->
      A.object
        [ "kind" .= ("p" :: T.Text)
        , "orbital" .= orbitalPValue orbital
        ]
    Orb.PureD orbital ->
      A.object
        [ "kind" .= ("d" :: T.Text)
        , "orbital" .= orbitalDValue orbital
        ]
    Orb.PureF orbital ->
      A.object
        [ "kind" .= ("f" :: T.Text)
        , "orbital" .= orbitalFValue orbital
        ]

orbitalSoValue :: Orb.So -> A.Value
orbitalSoValue Orb.So = A.String "s"

orbitalPValue :: Orb.P -> A.Value
orbitalPValue orbital =
  A.String $
    case orbital of
      Orb.Px -> "px"
      Orb.Py -> "py"
      Orb.Pz -> "pz"

orbitalDValue :: Orb.D -> A.Value
orbitalDValue orbital =
  A.String $
    case orbital of
      Orb.Dxy -> "dxy"
      Orb.Dyz -> "dyz"
      Orb.Dxz -> "dxz"
      Orb.Dx2y2 -> "dx2y2"
      Orb.Dz2 -> "dz2"

orbitalFValue :: Orb.F -> A.Value
orbitalFValue orbital =
  A.String $
    case orbital of
      Orb.Fxxx -> "fxxx"
      Orb.Fxxy -> "fxxy"
      Orb.Fxxz -> "fxxz"
      Orb.Fxyy -> "fxyy"
      Orb.Fxyz -> "fxyz"
      Orb.Fxzz -> "fxzz"
      Orb.Fzzz -> "fzzz"

smilesStereochemistryValue :: SmilesStereochemistry -> A.Value
smilesStereochemistryValue stereo =
  A.object
    [ "atom_stereo" .= map smilesAtomStereoValue (atomStereoAnnotations stereo)
    , "bond_stereo" .= map smilesBondStereoValue (bondStereoAnnotations stereo)
    ]

smilesAtomStereoValue :: SmilesAtomStereo -> A.Value
smilesAtomStereoValue stereo =
  A.object
    [ "center" .= atomIdValue (stereoCenter stereo)
    , "stereo_class" .= smilesAtomStereoClassValue (stereoClass stereo)
    , "configuration" .= stereoConfiguration stereo
    , "token" .= stereoToken stereo
    ]

smilesBondStereoValue :: SmilesBondStereo -> A.Value
smilesBondStereoValue stereo =
  A.object
    [ "start_atom" .= atomIdValue (bondStereoStart stereo)
    , "end_atom" .= atomIdValue (bondStereoEnd stereo)
    , "direction" .= smilesBondStereoDirectionValue (bondStereoDirection stereo)
    ]

smilesAtomStereoClassValue :: SmilesAtomStereoClass -> A.Value
smilesAtomStereoClassValue stereoClassValue =
  A.String $
    case stereoClassValue of
      StereoTetrahedral -> "TH"
      StereoAllene -> "AL"
      StereoSquarePlanar -> "SP"
      StereoTrigonalBipyramidal -> "TB"
      StereoOctahedral -> "OH"

smilesBondStereoDirectionValue :: SmilesBondStereoDirection -> A.Value
smilesBondStereoDirectionValue direction =
  A.String $
    case direction of
      BondUp -> "/"
      BondDown -> "\\"

atomicSymbolText :: AtomicSymbol -> T.Text
atomicSymbolText atomSymbol =
  case atomSymbol of
    H -> "H"
    C -> "C"
    N -> "N"
    O -> "O"
    S -> "S"
    P -> "P"
    Si -> "Si"
    F -> "F"
    Cl -> "Cl"
    Br -> "Br"
    I -> "I"
    Fe -> "Fe"
    B -> "B"
    Na -> "Na"

parseMoleculeValue :: A.Value -> Parser Molecule
parseMoleculeValue = A.withObject "Molecule" $ \obj -> do
  atomEntriesValue <- obj .: "atoms" :: Parser [A.Value]
  atomEntries <- mapM parseAtomEntryValue atomEntriesValue
  let atomMap = M.fromList atomEntries
  when (length atomEntries /= M.size atomMap) $
    fail "Duplicate atom_id entries in molecule atoms"
  localBondValues <- obj .: "local_bonds" :: Parser [A.Value]
  localBondList <- mapM parseEdgeValue localBondValues
  systemValues <- obj .: "systems" :: Parser [A.Value]
  systemList <- mapM parseSystemEntryValue systemValues
  smilesStereoValue <- obj .:? "smiles_stereochemistry" :: Parser (Maybe A.Value)
  smilesStereo <- maybe (pure emptySmilesStereochemistry) parseSmilesStereochemistryValue smilesStereoValue
  pure
    Molecule
      { atoms = atomMap
      , localBonds = S.fromList localBondList
      , systems = systemList
      , smilesStereochemistry = smilesStereo
      }

parseAtomEntryValue :: A.Value -> Parser (AtomId, Atom)
parseAtomEntryValue = A.withObject "AtomEntry" $ \obj -> do
  atomIdValue' <- obj .: "atom_id"
  atomId' <- parseAtomIdValue atomIdValue'
  atomValue' <- obj .: "atom"
  atom <- parseAtomValue atomValue'
  unless (atomId' == atomID atom) $
    fail "Atom entry atom_id does not match atom.atom_id"
  pure (atomId', atom)

parseSystemEntryValue :: A.Value -> Parser (SystemId, BondingSystem)
parseSystemEntryValue = A.withObject "SystemEntry" $ \obj -> do
  systemIdValue' <- obj .: "system_id"
  systemId' <- parseSystemIdValue systemIdValue'
  bondingSystemValue' <- obj .: "bonding_system"
  bondingSystem <- parseBondingSystemValue bondingSystemValue'
  pure (systemId', bondingSystem)

parseAtomIdValue :: A.Value -> Parser AtomId
parseAtomIdValue = A.withObject "AtomId" $ \obj -> do
  rawValue <- obj .: "value" :: Parser A.Value
  atomIdNumber <- parsePositiveIntegerValue "AtomId" rawValue
  pure (AtomId atomIdNumber)

parseSystemIdValue :: A.Value -> Parser SystemId
parseSystemIdValue = A.withObject "SystemId" $ \obj -> do
  rawValue <- obj .: "value" :: Parser A.Value
  systemIdNumber <- parsePositiveIntValue "SystemId" rawValue
  pure (SystemId systemIdNumber)

parseNonNegativeValue :: A.Value -> Parser NonNegative
parseNonNegativeValue = A.withObject "NonNegative" $ \obj -> do
  rawValue <- obj .: "value" :: Parser A.Value
  number <- parseNonNegativeIntValue "NonNegative" rawValue
  case mkNonNegative number of
    Nothing -> fail "NonNegative value must be >= 0"
    Just nonNegativeNumber -> pure nonNegativeNumber

parseEdgeValue :: A.Value -> Parser Edge
parseEdgeValue = A.withObject "Edge" $ \obj -> do
  atomAValue <- obj .: "a"
  atomBValue <- obj .: "b"
  atomA <- parseAtomIdValue atomAValue
  atomB <- parseAtomIdValue atomBValue
  if atomA == atomB
    then fail "Edge cannot connect an atom to itself"
    else pure (mkEdge atomA atomB)

parseBondingSystemValue :: A.Value -> Parser BondingSystem
parseBondingSystemValue = A.withObject "BondingSystem" $ \obj -> do
  sharedElectronsValue <- obj .: "shared_electrons"
  sharedElectrons' <- parseNonNegativeValue sharedElectronsValue
  memberAtomValues <- obj .:? "member_atoms" .!= [] :: Parser [A.Value]
  memberAtoms' <- S.fromList <$> mapM parseAtomIdValue memberAtomValues
  memberEdgeValues <- obj .: "member_edges" :: Parser [A.Value]
  memberEdges' <- S.fromList <$> mapM parseEdgeValue memberEdgeValues
  tagValue <- obj .:? "tag" :: Parser (Maybe String)
  let bondingSystem = mkBondingSystem sharedElectrons' memberEdges' tagValue
  when (not (S.null memberAtoms') && memberAtoms' /= memberAtoms bondingSystem) $
    fail "member_atoms does not match atoms implied by member_edges"
  pure bondingSystem

parseElementAttributesValue :: A.Value -> Parser ElementAttributes
parseElementAttributesValue = A.withObject "ElementAttributes" $ \obj -> do
  symbolTextValue <- obj .: "symbol" :: Parser T.Text
  atomicSymbol <- parseAtomicSymbolText symbolTextValue
  atomicNumberValue <- obj .: "atomic_number" :: Parser A.Value
  atomicNumber' <- parseIntValue "atomic_number" atomicNumberValue
  atomicWeightValue <- obj .: "atomic_weight" :: Parser A.Value
  atomicWeight' <- parseDoubleValue "atomic_weight" atomicWeightValue
  pure
    ElementAttributes
      { symbol = atomicSymbol
      , atomicNumber = atomicNumber'
      , atomicWeight = atomicWeight'
      }

parseCoordinateValue :: A.Value -> Parser Coordinate
parseCoordinateValue = A.withObject "Coordinate" $ \obj -> do
  xValue <- obj .: "x"
  yValue <- obj .: "y"
  zValue <- obj .: "z"
  coordX <- parseAngstromValue xValue
  coordY <- parseAngstromValue yValue
  coordZ <- parseAngstromValue zValue
  pure (Coordinate coordX coordY coordZ)

parseAngstromValue :: A.Value -> Parser Angstrom
parseAngstromValue = A.withObject "Angstrom" $ \obj -> do
  rawValue <- obj .: "value" :: Parser A.Value
  mkAngstrom <$> parseDoubleValue "Angstrom" rawValue

parseAtomValue :: A.Value -> Parser Atom
parseAtomValue = A.withObject "Atom" $ \obj -> do
  atomIdValue' <- obj .: "atom_id"
  atomId' <- parseAtomIdValue atomIdValue'
  attributesValue' <- obj .: "attributes"
  attributes' <- parseElementAttributesValue attributesValue'
  coordinateValue' <- obj .: "coordinate"
  coordinate' <- parseCoordinateValue coordinateValue'
  shellsValue <- obj .:? "shells" :: Parser (Maybe [A.Value])
  shells' <-
    case shellsValue of
      Nothing -> pure (elementShells (symbol attributes'))
      Just shellValues -> mapM parseShellValue shellValues
  formalChargeValue <- obj .:? "formal_charge" :: Parser (Maybe A.Value)
  formalCharge' <-
    case formalChargeValue of
      Nothing -> pure 0
      Just value -> parseIntValue "formal_charge" value
  pure
    Atom
      { atomID = atomId'
      , attributes = attributes'
      , coordinate = coordinate'
      , shells = shells'
      , formalCharge = formalCharge'
      }

parseShellValue :: A.Value -> Parser Orb.Shell
parseShellValue = A.withObject "Shell" $ \obj -> do
  principalQuantumNumberValue <- obj .: "principal_quantum_number" :: Parser A.Value
  principalQuantumNumber' <- parseIntValue "principal_quantum_number" principalQuantumNumberValue
  when (principalQuantumNumber' < 1) $
    fail "principal_quantum_number must be >= 1"
  sSubShellValue <- obj .:? "s_subshell" :: Parser (Maybe A.Value)
  pSubShellValue <- obj .:? "p_subshell" :: Parser (Maybe A.Value)
  dSubShellValue <- obj .:? "d_subshell" :: Parser (Maybe A.Value)
  fSubShellValue <- obj .:? "f_subshell" :: Parser (Maybe A.Value)
  sSubShell' <- traverse parseSubShellSoValue sSubShellValue
  pSubShell' <- traverse parseSubShellPValue pSubShellValue
  dSubShell' <- traverse parseSubShellDValue dSubShellValue
  fSubShell' <- traverse parseSubShellFValue fSubShellValue
  pure
    Orb.Shell
      { Orb.principalQuantumNumber = principalQuantumNumber'
      , Orb.sSubShell = sSubShell'
      , Orb.pSubShell = pSubShell'
      , Orb.dSubShell = dSubShell'
      , Orb.fSubShell = fSubShell'
      }

parseSubShellSoValue :: A.Value -> Parser (Orb.SubShell Orb.So)
parseSubShellSoValue = parseSubShellValue parseOrbitalSoValue

parseSubShellPValue :: A.Value -> Parser (Orb.SubShell Orb.P)
parseSubShellPValue = parseSubShellValue parseOrbitalPValue

parseSubShellDValue :: A.Value -> Parser (Orb.SubShell Orb.D)
parseSubShellDValue = parseSubShellValue parseOrbitalDValue

parseSubShellFValue :: A.Value -> Parser (Orb.SubShell Orb.F)
parseSubShellFValue = parseSubShellValue parseOrbitalFValue

parseSubShellValue :: (A.Value -> Parser (Orb.Orbital orbitalType)) -> A.Value -> Parser (Orb.SubShell orbitalType)
parseSubShellValue parseOrbitalType = A.withObject "SubShell" $ \obj -> do
  orbitalValues <- obj .: "orbitals" :: Parser [A.Value]
  Orb.SubShell <$> mapM parseOrbitalType orbitalValues

parseOrbitalSoValue :: A.Value -> Parser (Orb.Orbital Orb.So)
parseOrbitalSoValue = parseOrbitalValue parseSoValue

parseOrbitalPValue :: A.Value -> Parser (Orb.Orbital Orb.P)
parseOrbitalPValue = parseOrbitalValue parsePValue

parseOrbitalDValue :: A.Value -> Parser (Orb.Orbital Orb.D)
parseOrbitalDValue = parseOrbitalValue parseDValue

parseOrbitalFValue :: A.Value -> Parser (Orb.Orbital Orb.F)
parseOrbitalFValue = parseOrbitalValue parseFValue

parseOrbitalValue :: (A.Value -> Parser orbitalType) -> A.Value -> Parser (Orb.Orbital orbitalType)
parseOrbitalValue parseOrbitalType = A.withObject "Orbital" $ \obj -> do
  orbitalTypeValue <- obj .: "orbital_type"
  orbitalType' <- parseOrbitalType orbitalTypeValue
  electronCountValue <- obj .: "electron_count" :: Parser A.Value
  electronCount' <- parseNonNegativeIntValue "electron_count" electronCountValue
  orientationValue <- obj .:? "orientation" :: Parser (Maybe A.Value)
  orientation' <- traverse parseCoordinateValue orientationValue
  hybridComponentValues <- obj .:? "hybrid_components" :: Parser (Maybe [A.Value])
  hybridComponents' <- traverse (mapM parseHybridComponentValue) hybridComponentValues
  pure
    Orb.Orbital
      { Orb.orbitalType = orbitalType'
      , Orb.electronCount = electronCount'
      , Orb.orientation = orientation'
      , Orb.hybridComponents = hybridComponents'
      }

parseHybridComponentValue :: A.Value -> Parser (Double, Orb.PureOrbital)
parseHybridComponentValue = A.withObject "HybridComponent" $ \obj -> do
  weightValue <- obj .: "weight" :: Parser A.Value
  weight <- parseDoubleValue "weight" weightValue
  pureOrbitalValue' <- obj .: "pure_orbital"
  pureOrbital' <- parsePureOrbitalValue pureOrbitalValue'
  pure (weight, pureOrbital')

parsePureOrbitalValue :: A.Value -> Parser Orb.PureOrbital
parsePureOrbitalValue = A.withObject "PureOrbital" $ \obj -> do
  kind <- obj .: "kind" :: Parser T.Text
  orbitalValue' <- obj .: "orbital"
  case kind of
    "s" -> Orb.PureSo <$> parseSoValue orbitalValue'
    "p" -> Orb.PureP <$> parsePValue orbitalValue'
    "d" -> Orb.PureD <$> parseDValue orbitalValue'
    "f" -> Orb.PureF <$> parseFValue orbitalValue'
    _ -> fail ("Unknown pure orbital kind: " ++ T.unpack kind)

parseSmilesStereochemistryValue :: A.Value -> Parser SmilesStereochemistry
parseSmilesStereochemistryValue = A.withObject "SmilesStereochemistry" $ \obj -> do
  atomStereoValues <- obj .:? "atom_stereo" .!= [] :: Parser [A.Value]
  bondStereoValues <- obj .:? "bond_stereo" .!= [] :: Parser [A.Value]
  atomStereo' <- mapM parseSmilesAtomStereoValue atomStereoValues
  bondStereo' <- mapM parseSmilesBondStereoValue bondStereoValues
  pure
    SmilesStereochemistry
      { atomStereoAnnotations = atomStereo'
      , bondStereoAnnotations = bondStereo'
      }

parseSmilesAtomStereoValue :: A.Value -> Parser SmilesAtomStereo
parseSmilesAtomStereoValue = A.withObject "SmilesAtomStereo" $ \obj -> do
  centerValue <- obj .: "center"
  center' <- parseAtomIdValue centerValue
  stereoClassValue' <- obj .: "stereo_class"
  stereoClass' <- parseSmilesAtomStereoClassValue stereoClassValue'
  configurationValue <- obj .: "configuration" :: Parser A.Value
  configuration' <- parsePositiveIntValue "configuration" configurationValue
  token' <- obj .: "token" :: Parser String
  pure
    SmilesAtomStereo
      { stereoCenter = center'
      , stereoClass = stereoClass'
      , stereoConfiguration = configuration'
      , stereoToken = token'
      }

parseSmilesBondStereoValue :: A.Value -> Parser SmilesBondStereo
parseSmilesBondStereoValue = A.withObject "SmilesBondStereo" $ \obj -> do
  startAtomValue <- obj .: "start_atom"
  startAtom' <- parseAtomIdValue startAtomValue
  endAtomValue <- obj .: "end_atom"
  endAtom' <- parseAtomIdValue endAtomValue
  directionValue <- obj .: "direction"
  direction' <- parseSmilesBondStereoDirectionValue directionValue
  pure
    SmilesBondStereo
      { bondStereoStart = startAtom'
      , bondStereoEnd = endAtom'
      , bondStereoDirection = direction'
      }

parseSmilesAtomStereoClassValue :: A.Value -> Parser SmilesAtomStereoClass
parseSmilesAtomStereoClassValue = A.withText "SmilesAtomStereoClass" $ \value ->
  case value of
    "TH" -> pure StereoTetrahedral
    "AL" -> pure StereoAllene
    "SP" -> pure StereoSquarePlanar
    "TB" -> pure StereoTrigonalBipyramidal
    "OH" -> pure StereoOctahedral
    _ -> fail ("Unknown SMILES atom stereo class: " ++ T.unpack value)

parseSmilesBondStereoDirectionValue :: A.Value -> Parser SmilesBondStereoDirection
parseSmilesBondStereoDirectionValue = A.withText "SmilesBondStereoDirection" $ \value ->
  case value of
    "/" -> pure BondUp
    "\\" -> pure BondDown
    _ -> fail ("Unknown SMILES bond stereo direction: " ++ T.unpack value)

parseAtomicSymbolText :: T.Text -> Parser AtomicSymbol
parseAtomicSymbolText value =
  case value of
    "H" -> pure H
    "C" -> pure C
    "N" -> pure N
    "O" -> pure O
    "S" -> pure S
    "P" -> pure P
    "Si" -> pure Si
    "F" -> pure F
    "Cl" -> pure Cl
    "Br" -> pure Br
    "I" -> pure I
    "Fe" -> pure Fe
    "B" -> pure B
    "Na" -> pure Na
    _ -> fail ("Unknown atomic symbol: " ++ T.unpack value)

parseSoValue :: A.Value -> Parser Orb.So
parseSoValue = A.withText "s orbital type" $ \value ->
  case value of
    "s" -> pure Orb.So
    _ -> fail ("Unknown s orbital type: " ++ T.unpack value)

parsePValue :: A.Value -> Parser Orb.P
parsePValue = A.withText "p orbital type" $ \value ->
  case value of
    "px" -> pure Orb.Px
    "py" -> pure Orb.Py
    "pz" -> pure Orb.Pz
    _ -> fail ("Unknown p orbital type: " ++ T.unpack value)

parseDValue :: A.Value -> Parser Orb.D
parseDValue = A.withText "d orbital type" $ \value ->
  case value of
    "dxy" -> pure Orb.Dxy
    "dyz" -> pure Orb.Dyz
    "dxz" -> pure Orb.Dxz
    "dx2y2" -> pure Orb.Dx2y2
    "dz2" -> pure Orb.Dz2
    _ -> fail ("Unknown d orbital type: " ++ T.unpack value)

parseFValue :: A.Value -> Parser Orb.F
parseFValue = A.withText "f orbital type" $ \value ->
  case value of
    "fxxx" -> pure Orb.Fxxx
    "fxxy" -> pure Orb.Fxxy
    "fxxz" -> pure Orb.Fxxz
    "fxyy" -> pure Orb.Fxyy
    "fxyz" -> pure Orb.Fxyz
    "fxzz" -> pure Orb.Fxzz
    "fzzz" -> pure Orb.Fzzz
    _ -> fail ("Unknown f orbital type: " ++ T.unpack value)

parsePositiveIntegerValue :: String -> A.Value -> Parser Integer
parsePositiveIntegerValue label = A.withScientific label $ \value ->
  case Scientific.floatingOrInteger value :: Either Double Integer of
    Right integerValue
      | integerValue > 0 -> pure integerValue
      | otherwise -> fail (label ++ " must be positive")
    Left _ -> fail (label ++ " must be an integer")

parsePositiveIntValue :: String -> A.Value -> Parser Int
parsePositiveIntValue label = A.withScientific label $ \value ->
  case Scientific.toBoundedInteger value of
    Just intValue
      | intValue > 0 -> pure intValue
      | otherwise -> fail (label ++ " must be positive")
    Nothing -> fail (label ++ " must be an integer")

parseNonNegativeIntValue :: String -> A.Value -> Parser Int
parseNonNegativeIntValue label = A.withScientific label $ \value ->
  case Scientific.toBoundedInteger value of
    Just intValue
      | intValue >= 0 -> pure intValue
      | otherwise -> fail (label ++ " must be >= 0")
    Nothing -> fail (label ++ " must be an integer")

parseIntValue :: String -> A.Value -> Parser Int
parseIntValue label = A.withScientific label $ \value ->
  case Scientific.toBoundedInteger value of
    Just intValue -> pure intValue
    Nothing -> fail (label ++ " must be an integer")

parseDoubleValue :: String -> A.Value -> Parser Double
parseDoubleValue label = A.withScientific label (pure . Scientific.toRealFloat)
