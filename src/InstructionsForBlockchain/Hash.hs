{-# LANGUAGE OverloadedStrings #-}
-- | Small hashing helpers tailored for reproducible on-chain payloads.
-- The functions here avoid pulling in heavyweight crypto libraries while
-- still providing deterministic digests that can be referenced from smart
-- contracts.
module InstructionsForBlockchain.Hash
  ( fnv1a64
  , hashBytes
  , hashBinary
  , hashBuilder
  , renderHash
  ) where

import           Data.Bits (xor)
import           Data.Binary (Binary, encode)
import           Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as BB
import qualified Data.ByteString.Lazy as BL
import           Data.Text (Text)
import qualified Data.Text as T
import           Data.Word (Word64)
import           Numeric (showHex)

-- | FNV-1a constants for 64-bit hashing.
fnvOffsetBasis64 :: Word64
fnvOffsetBasis64 = 0xcbf29ce484222325

fnvPrime64 :: Word64
fnvPrime64 = 0x00000100000001B3

-- | Reduce a 'ByteString' into an FNV-1a 64-bit hash.
hashBytes :: ByteString -> Word64
hashBytes = BS.foldl' step fnvOffsetBasis64
  where
    step h b = (h `xor` fromIntegral b) * fnvPrime64

-- | Hash any value with a 'Binary' instance.
hashBinary :: Binary a => a -> Word64
hashBinary = hashBytes . BL.toStrict . encode

-- | Hash the bytes emitted by a builder.  This is handy when the payload
-- should mix structured numbers (Word64, Double, etc.).
hashBuilder :: BB.Builder -> Word64
hashBuilder = hashBytes . BL.toStrict . BB.toLazyByteString

-- | Expose the raw FNV-1a implementation in case callers want to stream
-- bytes in an incremental fashion.
fnv1a64 :: ByteString -> Word64
fnv1a64 = hashBytes

-- | Render a hash as a hexadecimal 'Text' value.
renderHash :: Word64 -> Text
renderHash h = "0x" <> T.pack (showHex h "")
