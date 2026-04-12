{-# LANGUAGE OverloadedStrings #-}

-- | Minimal SDF (Structure Data File) parser tailored to the Dietz-based
-- molecule representation used in the project. It accepts the local V2000
-- subset and the core V3000 CTAB subset used by common structure exports:
-- atoms, bonds, coordinates, and atom-local formal charges.
module Chem.IO.SDF
  ( readSDF
  , parseSDF
  , readSDFRecords
  , parseSDFRecords
  ) where

import           Data.Char (isSpace)
import           Data.List (isInfixOf, stripPrefix)
import           Data.Maybe (mapMaybe)
import           Data.Void (Void)
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import           Text.Megaparsec
import           Text.Read (readMaybe)

import           Chem.Molecule
import           Chem.Molecule.Coordinate (Coordinate(..), mkAngstrom)
import           Chem.Dietz
import           Constants (elementAttributes, elementShells)

-- | Parser type on String input.
type Parser = Parsec Void String

-- | Read an SDF file into a 'Molecule'.
readSDF :: FilePath -> IO (Either (ParseErrorBundle String Void) Molecule)
readSDF fp = do
  txt <- readFile fp
  pure (parseSDF txt)

-- | Read an SDF file into all parsed 'Molecule' records it contains.
readSDFRecords :: FilePath -> IO (Either (ParseErrorBundle String Void) [Molecule])
readSDFRecords fp = do
  txt <- readFile fp
  pure (parseSDFRecords txt)

-- | Parse SDF contents into a 'Molecule'.
parseSDF :: String -> Either (ParseErrorBundle String Void) Molecule
parseSDF = runParser (sdfFile <* eof) "SDF"

-- | Parse SDF contents into all 'Molecule' records it contains.
parseSDFRecords :: String -> Either (ParseErrorBundle String Void) [Molecule]
parseSDFRecords = runParser (sdfRecordsFile <* eof) "SDF"

-- Internal parser for one SDF record. The outer API still returns Megaparsec
-- errors, but the actual SDF logic stays line-oriented so V2000 and V3000
-- remain easy to audit side by side.
sdfFile :: Parser Molecule
sdfFile = do
  txt <- takeRest
  case parseSDFText txt of
    Left err  -> fail err
    Right mol -> pure mol

sdfRecordsFile :: Parser [Molecule]
sdfRecordsFile = do
  txt <- takeRest
  case parseSDFRecordsText txt of
    Left err   -> fail err
    Right mols -> pure mols


parseSDFRecordsText :: String -> Either String [Molecule]
parseSDFRecordsText txt =
  let blocks = splitSDFBlocks txt
  in if null blocks
       then Left "No SDF record found"
       else mapM parseSDFText blocks


parseSDFText :: String -> Either String Molecule
parseSDFText txt =
  case lines txt of
    (_title : _program : _comment : countsLine : rest) ->
      if "V3000" `isInfixOf` countsLine
        then parseV3000Record rest
        else parseV2000Record countsLine rest
    _ -> Left "Incomplete SDF block"


splitSDFBlocks :: String -> [String]
splitSDFBlocks = go [] [] . lines
  where
    emit acc blocks =
      let block = unlines (reverse acc)
      in if all isSpace block then blocks else block : blocks

    go acc blocks [] = reverse (emit acc blocks)
    go acc blocks ("$$$$" : rest) = go [] (emit acc blocks) rest
    go acc blocks (line : rest) = go (line : acc) blocks rest


parseV2000Record :: String -> [String] -> Either String Molecule
parseV2000Record countsLine rest = do
  (nAtoms, nBonds) <- parseCountsLine countsLine
  let (atomLines, restAfterAtoms) = splitAt nAtoms rest
      (bondLines, tailLines) = splitAt nBonds restAfterAtoms
  if length atomLines /= nAtoms || length bondLines /= nBonds
    then Left "V2000 atom or bond block ended early"
    else do
      atoms <- mapM (uncurry parseV2000Atom) (zip [1 .. nAtoms] atomLines)
      bonds <- mapM parseV2000Bond bondLines
      charges <- parseV2000Charges tailLines
      pure (buildMolecule (applyCharges atoms charges) bonds)


parseV3000Record :: [String] -> Either String Molecule
parseV3000Record rest = do
  ctabLines <- collectV3000LogicalLines rest
  parseV3000Sections ctabLines


parseCountsLine :: String -> Either String (Int, Int)
parseCountsLine line =
  case words line of
    (a : b : _) ->
      case (readMaybe a, readMaybe b) of
        (Just nAtoms, Just nBonds) -> Right (nAtoms, nBonds)
        _ -> Left "Invalid counts line"
    _ -> Left "Invalid counts line"


parseV2000Atom :: Int -> String -> Either String Atom
parseV2000Atom idx line =
  case words line of
    (xs : ys : zs : sym : _) ->
      case (readMaybe xs, readMaybe ys, readMaybe zs, readMaybe sym) of
        (Just x, Just y, Just z, Just symbol) ->
          Right
            Atom
              { atomID = AtomId (fromIntegral idx)
              , attributes = elementAttributes symbol
              , coordinate = Coordinate (mkAngstrom x) (mkAngstrom y) (mkAngstrom z)
              , shells = elementShells symbol
              , formalCharge = 0
              }
        _ -> Left ("Invalid V2000 atom line: " ++ line)
    _ -> Left ("Invalid V2000 atom line: " ++ line)


parseV2000Bond :: String -> Either String (Edge, Int)
parseV2000Bond line =
  case words line of
    (a : b : typ : _) ->
      case (readMaybe a, readMaybe b, readMaybe typ) of
        (Just i, Just j, Just bondType) ->
          Right (mkEdge (AtomId i) (AtomId j), bondType)
        _ -> Left ("Invalid V2000 bond line: " ++ line)
    _ -> Left ("Invalid V2000 bond line: " ++ line)


parseV2000Charges :: [String] -> Either String [(AtomId, Int)]
parseV2000Charges = go []
  where
    go charges [] = Left "Missing M  END line"
    go charges ("M  END" : _) = Right charges
    go charges (line : rest)
      | "M  CHG" `isInfixOf` line = do
          parsedCharges <- parseChargeLineText line
          go (charges ++ parsedCharges) rest
      | otherwise = go charges rest


parseChargeLineText :: String -> Either String [(AtomId, Int)]
parseChargeLineText line =
  case words line of
    ("M" : "CHG" : pairCountText : rest) ->
      case readMaybe pairCountText of
        Nothing -> Left ("Invalid M  CHG line: " ++ line)
        Just pairCount ->
          let values = mapMaybe readMaybe rest
              pairs = chunksOf 2 values
          in if length values < pairCount * 2 || any ((/= 2) . length) (take pairCount pairs)
               then Left ("Invalid M  CHG line: " ++ line)
               else
                 Right
                   [ (AtomId (fromIntegral atomIndex), fromIntegral charge)
                   | [atomIndex, charge] <- take pairCount pairs
                   ]
    _ -> Left ("Invalid M  CHG line: " ++ line)


collectV3000LogicalLines :: [String] -> Either String [String]
collectV3000LogicalLines = go [] Nothing
  where
    go acc pending [] =
      case pending of
        Just _  -> Left "Unterminated V3000 continuation line"
        Nothing -> Left "Missing M  END line"
    go acc pending (line : rest)
      | line == "M  END" =
          case pending of
            Just _  -> Left "Unterminated V3000 continuation line"
            Nothing -> Right (reverse acc)
      | otherwise =
          case stripPrefix "M  V30 " line of
            Nothing ->
              case pending of
                Just _  -> Left "Expected V3000 continuation line"
                Nothing -> go acc Nothing rest
            Just payload ->
              let combined = maybe payload (\prefix -> prefix ++ dropWhile isSpace payload) pending
              in if not (null combined) && last combined == '-'
                   then go acc (Just (rstrip (init combined) ++ " ")) rest
                   else go (combined : acc) Nothing rest


parseV3000Sections :: [String] -> Either String Molecule
parseV3000Sections logicalLines = go Nothing Nothing [] [] logicalLines
  where
    go _ mCounts atoms bonds [] =
      case mCounts of
        Nothing -> Left "Missing V3000 COUNTS line"
        Just (expectedAtoms, expectedBonds)
          | length atoms /= expectedAtoms ->
              Left ("V3000 atom count mismatch: expected " ++ show expectedAtoms ++ ", got " ++ show (length atoms))
          | length bonds /= expectedBonds ->
              Left ("V3000 bond count mismatch: expected " ++ show expectedBonds ++ ", got " ++ show (length bonds))
          | otherwise ->
              Right (buildMolecule atoms bonds)
    go section mCounts atoms bonds (line : rest)
      | line == "BEGIN CTAB" || line == "END CTAB" = go section mCounts atoms bonds rest
      | "COUNTS " `isPrefixText` line = do
          counts <- parseV3000Counts line
          go section (Just counts) atoms bonds rest
      | line == "BEGIN ATOM" = go (Just "ATOM") mCounts atoms bonds rest
      | line == "END ATOM" = go Nothing mCounts atoms bonds rest
      | line == "BEGIN BOND" = go (Just "BOND") mCounts atoms bonds rest
      | line == "END BOND" = go Nothing mCounts atoms bonds rest
      | "BEGIN " `isPrefixText` line = go Nothing mCounts atoms bonds rest
      | "END " `isPrefixText` line = go Nothing mCounts atoms bonds rest
      | section == Just "ATOM" = do
          atom <- parseV3000Atom line
          go section mCounts (atoms ++ [atom]) bonds rest
      | section == Just "BOND" = do
          bond <- parseV3000Bond line
          go section mCounts atoms (bonds ++ [bond]) rest
      | otherwise = go section mCounts atoms bonds rest


parseV3000Counts :: String -> Either String (Int, Int)
parseV3000Counts line =
  case words line of
    ("COUNTS" : atomCountText : bondCountText : _) ->
      case (readMaybe atomCountText, readMaybe bondCountText) of
        (Just atomCount, Just bondCount) -> Right (atomCount, bondCount)
        _ -> Left ("Invalid V3000 COUNTS line: " ++ line)
    _ -> Left ("Invalid V3000 COUNTS line: " ++ line)


parseV3000Atom :: String -> Either String Atom
parseV3000Atom line =
  case words line of
    (indexText : sym : xs : ys : zs : _aamap : rest) ->
      case (readMaybe indexText, readMaybe xs, readMaybe ys, readMaybe zs, readMaybe sym) of
        (Just atomIndex, Just x, Just y, Just z, Just symbol) ->
          let atomCharge = maybe 0 id (firstTaggedInt "CHG=" rest)
          in Right
               Atom
                 { atomID = AtomId atomIndex
                 , attributes = elementAttributes symbol
                 , coordinate = Coordinate (mkAngstrom x) (mkAngstrom y) (mkAngstrom z)
                 , shells = elementShells symbol
                 , formalCharge = atomCharge
                 }
        _ -> Left ("Invalid V3000 atom line: " ++ line)
    _ -> Left ("Invalid V3000 atom line: " ++ line)


parseV3000Bond :: String -> Either String (Edge, Int)
parseV3000Bond line =
  case words line of
    (_bondIndex : bondTypeText : atomAText : atomBText : _) ->
      case (readMaybe bondTypeText, readMaybe atomAText, readMaybe atomBText) of
        (Just bondType, Just atomA, Just atomB) ->
          Right (mkEdge (AtomId atomA) (AtomId atomB), bondType)
        _ -> Left ("Invalid V3000 bond line: " ++ line)
    _ -> Left ("Invalid V3000 bond line: " ++ line)


applyCharges :: [Atom] -> [(AtomId, Int)] -> [Atom]
applyCharges atoms charges =
  let chargeMap = M.fromList charges
  in [ atom { formalCharge = M.findWithDefault (formalCharge atom) (atomID atom) chargeMap }
     | atom <- atoms
     ]


buildMolecule :: [Atom] -> [(Edge, Int)] -> Molecule
buildMolecule atomList bonds =
  let atomMap = M.fromList [(atomID atom, atom) | atom <- atomList]
      local = S.fromList [edge | (edge, _) <- bonds]
      rings = detectSixRings bonds
      sysList =
        [ (SystemId idx, mkBondingSystem (NonNegative 6) ring (Just "pi_ring"))
        | (idx, ring) <- zip [1 ..] rings
        ]
  in Molecule atomMap local sysList emptySmilesStereochemistry


chunksOf :: Int -> [a] -> [[a]]
chunksOf _ [] = []
chunksOf n xs
  | n <= 0 = [xs]
  | otherwise =
      let (prefix, suffix) = splitAt n xs
      in prefix : chunksOf n suffix


rstrip :: String -> String
rstrip = reverse . dropWhile isSpace . reverse


isPrefixText :: String -> String -> Bool
isPrefixText prefix value =
  case stripPrefix prefix value of
    Just _  -> True
    Nothing -> False


firstTaggedInt :: String -> [String] -> Maybe Int
firstTaggedInt prefix =
  firstJust . map (\token -> stripPrefix prefix token >>= readMaybe)


firstJust :: [Maybe a] -> Maybe a
firstJust [] = Nothing
firstJust (Nothing : rest) = firstJust rest
firstJust (value : _) = value

-- | 'zipWithM' for lists with explicit failure on length mismatch.
zipWithM :: MonadFail m => (a -> b -> m c) -> [a] -> [b] -> m [c]
zipWithM _ [] []         = pure []
zipWithM f (x:xs) (y:ys) = (:) <$> f x y <*> zipWithM f xs ys
zipWithM _ _ _           = fail "zipWithM: mismatched lengths"

-- | Strict left fold used locally to avoid building thunks while accumulating
-- charges.
foldl' :: (b -> a -> b) -> b -> [a] -> b
foldl' f z xs = go z xs
  where
    go acc []     = acc
    go acc (y:ys) = let acc' = f acc y in acc' `seq` go acc' ys

-- | Detect 6-membered cycles with either alternating single/double bonds or
-- aromatic V3000 bond type 4 edges. The detection is intentionally lightweight
-- and only covers the local aromatic cases used by the demos and parser tests.
detectSixRings :: [(Edge, Int)] -> [S.Set Edge]
detectSixRings bonds = S.toList . S.fromList $ concatMap (findFrom adj) (M.keys adj)
  where
    -- adjacency map with bond orders
    adj = M.unionWith (++) m1 m2
    m1 = M.fromListWith (++) [ (i, [(j,o)]) | (Edge i j, o) <- bonds ]
    m2 = M.fromListWith (++) [ (j, [(i,o)]) | (Edge i j, o) <- bonds ]

    findFrom :: M.Map AtomId [(AtomId, Int)] -> AtomId -> [S.Set Edge]
    findFrom a start = searchAlternating [start] start Nothing ++ searchAromatic [start] start
      where
        neighbors v = M.findWithDefault [] v a
        alt 1 = 2
        alt 2 = 1
        alt _ = 0

        searchAlternating path curr mPrev
          | length path == 6 =
              case mPrev of
                Just prevOrd ->
                  case lookup start (neighbors curr) of
                    Just o | o == alt prevOrd ->
                      let atoms = path ++ [start]
                          edges = zipWith mkEdge atoms (tail atoms)
                      in if start == minimum path
                            then [S.fromList edges]
                            else []
                    _ -> []
                Nothing -> []
          | otherwise =
              [ res
              | (n,o) <- neighbors curr
              , o `elem` [1,2]
              , maybe True (\p -> o == alt p) mPrev
              , n `notElem` path
              , res <- searchAlternating (path ++ [n]) n (Just o)
              ]

        searchAromatic path curr
          | length path == 6 =
              case lookup start (neighbors curr) of
                Just 4 ->
                  let atoms = path ++ [start]
                      edges = zipWith mkEdge atoms (tail atoms)
                  in if start == minimum path
                        then [S.fromList edges]
                        else []
                _ -> []
          | otherwise =
              [ res
              | (n,o) <- neighbors curr
              , o == 4
              , n `notElem` path
              , res <- searchAromatic (path ++ [n]) n
              ]
