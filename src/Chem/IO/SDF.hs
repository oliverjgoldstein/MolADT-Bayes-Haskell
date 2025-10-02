{-# LANGUAGE OverloadedStrings #-}

-- | Minimal SDF (Structure Data File) parser tailored to the Dietz-based
-- molecule representation used in the project.  Only the subset of the V2000
-- format required by the examples is implemented which keeps the parser
-- small and easy to audit.
module Chem.IO.SDF
  ( readSDF
  , parseSDF
  ) where

import           Control.Monad (void)
import           Data.Void (Void)
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import           Text.Megaparsec
import           Text.Megaparsec.Char hiding (eol)
import qualified Text.Megaparsec.Char.Lexer as L
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

-- | Parse SDF contents into a 'Molecule'.
parseSDF :: String -> Either (ParseErrorBundle String Void) Molecule
parseSDF = runParser sdfFile "SDF"

-- Internal parser for a complete V2000 record.
sdfFile :: Parser Molecule
sdfFile = do
  -- skip header lines
  count 3 (manyTill anySingle eol)
  (nAtoms, nBonds) <- parseCounts
  atoms <- zipWithM parseAtom [1..nAtoms] (replicate nAtoms ())
  bonds <- count nBonds parseBond
  chg   <- concat <$> many (try parseChargeLine <|> otherLine)
  _     <- string "M  END"
  -- consume any trailing data (properties/$$$$ markers)
  manyTill anySingle eof
  let atomMap0 = M.fromList [(atomID a, a) | a <- atoms]
      atomMap  = foldl' applyCharge atomMap0 chg
      local    = S.fromList [ e | (e, _) <- bonds ]
      rings    = detectSixRings bonds
      sysList =
        [ (SystemId idx
          , mkBondingSystem (NonNegative 6) ring (Just "pi_ring"))
        | (idx, ring) <- zip [1..] rings ]
      mol = Molecule atomMap local sysList
  pure mol
    where
      -- apply formal charges specified in M  CHG records
      applyCharge m (i,q) = M.adjust (\a -> a { formalCharge = q }) i m

      -- | Parse the counts line (number of atoms and bonds) from the CTAB header.
      parseCounts :: Parser (Int, Int)
      parseCounts = do
        line <- manyTill anySingle eol
        let ws = words line
        case ws of
          (a:b:_) -> pure (read a, read b)
          _       -> fail "Invalid counts line"

      -- | Parse one atom block assigning an index that becomes the 'AtomId'.
      parseAtom :: Int -> () -> Parser Atom
      parseAtom idx _ = do
        line <- manyTill anySingle eol
        let ws = words line
        case ws of
          (xs:ys:zs:sym:_) ->
            case readMaybe sym of
              Just symbol ->
                let x = read xs; y = read ys; z = read zs
                    coord = Coordinate (mkAngstrom x) (mkAngstrom y) (mkAngstrom z)
                in pure Atom { atomID = AtomId (fromIntegral idx)
                              , attributes = elementAttributes symbol
                              , coordinate = coord
                              , shells = elementShells symbol
                              , formalCharge = 0 }
              Nothing -> fail ("Unknown atomic symbol: " ++ sym)
          _ -> fail "Invalid atom line"

      -- | Parse a bond entry returning an undirected 'Edge' and its bond order.
      parseBond :: Parser (Edge, Int)
      parseBond = do
        line <- manyTill anySingle eol
        let ws = words line
        case ws of
          (a:b:typ:_) ->
            let i = AtomId (read a)
                j = AtomId (read b)
                t = read typ
            in pure (mkEdge i j, t)
          _ -> fail "Invalid bond line"

      -- | Parse an 'M  CHG' line producing atom/charge pairs.
      parseChargeLine :: Parser [(AtomId, Int)]
      parseChargeLine = do
        _ <- string "M  CHG"
        hspace1
        n <- L.decimal
        pairs <- count n $ do
          hspace1
          i <- L.decimal
          hspace1
          q <- L.signed hspace L.decimal
          pure (AtomId (fromIntegral i), q)
        hspace
        eol
        pure pairs

      -- | Skip any other property line while preserving parser progress.
      otherLine :: Parser [(AtomId, Int)]
      otherLine = do
        notFollowedBy (string "M  END")
        manyTill anySingle eol
        pure []

      -- | Convenience wrapper around Megaparsec's 'newline'.
      eol :: Parser ()
      eol = void newline

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

-- | Detect 6-membered cycles with alternating single and double bonds to
-- approximate aromatic systems.  The detection is intentionally lightweight
-- and only covers the features required by the benzene demo.
detectSixRings :: [(Edge, Int)] -> [S.Set Edge]
detectSixRings bonds = S.toList . S.fromList $ concatMap (findFrom adj) (M.keys adj)
  where
    -- adjacency map with bond orders
    adj = M.unionWith (++) m1 m2
    m1 = M.fromListWith (++) [ (i, [(j,o)]) | (Edge i j, o) <- bonds ]
    m2 = M.fromListWith (++) [ (j, [(i,o)]) | (Edge i j, o) <- bonds ]

    findFrom :: M.Map AtomId [(AtomId, Int)] -> AtomId -> [S.Set Edge]
    findFrom a start = search [start] start Nothing
      where
        neighbors v = M.findWithDefault [] v a
        alt 1 = 2
        alt 2 = 1
        alt _ = 0

        search path curr mPrev
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
              , res <- search (path ++ [n]) n (Just o)
              ]
