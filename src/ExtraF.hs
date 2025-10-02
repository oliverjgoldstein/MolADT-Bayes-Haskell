-- | Convenience probabilistic helpers built on top of the light-weight PPL.
-- These are intentionally small wrappers used inside examples to keep the
-- probabilistic programs readable.
module ExtraF where
import LazyPPL
import Control.Monad

-- | Uniform draw in the closed interval @[lower, upper]@.
uniformBounded :: Double -> Double -> Prob Double
uniformBounded lower upper = do
  x <- uniform
  return $ (upper - lower) * x + lower

-- | Sum @n@ independent uniforms and rescale them to @[a, b]@.  This is a
-- crude way to form a smoother distribution over the interval than a single
-- uniform draw.
superuniformbounded :: Int -> Double -> Double -> Prob Double
superuniformbounded n a b = do
   xs <- replicateM n uniform
   let x = sum xs
   return $ x * (b - a) + a

-- | Uniform distribution over the integers @[0, n)@.
uniformDiscrete :: Int -> Prob Int
uniformDiscrete n =
  do
    let upper = fromIntegral n
    r <- uniformBounded 0 upper
    return $ floor r

-- | Choose an element from a finite list with equal probability.
uniformD :: [a] -> Prob a
uniformD xs = let l = length xs
              in  do i <- uniformDiscrete l
                     return $ xs !! i

-- | Add hard conditioning to the probability space.  The measure receives
-- weight 1 when the predicate holds and 0 otherwise.
condition :: Bool -> Meas ()
condition True = score 1
condition False = score 0
