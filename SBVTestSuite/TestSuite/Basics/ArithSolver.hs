-----------------------------------------------------------------------------
-- |
-- Module      :  TestSuite.Basics.ArithSolver
-- Copyright   :  (c) Levent Erkok
-- License     :  BSD3
-- Maintainer  :  erkokl@gmail.com
-- Stability   :  experimental
--
-- Test suite for basic non-concrete arithmetic, i.e., testing all
-- basic arithmetic reasoning using an SMT solver without any
-- constant folding.
-----------------------------------------------------------------------------

{-# LANGUAGE Rank2Types       #-}
{-# LANGUAGE FlexibleContexts #-}

module TestSuite.Basics.ArithSolver(tests) where

import qualified Data.Binary.IEEE754 as DB (wordToFloat, wordToDouble, floatToWord, doubleToWord)

import Data.SBV.Internals
import Utils.SBVTestFramework

import Data.List (genericIndex, isInfixOf, isPrefixOf, isSuffixOf, genericTake, genericDrop, genericLength)

import qualified Data.Char     as C
import qualified Data.SBV.Char as SC
import qualified Data.SBV.String as SS

-- Test suite
tests :: TestTree
tests =
  testGroup "Basics.ArithSolver"
   (    genReals
     ++ genFloats
     ++ genDoubles
     ++ genFPConverts
     ++ genQRems
     ++ genBinTest       True  "+"                (+)
     ++ genBinTest       True  "-"                (-)
     ++ genBinTest       True  "*"                (*)
     ++ genUnTest        True  "negate"           negate
     ++ genUnTest        True  "abs"              abs
     ++ genUnTest        True  "signum"           signum
     ++ genBinTest       False ".&."              (.&.)
     ++ genBinTest       False ".|."              (.|.)
     ++ genBoolTest            "<"                (<)  (.<)
     ++ genBoolTest            "<="               (<=) (.<=)
     ++ genBoolTest            ">"                (>)  (.>)
     ++ genBoolTest            ">="               (>=) (.>=)
     ++ genBoolTest            "=="               (==) (.==)
     ++ genBoolTest            "/="               (/=) (./=)
     ++ genBinTest       False "xor"              xor
     ++ genUnTest        False "complement"       complement
     ++ genIntTest       False "setBit"           setBit
     ++ genIntTest       False "clearBit"         clearBit
     ++ genIntTest       False "complementBit"    complementBit
     ++ genIntTest       True  "shift"            shift
     ++ genIntTest       True  "shiftL"           shiftL
     ++ genIntTest       True  "shiftR"           shiftR
     ++ genIntTest       True  "rotate"           rotate
     ++ genIntTest       True  "rotateL"          rotateL
     ++ genIntTest       True  "rotateR"          rotateR
     ++ genShiftRotTest        "shiftL_gen"       sShiftLeft
     ++ genShiftRotTest        "shiftR_gen"       sShiftRight
     ++ genShiftRotTest        "rotateL_gen"      sRotateLeft
     ++ genShiftRotTest        "rotateR_gen"      sRotateRight
     ++ genShiftMixSize
     ++ genBlasts
     ++ genCounts
     ++ genIntCasts
     ++ genChars
     ++ genStrings
     )

genBinTest :: Bool -> String -> (forall a. (Num a, Bits a) => a -> a -> a) -> [TestTree]
genBinTest unboundedOK nm op = map mkTest $  [(show x, show y, mkThm2 x y (x `op` y)) | x <- w8s,  y <- w8s ]
                                          ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- w16s, y <- w16s]
                                          ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- w32s, y <- w32s]
                                          ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- w64s, y <- w64s]
                                          ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- i8s,  y <- i8s ]
                                          ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- i16s, y <- i16s]
                                          ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- i32s, y <- i32s]
                                          ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- i64s, y <- i64s]
                                          ++ [(show x, show y, mkThm2 x y (x `op` y)) | unboundedOK, x <- iUBs, y <- iUBs]
  where mkTest (x, y, t) = testCase ("genBinTest.arithmetic-" ++ nm ++ "." ++ x ++ "_" ++ y) (assert t)
        mkThm2 x y r = isTheorem $ do [a, b] <- mapM free ["x", "y"]
                                      constrain $ a .== literal x
                                      constrain $ b .== literal y
                                      return $ literal r .== a `op` b

genBoolTest :: String -> (forall a. Ord a => a -> a -> Bool) -> (forall a. OrdSymbolic a => a -> a -> SBool) -> [TestTree]
genBoolTest nm op opS = map mkTest $  [(show x, show y, mkThm2 x y (x `op` y)) | x <- w8s,       y <- w8s ]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- w16s,      y <- w16s]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- w32s,      y <- w32s]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- w64s,      y <- w64s]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- i8s,       y <- i8s ]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- i16s,      y <- i16s]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- i32s,      y <- i32s]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- i64s,      y <- i64s]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- iUBs,      y <- iUBs]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- reducedCS, y <- reducedCS]
                                   ++ [(show x, show y, mkThm2 x y (x `op` y)) | x <- ss,        y <- ss, nm `elem` allowedStringComps]
  where -- Currently Z3 doesn't allow for string comparisons, so only test equals and distinct
        -- See: https://github.com/LeventErkok/sbv/issues/368 for tracking issue.
        allowedStringComps = ["==", "/="]
        mkTest (x, y, t) = testCase ("genBoolTest.arithmetic-" ++ nm ++ "." ++ x ++ "_" ++ y) (assert t)
        mkThm2 x y r = isTheorem $ do [a, b] <- mapM free ["x", "y"]
                                      constrain $ a .== literal x
                                      constrain $ b .== literal y
                                      return $ literal r .== a `opS` b

genUnTest :: Bool -> String -> (forall a. (Num a, Bits a) => a -> a) -> [TestTree]
genUnTest unboundedOK nm op = map mkTest $  [(show x, mkThm x (op x)) | x <- w8s ]
                                         ++ [(show x, mkThm x (op x)) | x <- w16s]
                                         ++ [(show x, mkThm x (op x)) | x <- w32s]
                                         ++ [(show x, mkThm x (op x)) | x <- w64s]
                                         ++ [(show x, mkThm x (op x)) | x <- i8s ]
                                         ++ [(show x, mkThm x (op x)) | x <- i16s]
                                         ++ [(show x, mkThm x (op x)) | x <- i32s]
                                         ++ [(show x, mkThm x (op x)) | x <- i64s]
                                         ++ [(show x, mkThm x (op x)) | unboundedOK, x <- iUBs]
  where mkTest (x, t) = testCase ("genUnTest.arithmetic-" ++ nm ++ "." ++ x) (assert t)
        mkThm x r = isTheorem $ do a <- free "x"
                                   constrain $ a .== literal x
                                   return $ literal r .== op a

genIntTest :: Bool -> String -> (forall a. (Num a, Bits a) => (a -> Int -> a)) -> [TestTree]
genIntTest overSized nm op = map mkTest $
        [("u8",  show x, show y, mkThm2 x y (x `op` y)) | x <- w8s,  y <- is (intSizeOf x)]
     ++ [("u16", show x, show y, mkThm2 x y (x `op` y)) | x <- w16s, y <- is (intSizeOf x)]
     ++ [("u32", show x, show y, mkThm2 x y (x `op` y)) | x <- w32s, y <- is (intSizeOf x)]
     ++ [("u64", show x, show y, mkThm2 x y (x `op` y)) | x <- w64s, y <- is (intSizeOf x)]
     ++ [("s8",  show x, show y, mkThm2 x y (x `op` y)) | x <- i8s,  y <- is (intSizeOf x)]
     ++ [("s16", show x, show y, mkThm2 x y (x `op` y)) | x <- i16s, y <- is (intSizeOf x)]
     ++ [("s32", show x, show y, mkThm2 x y (x `op` y)) | x <- i32s, y <- is (intSizeOf x)]
     ++ [("s64", show x, show y, mkThm2 x y (x `op` y)) | x <- i64s, y <- is (intSizeOf x)]
     -- No size based tests for unbounded integers
  where is sz = [0 .. sz - 1] ++ extras
          where extras
                 | overSized = map (sz +) ([0 .. 1] ++ [sz, sz+1])
                 | True      = []
        mkTest (l, x, y, t) = testCase ("genIntTest.arithmetic-" ++ nm ++ "." ++ l ++ "_" ++ x ++ "_" ++ y) (assert t)
        mkThm2 x y r = isTheorem $ do a <- free "x"
                                      constrain $ a .== literal x
                                      return $ literal r .== a `op` y

genShiftRotTest :: String -> (forall a. (SIntegral a, SDivisible (SBV a)) => (SBV a -> SBV a -> SBV a)) -> [TestTree]
genShiftRotTest nm op = map mkTest $
        [("u8",  show x, show y, mkThm2 x (fromIntegral y) (literal x `op` sFromIntegral (literal y))) | x <- w8s,  y <- is (intSizeOf x)]
     ++ [("u16", show x, show y, mkThm2 x (fromIntegral y) (literal x `op` sFromIntegral (literal y))) | x <- w16s, y <- is (intSizeOf x)]
     ++ [("u32", show x, show y, mkThm2 x (fromIntegral y) (literal x `op` sFromIntegral (literal y))) | x <- w32s, y <- is (intSizeOf x)]
     ++ [("u64", show x, show y, mkThm2 x (fromIntegral y) (literal x `op` sFromIntegral (literal y))) | x <- w64s, y <- is (intSizeOf x)]
     ++ [("s8",  show x, show y, mkThm2 x (fromIntegral y) (literal x `op` sFromIntegral (literal y))) | x <- i8s,  y <- is (intSizeOf x)]
     ++ [("s16", show x, show y, mkThm2 x (fromIntegral y) (literal x `op` sFromIntegral (literal y))) | x <- i16s, y <- is (intSizeOf x)]
     ++ [("s32", show x, show y, mkThm2 x (fromIntegral y) (literal x `op` sFromIntegral (literal y))) | x <- i32s, y <- is (intSizeOf x)]
     ++ [("s64", show x, show y, mkThm2 x (fromIntegral y) (literal x `op` sFromIntegral (literal y))) | x <- i64s, y <- is (intSizeOf x)]
     -- NB. No generic shift/rotate for SMTLib unbounded integers
  where is sz = let b :: Word32
                    b = fromIntegral sz
                in [0 .. b - 1] ++ [b, b+1, 2*b, 2*b+1]
        mkTest (l, x, y, t) = testCase ("genShiftRotTest.arithmetic-" ++ nm ++ "." ++ l ++ "_" ++ x ++ "_" ++ y) (assert t)
        mkThm2 x y sr
         | Just r <- unliteral sr
         = isTheorem $ do [a, b] <- mapM free ["x", "y"]
                          constrain $ a .== literal x
                          constrain $ b .== literal y
                          return $ literal r .== a `op` b
         | True
         = return False

-- A few tests for mixed-size shifts
genShiftMixSize :: [TestTree]
genShiftMixSize = map mkTest $  [(show x, show y, "shl_w8_w16", mk sShiftLeft  x y (x `shiftL` fromIntegral y)) | x <- w8s,  y <- yw16s]
                             ++ [(show x, show y, "shr_w8_w16", mk sShiftRight x y (x `shiftR` fromIntegral y)) | x <- w8s,  y <- yw16s]
                             ++ [(show x, show y, "shl_w16_w8", mk sShiftLeft  x y (x `shiftL` fromIntegral y)) | x <- w16s, y <- w8s]
                             ++ [(show x, show y, "shr_w16_w8", mk sShiftRight x y (x `shiftR` fromIntegral y)) | x <- w16s, y <- w8s]
                             ++ [(show x, show y, "shl_i8_i16", mk sShiftLeft  x y (x `shiftL` fromIntegral y)) | x <- i8s,  y <- yi16s]
                             ++ [(show x, show y, "shr_i8_i16", mk sShiftRight x y (x `shiftR` fromIntegral y)) | x <- i8s,  y <- yi16s]
                             ++ [(show x, show y, "shl_i16_i8", mk sShiftLeft  x y (x `shiftL` fromIntegral y)) | x <- i16s, y <- i8s, y >= 0]
                             ++ [(show x, show y, "shr_i16_i8", mk sShiftRight x y (x `shiftR` fromIntegral y)) | x <- i16s, y <- i8s, y >= 0]
                             ++ [(show x, show y, "shl_w8_i16", mk sShiftLeft  x y (x `shiftL` fromIntegral y)) | x <- w8s,  y <- yi16s]
                             ++ [(show x, show y, "shr_w8_i16", mk sShiftRight x y (x `shiftR` fromIntegral y)) | x <- w8s,  y <- yi16s]
                             ++ [(show x, show y, "shl_w16_i8", mk sShiftLeft  x y (x `shiftL` fromIntegral y)) | x <- w16s, y <- i8s, y >= 0]
                             ++ [(show x, show y, "shr_w16_i8", mk sShiftRight x y (x `shiftR` fromIntegral y)) | x <- w16s, y <- i8s, y >= 0]
                             ++ [(show x, show y, "shl_i8_w16", mk sShiftLeft  x y (x `shiftL` fromIntegral y)) | x <- i8s,  y <- yw16s]
                             ++ [(show x, show y, "shr_i8_w16", mk sShiftRight x y (x `shiftR` fromIntegral y)) | x <- i8s,  y <- yw16s]
                             ++ [(show x, show y, "shl_i16_w8", mk sShiftLeft  x y (x `shiftL` fromIntegral y)) | x <- i16s, y <- w8s]
                             ++ [(show x, show y, "shr_i16_w8", mk sShiftRight x y (x `shiftR` fromIntegral y)) | x <- i16s, y <- w8s]
   where yi16s :: [Int16]
         yi16s = [0, 255, 256, 257, maxBound]

         yw16s :: [Word16]
         yw16s = [0, 255, 256, 257, maxBound]

         mkTest (x, y, l, t) = testCase ("genShiftMixSize." ++ l ++ "." ++ x ++ "_" ++ y) (assert t)
         mk :: (SymWord a, SymWord b) => (SBV a -> SBV b -> SBV a) -> a -> b -> a -> IO Bool
         mk o x y r
          = isTheorem $ do a <- free "x"
                           b <- free "y"
                           constrain $ a .== literal x
                           constrain $ b .== literal y
                           return $ literal r .== a `o` b

genBlasts :: [TestTree]
genBlasts = map mkTest $  [(show x, mkThm fromBitsLE blastLE x) | x <- w8s ]
                       ++ [(show x, mkThm fromBitsBE blastBE x) | x <- w8s ]
                       ++ [(show x, mkThm fromBitsLE blastLE x) | x <- i8s ]
                       ++ [(show x, mkThm fromBitsBE blastBE x) | x <- i8s ]
                       ++ [(show x, mkThm fromBitsLE blastLE x) | x <- w16s]
                       ++ [(show x, mkThm fromBitsBE blastBE x) | x <- w16s]
                       ++ [(show x, mkThm fromBitsLE blastLE x) | x <- i16s]
                       ++ [(show x, mkThm fromBitsBE blastBE x) | x <- i16s]
                       ++ [(show x, mkThm fromBitsLE blastLE x) | x <- w32s]
                       ++ [(show x, mkThm fromBitsBE blastBE x) | x <- w32s]
                       ++ [(show x, mkThm fromBitsLE blastLE x) | x <- i32s]
                       ++ [(show x, mkThm fromBitsBE blastBE x) | x <- i32s]
                       ++ [(show x, mkThm fromBitsLE blastLE x) | x <- w64s]
                       ++ [(show x, mkThm fromBitsBE blastBE x) | x <- w64s]
                       ++ [(show x, mkThm fromBitsLE blastLE x) | x <- i64s]
                       ++ [(show x, mkThm fromBitsBE blastBE x) | x <- i64s]
  where mkTest (x, t) = testCase ("genBlasts.blast-" ++ show x) (assert t)
        mkThm from to v = isTheorem $ do a <- free "x"
                                         constrain $ a .== literal v
                                         return $ a .== from (to a)

genCounts :: [TestTree]
genCounts = map mkTest $  [(show x, mkThm (fromBitsLE :: [SBool] -> SWord8 ) blastBE x) | x <- w8s ]
                       ++ [(show x, mkThm (fromBitsBE :: [SBool] -> SWord8 ) blastLE x) | x <- w8s ]
                       ++ [(show x, mkThm (fromBitsLE :: [SBool] -> SInt8  ) blastBE x) | x <- i8s ]
                       ++ [(show x, mkThm (fromBitsBE :: [SBool] -> SInt8  ) blastLE x) | x <- i8s ]
                       ++ [(show x, mkThm (fromBitsLE :: [SBool] -> SWord16) blastBE x) | x <- w16s]
                       ++ [(show x, mkThm (fromBitsBE :: [SBool] -> SWord16) blastLE x) | x <- w16s]
                       ++ [(show x, mkThm (fromBitsLE :: [SBool] -> SInt16 ) blastBE x) | x <- i16s]
                       ++ [(show x, mkThm (fromBitsBE :: [SBool] -> SInt16 ) blastLE x) | x <- i16s]
                       ++ [(show x, mkThm (fromBitsLE :: [SBool] -> SWord32) blastBE x) | x <- w32s]
                       ++ [(show x, mkThm (fromBitsBE :: [SBool] -> SWord32) blastLE x) | x <- w32s]
                       ++ [(show x, mkThm (fromBitsLE :: [SBool] -> SInt32 ) blastBE x) | x <- i32s]
                       ++ [(show x, mkThm (fromBitsBE :: [SBool] -> SInt32 ) blastLE x) | x <- i32s]
                       ++ [(show x, mkThm (fromBitsLE :: [SBool] -> SWord64) blastBE x) | x <- w64s]
                       ++ [(show x, mkThm (fromBitsBE :: [SBool] -> SWord64) blastLE x) | x <- w64s]
                       ++ [(show x, mkThm (fromBitsLE :: [SBool] -> SInt64 ) blastBE x) | x <- i64s]
                       ++ [(show x, mkThm (fromBitsBE :: [SBool] -> SInt64 ) blastLE x) | x <- i64s]
  where mkTest (x, t) = testCase ("genCounts.count-" ++ show x) (assert t)
        mkThm from to v = isTheorem $ do a <- free "x"
                                         constrain $ a .== literal v
                                         return $ sCountTrailingZeros a .== sCountLeadingZeros (from (to a))

genIntCasts :: [TestTree]
genIntCasts = map mkTest $  cast w8s ++ cast w16s ++ cast w32s ++ cast w64s
                         ++ cast i8s ++ cast i16s ++ cast i32s ++ cast i64s
                         ++ cast iUBs
   where mkTest (x, t) = testCase ("sIntCast-" ++ x) (assert t)
         cast :: forall a. (Show a, Integral a, SymWord a) => [a] -> [(String, IO Bool)]
         cast xs = toWords xs ++ toInts xs
         toWords xs =  [(show x, mkThm x (fromIntegral x :: Word8 ))  | x <- xs]
                    ++ [(show x, mkThm x (fromIntegral x :: Word16))  | x <- xs]
                    ++ [(show x, mkThm x (fromIntegral x :: Word32))  | x <- xs]
                    ++ [(show x, mkThm x (fromIntegral x :: Word64))  | x <- xs]
         toInts  xs =  [(show x, mkThm x (fromIntegral x :: Int8 ))   | x <- xs]
                    ++ [(show x, mkThm x (fromIntegral x :: Int16))   | x <- xs]
                    ++ [(show x, mkThm x (fromIntegral x :: Int32))   | x <- xs]
                    ++ [(show x, mkThm x (fromIntegral x :: Int64))   | x <- xs]
                    ++ [(show x, mkThm x (fromIntegral x :: Integer)) | x <- xs]
         mkThm v res = isTheorem $ do a <- free "x"
                                      constrain $ a .== literal v
                                      return $ literal res .== sFromIntegral a

genReals :: [TestTree]
genReals = map mkTest $  [("+",  show x, show y, mkThm2 (+)   x y (x +  y)) | x <- rs, y <- rs        ]
                      ++ [("-",  show x, show y, mkThm2 (-)   x y (x -  y)) | x <- rs, y <- rs        ]
                      ++ [("*",  show x, show y, mkThm2 (*)   x y (x *  y)) | x <- rs, y <- rs        ]
                      ++ [("/",  show x, show y, mkThm2 (/)   x y (x /  y)) | x <- rs, y <- rs, y /= 0]
                      ++ [("<",  show x, show y, mkThm2 (.<)  x y (x <  y)) | x <- rs, y <- rs        ]
                      ++ [("<=", show x, show y, mkThm2 (.<=) x y (x <= y)) | x <- rs, y <- rs        ]
                      ++ [(">",  show x, show y, mkThm2 (.>)  x y (x >  y)) | x <- rs, y <- rs        ]
                      ++ [(">=", show x, show y, mkThm2 (.>=) x y (x >= y)) | x <- rs, y <- rs        ]
                      ++ [("==", show x, show y, mkThm2 (.==) x y (x == y)) | x <- rs, y <- rs        ]
                      ++ [("/=", show x, show y, mkThm2 (./=) x y (x /= y)) | x <- rs, y <- rs        ]
  where mkTest (nm, x, y, t) = testCase ("genReals.arithmetic-" ++ nm ++ "." ++ x ++ "_" ++ y) (assert t)
        mkThm2 op x y r = isTheorem $ do [a, b] <- mapM free ["x", "y"]
                                         constrain $ a .== literal x
                                         constrain $ b .== literal y
                                         return $ literal r .== a `op` b

genFloats :: [TestTree]
genFloats = genIEEE754 "genFloats" fs

genDoubles :: [TestTree]
genDoubles = genIEEE754 "genDoubles" ds

genIEEE754 :: (IEEEFloating a, Show a) => String -> [a] -> [TestTree]
genIEEE754 origin vs =  map tst1 [("pred_"   ++ nm, x, y)    | (nm, x, y)    <- preds]
                     ++ map tst1 [("unary_"  ++ nm, x, y)    | (nm, x, y)    <- uns]
                     ++ map tst2 [("binary_" ++ nm, x, y, r) | (nm, x, y, r) <- bins]
  where uns =     [("abs",               show x, mkThm1 abs                   x  (abs x))                | x <- vs]
               ++ [("negate",            show x, mkThm1 negate                x  (negate x))             | x <- vs]
               ++ [("signum",            show x, mkThm1 signum                x  (signum x))             | x <- vs]
               ++ [("fpAbs",             show x, mkThm1 fpAbs                 x  (abs x))                | x <- vs]
               ++ [("fpNeg",             show x, mkThm1 fpNeg                 x  (negate x))             | x <- vs]
               ++ [("fpSqrt",            show x, mkThm1 (m fpSqrt)            x  (sqrt   x))             | x <- vs]
               ++ [("fpRoundToIntegral", show x, mkThm1 (m fpRoundToIntegral) x  (fpRoundToIntegralH x)) | x <- vs]

        bins =    [("+",      show x,  show y, mkThm2        (+)       x y (x +  y))   | x <- vs, y <- vs]
               ++ [("-",      show x,  show y, mkThm2        (-)       x y (x -  y))   | x <- vs, y <- vs]
               ++ [("*",      show x,  show y, mkThm2        (*)       x y (x *  y))   | x <- vs, y <- vs]
               ++ [("/",      show x,  show y, mkThm2        (/)       x y (x /  y))   | x <- vs, y <- vs]
               ++ [("<",      show x,  show y, mkThm2C False (.<)      x y (x <  y))   | x <- vs, y <- vs]
               ++ [("<=",     show x,  show y, mkThm2C False (.<=)     x y (x <= y))   | x <- vs, y <- vs]
               ++ [(">",      show x,  show y, mkThm2C False (.>)      x y (x >  y))   | x <- vs, y <- vs]
               ++ [(">=",     show x,  show y, mkThm2C False (.>=)     x y (x >= y))   | x <- vs, y <- vs]
               ++ [("==",     show x,  show y, mkThm2C False (.==)     x y (x == y))   | x <- vs, y <- vs]
               ++ [("/=",     show x,  show y, mkThm2C True  (./=)     x y (x /= y))   | x <- vs, y <- vs]
               -- TODO. Can't possibly test fma, unless we FFI out to C. Leave it out for the time being
               ++ [("fpAdd",           show x, show y, mkThm2  (m fpAdd)        x y ((+)              x y)) | x <- vs, y <- vs]
               ++ [("fpSub",           show x, show y, mkThm2  (m fpSub)        x y ((-)              x y)) | x <- vs, y <- vs]
               ++ [("fpMul",           show x, show y, mkThm2  (m fpMul)        x y ((*)              x y)) | x <- vs, y <- vs]
               ++ [("fpDiv",           show x, show y, mkThm2  (m fpDiv)        x y ((/)              x y)) | x <- vs, y <- vs]
               ++ [("fpMin",           show x, show y, mkThm2  fpMin            x y (fpMinH           x y)) | x <- vs, y <- vs, not (alt0 x y || alt0 y x)]
               ++ [("fpMax",           show x, show y, mkThm2  fpMax            x y (fpMaxH           x y)) | x <- vs, y <- vs, not (alt0 x y || alt0 y x)]
               ++ [("fpIsEqualObject", show x, show y, mkThm2P fpIsEqualObject  x y (fpIsEqualObjectH x y)) | x <- vs, y <- vs]
               ++ [("fpRem",           show x, show y, mkThm2  fpRem            x y (fpRemH           x y)) | x <- vsFPRem, y <- vsFPRem]

        -- TODO: For doubles fpRem takes too long, so we only do a subset
        vsFPRem
          | origin == "genDoubles" = [nan, infinity, 0, 0.5, -infinity, -0, -0.5]
          | True                   = vs

        -- fpMin/fpMax: skip +0/-0 case as this is underspecified
        alt0 x y = isNegativeZero x && y == 0 && not (isNegativeZero y)

        m f = f sRNE

        preds =   [(pn, show x, mkThmP ps x (pc x)) | (pn, ps, pc) <- predicates, x <- vs]
        tst2 (nm, x, y, t) = testCase (origin ++ ".arithmetic-" ++ nm ++ "." ++ x ++ "_" ++ y) (assert t)
        tst1 (nm, x,    t) = testCase (origin ++ ".arithmetic-" ++ nm ++ "." ++ x) (assert t)

        eqF v val
          | isNaN          val        = constrain $ fpIsNaN v
          | isNegativeZero val        = constrain $ fpIsNegativeZero v
          | val == 0                  = constrain $ fpIsPositiveZero v
          | isInfinite val && val > 0 = constrain $ fpIsInfinite v &&& fpIsPositive v
          | isInfinite val && val < 0 = constrain $ fpIsInfinite v &&& fpIsNegative v
          | True                      = constrain $ v .== literal val

        -- Quickly pick which solver to use. Currently z3 or mathSAT supports FP
        fpProver :: SMTConfig
        fpProver = z3 -- mathSAT

        fpThm :: Provable a => a -> IO Bool
        fpThm = isTheoremWith fpProver

        mkThmP op x r = fpThm $ do a <- free "x"
                                   eqF a x
                                   return $ literal r .== op a

        mkThm2P op x y r = fpThm $ do [a, b] <- mapM free ["x", "y"]
                                      eqF a x
                                      eqF b y
                                      return $ literal r .== a `op` b

        mkThm1 op x r = fpThm $ do a <- free "x"
                                   eqF a x
                                   return $ literal r `fpIsEqualObject` op a

        mkThm2 op x y r = fpThm $ do [a, b] <- mapM free ["x", "y"]
                                     eqF a x
                                     eqF b y
                                     return $ literal r `fpIsEqualObject` (a `op` b)

        mkThm2C neq op x y r = fpThm $ do [a, b] <- mapM free ["x", "y"]
                                          eqF a x
                                          eqF b y
                                          return $ if isNaN x || isNaN y
                                                   then (if neq then a `op` b else bnot (a `op` b))
                                                   else literal r .== a `op` b

        predicates :: (IEEEFloating a) => [(String, SBV a -> SBool, a -> Bool)]
        predicates = [ ("fpIsNormal",       fpIsNormal,        fpIsNormalizedH)
                     , ("fpIsSubnormal",    fpIsSubnormal,     isDenormalized)
                     , ("fpIsZero",         fpIsZero,          (== 0))
                     , ("fpIsInfinite",     fpIsInfinite,      isInfinite)
                     , ("fpIsNaN",          fpIsNaN,           isNaN)
                     , ("fpIsNegative",     fpIsNegative,      \x -> x < 0  ||      isNegativeZero x)
                     , ("fpIsPositive",     fpIsPositive,      \x -> x >= 0 && not (isNegativeZero x))
                     , ("fpIsNegativeZero", fpIsNegativeZero,  isNegativeZero)
                     , ("fpIsPositiveZero", fpIsPositiveZero,  \x -> x == 0 && not (isNegativeZero x))
                     , ("fpIsPoint",        fpIsPoint,         \x -> not (isNaN x || isInfinite x))
                     ]

genFPConverts :: [TestTree]
genFPConverts = map tst1 [("fpCast_" ++ nm, x, y) | (nm, x, y) <- converts]
  where converts =   [("toFP_Int8_ToFloat",     show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- i8s ]
                 ++  [("toFP_Int16_ToFloat",    show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- i16s]
                 ++  [("toFP_Int32_ToFloat",    show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- i32s]
                 ++  [("toFP_Int64_ToFloat",    show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- i64s]
                 ++  [("toFP_Word8_ToFloat",    show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- w8s ]
                 ++  [("toFP_Word16_ToFloat",   show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- w16s]
                 ++  [("toFP_Word32_ToFloat",   show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- w32s]
                 ++  [("toFP_Word64_ToFloat",   show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- w64s]
                 ++  [("toFP_Float_ToFloat",    show x, mkThm1 (m toSFloat) x                           x  ) | x <- fs  ]
                 ++  [("toFP_Double_ToFloat",   show x, mkThm1 (m toSFloat) x (                   fp2fp x )) | x <- ds  ]
                 ++  [("toFP_Integer_ToFloat",  show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- iUBs]
                 ++  [("toFP_Real_ToFloat",     show x, mkThmC (m toSFloat) x (fromRational (toRational x))) | x <- rs  ]

                 ++  [("toFP_Int8_ToDouble",    show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- i8s ]
                 ++  [("toFP_Int16_ToDouble",   show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- i16s]
                 ++  [("toFP_Int32_ToDouble",   show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- i32s]
                 ++  [("toFP_Int64_ToDouble",   show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- i64s]
                 ++  [("toFP_Word8_ToDouble",   show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- w8s ]
                 ++  [("toFP_Word16_ToDouble",  show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- w16s]
                 ++  [("toFP_Word32_ToDouble",  show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- w32s]
                 ++  [("toFP_Word64_ToDouble",  show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- w64s]
                 ++  [("toFP_Float_ToDouble",   show x, mkThm1 (m toSDouble) x (                   fp2fp x )) | x <- fs  ]
                 ++  [("toFP_Double_ToDouble",  show x, mkThm1 (m toSDouble) x                           x )  | x <- ds  ]
                 ++  [("toFP_Integer_ToDouble", show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- iUBs]
                 ++  [("toFP_Real_ToDouble",    show x, mkThmC (m toSDouble) x (fromRational (toRational x))) | x <- rs  ]

                 ++  [("fromFP_Float_ToInt8",    show x, mkThmC' (m fromSFloat :: SFloat -> SInt8)    x (((fromIntegral :: Integer -> Int8)    . fpRound0) x)) | x <- fs]
                 ++  [("fromFP_Float_ToInt16",   show x, mkThmC' (m fromSFloat :: SFloat -> SInt16)   x (((fromIntegral :: Integer -> Int16)   . fpRound0) x)) | x <- fs]
                 ++  [("fromFP_Float_ToInt32",   show x, mkThmC' (m fromSFloat :: SFloat -> SInt32)   x (((fromIntegral :: Integer -> Int32)   . fpRound0) x)) | x <- fs]
                 ++  [("fromFP_Float_ToInt64",   show x, mkThmC' (m fromSFloat :: SFloat -> SInt64)   x (((fromIntegral :: Integer -> Int64)   . fpRound0) x)) | x <- fs]
                 ++  [("fromFP_Float_ToWord8",   show x, mkThmC' (m fromSFloat :: SFloat -> SWord8)   x (((fromIntegral :: Integer -> Word8)   . fpRound0) x)) | x <- fs]
                 ++  [("fromFP_Float_ToWord16",  show x, mkThmC' (m fromSFloat :: SFloat -> SWord16)  x (((fromIntegral :: Integer -> Word16)  . fpRound0) x)) | x <- fs]
                 ++  [("fromFP_Float_ToWord32",  show x, mkThmC' (m fromSFloat :: SFloat -> SWord32)  x (((fromIntegral :: Integer -> Word32)  . fpRound0) x)) | x <- fs]
                 ++  [("fromFP_Float_ToWord64",  show x, mkThmC' (m fromSFloat :: SFloat -> SWord64)  x (((fromIntegral :: Integer -> Word64)  . fpRound0) x)) | x <- fs]
                 ++  [("fromFP_Float_ToFloat",   show x, mkThm1  (m fromSFloat :: SFloat -> SFloat)   x                                                    x ) | x <- fs]
                 ++  [("fromFP_Float_ToDouble",  show x, mkThm1  (m fromSFloat :: SFloat -> SDouble)  x (                                           fp2fp  x)) | x <- fs]
                 -- Neither Z3 nor MathSAT support Float->Integer/Float->Real conversion for the time being; so comment out.
                 -- See GitHub issue: #191
                 -- ++  [("fromFP_Float_ToInteger", show x, mkThmC' (m fromSFloat :: SFloat -> SInteger) x (((fromIntegral :: Integer -> Integer) . fpRound0) x)) | x <- fs]
                 -- ++  [("fromFP_Float_ToReal",    show x, mkThmC' (m fromSFloat :: SFloat -> SReal)    x (                        (fromRational . fpRatio0) x)) | x <- fs]

                 ++  [("fromFP_Double_ToInt8",    show x, mkThmC' (m fromSDouble :: SDouble -> SInt8)    x (((fromIntegral :: Integer -> Int8)    . fpRound0) x)) | x <- ds]
                 ++  [("fromFP_Double_ToInt16",   show x, mkThmC' (m fromSDouble :: SDouble -> SInt16)   x (((fromIntegral :: Integer -> Int16)   . fpRound0) x)) | x <- ds]
                 ++  [("fromFP_Double_ToInt32",   show x, mkThmC' (m fromSDouble :: SDouble -> SInt32)   x (((fromIntegral :: Integer -> Int32)   . fpRound0) x)) | x <- ds]
                 ++  [("fromFP_Double_ToInt64",   show x, mkThmC' (m fromSDouble :: SDouble -> SInt64)   x (((fromIntegral :: Integer -> Int64)   . fpRound0) x)) | x <- ds]
                 ++  [("fromFP_Double_ToWord8",   show x, mkThmC' (m fromSDouble :: SDouble -> SWord8)   x (((fromIntegral :: Integer -> Word8)   . fpRound0) x)) | x <- ds]
                 ++  [("fromFP_Double_ToWord16",  show x, mkThmC' (m fromSDouble :: SDouble -> SWord16)  x (((fromIntegral :: Integer -> Word16)  . fpRound0) x)) | x <- ds]
                 ++  [("fromFP_Double_ToWord32",  show x, mkThmC' (m fromSDouble :: SDouble -> SWord32)  x (((fromIntegral :: Integer -> Word32)  . fpRound0) x)) | x <- ds]
                 ++  [("fromFP_Double_ToWord64",  show x, mkThmC' (m fromSDouble :: SDouble -> SWord64)  x (((fromIntegral :: Integer -> Word64)  . fpRound0) x)) | x <- ds]
                 ++  [("fromFP_Double_ToFloat",   show x, mkThm1  (m fromSDouble :: SDouble -> SFloat)   x (                                            fp2fp x)) | x <- ds]
                 ++  [("fromFP_Double_ToDouble",  show x, mkThm1  (m fromSDouble :: SDouble -> SDouble)  x                                                    x ) | x <- ds]
                 -- Neither Z3 nor MathSAT support Float->Integer/Float->Real conversion for the time being; so comment out.
                 -- See GitHub issue: #191
                 -- ++  [("fromFP_Double_ToInteger", show x, mkThmC' (m fromSDouble :: SDouble -> SInteger) x (((fromIntegral :: Integer -> Integer) . fpRound0) x)) | x <- ds]
                 -- ++  [("fromFP_Double_ToReal",    show x, mkThmC' (m fromSDouble :: SDouble -> SReal)    x (                        (fromRational . fpRatio0) x)) | x <- ds]

                 ++  [("reinterp_Word32_Float",  show x, mkThmC sWord32AsSFloat  x (DB.wordToFloat  x)) | x <- w32s]
                 ++  [("reinterp_Word64_Double", show x, mkThmC sWord64AsSDouble x (DB.wordToDouble x)) | x <- w64s]

                 ++  [("reinterp_Float_Word32",  show x, mkThmP sFloatAsSWord32  x (DB.floatToWord x))  | x <- fs, not (isNaN x)] -- Not unique for NaN
                 ++  [("reinterp_Double_Word64", show x, mkThmP sDoubleAsSWord64 x (DB.doubleToWord x)) | x <- ds, not (isNaN x)] -- Not unique for NaN

        m f = f sRNE

        tst1 (nm, x, t) = testCase ("fpConverts.arithmetic-" ++ nm ++ "." ++ x) (assert t)

        eqF v val
          | isNaN          val        = constrain $ fpIsNaN v
          | isNegativeZero val        = constrain $ fpIsNegativeZero v
          | val == 0                  = constrain $ fpIsPositiveZero v
          | isInfinite val && val > 0 = constrain $ fpIsInfinite v &&& fpIsPositive v
          | isInfinite val && val < 0 = constrain $ fpIsInfinite v &&& fpIsNegative v
          | True                      = constrain $ v .== literal val

        -- Quickly pick which solver to use. Currently z3 or mathSAT supports FP
        fpProver :: SMTConfig
        fpProver = z3 -- mathSAT

        fpThm :: Provable a => a -> IO Bool
        fpThm = isTheoremWith fpProver

        mkThmP op x r = fpThm $ do a <- free "x"
                                   eqF a x
                                   return $ literal r .== op a

        mkThm1 op x r = fpThm $ do a <- free "x"
                                   eqF a x
                                   return $ literal r `fpIsEqualObject` op a

        mkThmC op x r = fpThm $ do a <- free "x"
                                   constrain $ a .== literal x
                                   return $ literal r `fpIsEqualObject` op a

        mkThmC' op x r = fpThm $ do a <- free "x"
                                    eqF a x
                                    return $ literal r .== op a

genQRems :: [TestTree]
genQRems = map mkTest $  [("divMod",  show x, show y, mkThm2 sDivMod  x y (x `divMod'`  y)) | x <- w8s,  y <- w8s ]
                      ++ [("divMod",  show x, show y, mkThm2 sDivMod  x y (x `divMod'`  y)) | x <- w16s, y <- w16s]
                      ++ [("divMod",  show x, show y, mkThm2 sDivMod  x y (x `divMod'`  y)) | x <- w32s, y <- w32s]
                      ++ [("divMod",  show x, show y, mkThm2 sDivMod  x y (x `divMod'`  y)) | x <- w64s, y <- w64s]
                      ++ [("divMod",  show x, show y, mkThm2 sDivMod  x y (x `divMod'`  y)) | x <- i8s,  y <- i8s , noOverflow x y]
                      ++ [("divMod",  show x, show y, mkThm2 sDivMod  x y (x `divMod'`  y)) | x <- i16s, y <- i16s, noOverflow x y]
                      ++ [("divMod",  show x, show y, mkThm2 sDivMod  x y (x `divMod'`  y)) | x <- i32s, y <- i32s, noOverflow x y]
                      ++ [("divMod",  show x, show y, mkThm2 sDivMod  x y (x `divMod'`  y)) | x <- i64s, y <- i64s, noOverflow x y]
                      ++ [("divMod",  show x, show y, mkThm2 sDivMod  x y (x `divMod'`  y)) | x <- iUBs, y <- iUBs]
                      ++ [("quotRem", show x, show y, mkThm2 sQuotRem x y (x `quotRem'` y)) | x <- w8s,  y <- w8s ]
                      ++ [("quotRem", show x, show y, mkThm2 sQuotRem x y (x `quotRem'` y)) | x <- w16s, y <- w16s]
                      ++ [("quotRem", show x, show y, mkThm2 sQuotRem x y (x `quotRem'` y)) | x <- w32s, y <- w32s]
                      ++ [("quotRem", show x, show y, mkThm2 sQuotRem x y (x `quotRem'` y)) | x <- w64s, y <- w64s]
                      ++ [("quotRem", show x, show y, mkThm2 sQuotRem x y (x `quotRem'` y)) | x <- i8s,  y <- i8s , noOverflow x y]
                      ++ [("quotRem", show x, show y, mkThm2 sQuotRem x y (x `quotRem'` y)) | x <- i16s, y <- i16s, noOverflow x y]
                      ++ [("quotRem", show x, show y, mkThm2 sQuotRem x y (x `quotRem'` y)) | x <- i32s, y <- i32s, noOverflow x y]
                      ++ [("quotRem", show x, show y, mkThm2 sQuotRem x y (x `quotRem'` y)) | x <- i64s, y <- i64s, noOverflow x y]
                      ++ [("quotRem", show x, show y, mkThm2 sQuotRem x y (x `quotRem'` y)) | x <- iUBs, y <- iUBs]
  where divMod'  x y = if y == 0 then (0, x) else x `divMod`  y
        quotRem' x y = if y == 0 then (0, x) else x `quotRem` y
        mkTest (nm, x, y, t) = testCase ("genQRems.arithmetic-" ++ nm ++ "." ++ x ++ "_" ++ y) (assert t)
        mkThm2 op x y (e1, e2) = isTheorem $ do [a, b] <- mapM free ["x", "y"]
                                                constrain $ a .== literal x
                                                constrain $ b .== literal y
                                                return $ (literal e1, literal e2) .== a `op` b
        -- Haskell's divMod and quotRem overflows if x == minBound and y == -1 for signed types; so avoid that case
        noOverflow x y = not (x == minBound && y == -1)

genChars :: [TestTree]
genChars = map mkTest $  [("ord",           show c, mkThm SC.ord           cord            c) | c <- cs]
                      ++ [("toLower",       show c, mkThm SC.toLower       C.toLower       c) | c <- cs]
                      ++ [("toUpper",       show c, mkThm SC.toUpper       C.toUpper       c) | c <- cs, toUpperExceptions c]
                      ++ [("digitToInt",    show c, mkThm SC.digitToInt    dig2Int         c) | c <- cs, digitToIntRange c]
                      ++ [("intToDigit",    show c, mkThm SC.intToDigit    int2Dig         c) | c <- [0 .. 15]]
                      ++ [("isControl",     show c, mkThm SC.isControl     C.isControl     c) | c <- cs]
                      ++ [("isSpace",       show c, mkThm SC.isSpace       C.isSpace       c) | c <- cs]
                      ++ [("isLower",       show c, mkThm SC.isLower       C.isLower       c) | c <- cs]
                      ++ [("isUpper",       show c, mkThm SC.isUpper       C.isUpper       c) | c <- cs]
                      ++ [("isAlpha",       show c, mkThm SC.isAlpha       C.isAlpha       c) | c <- cs]
                      ++ [("isAlphaNum",    show c, mkThm SC.isAlphaNum    C.isAlphaNum    c) | c <- cs]
                      ++ [("isPrint",       show c, mkThm SC.isPrint       C.isPrint       c) | c <- cs]
                      ++ [("isDigit",       show c, mkThm SC.isDigit       C.isDigit       c) | c <- cs]
                      ++ [("isOctDigit",    show c, mkThm SC.isOctDigit    C.isOctDigit    c) | c <- cs]
                      ++ [("isHexDigit",    show c, mkThm SC.isHexDigit    C.isHexDigit    c) | c <- cs]
                      ++ [("isLetter",      show c, mkThm SC.isLetter      C.isLetter      c) | c <- cs]
                      ++ [("isMark",        show c, mkThm SC.isMark        C.isMark        c) | c <- cs]
                      ++ [("isNumber",      show c, mkThm SC.isNumber      C.isNumber      c) | c <- cs]
                      ++ [("isPunctuation", show c, mkThm SC.isPunctuation C.isPunctuation c) | c <- cs]
                      ++ [("isSymbol",      show c, mkThm SC.isSymbol      C.isSymbol      c) | c <- cs]
                      ++ [("isSeparator",   show c, mkThm SC.isSeparator   C.isSeparator   c) | c <- cs]
                      ++ [("isAscii",       show c, mkThm SC.isAscii       C.isAscii       c) | c <- cs]
                      ++ [("isLatin1",      show c, mkThm SC.isLatin1      C.isLatin1      c) | c <- cs]
                      ++ [("isAsciiUpper",  show c, mkThm SC.isAsciiUpper  C.isAsciiUpper  c) | c <- cs]
                      ++ [("isAsciiLower",  show c, mkThm SC.isAsciiLower  C.isAsciiLower  c) | c <- cs]
  where toUpperExceptions = (`notElem` "\181\255")
        digitToIntRange   = (`elem` "0123456789abcdefABCDEF")
        cord :: Char -> Integer
        cord = fromIntegral . C.ord
        dig2Int :: Char -> Integer
        dig2Int = fromIntegral . C.digitToInt
        int2Dig :: Integer -> Char
        int2Dig = C.intToDigit . fromIntegral
        mkTest (nm, x, t) = testCase ("genChars-" ++ nm ++ "." ++ x) (assert t)
        mkThm sop cop arg = isTheorem $ do a <- free "a"
                                           constrain $ a .== literal arg
                                           return $ literal (cop arg) .== sop a

genStrings :: [TestTree]
genStrings = map mkTest1 (  [("length",        show s,                   mkThm1 SS.length        strLen        s      ) | s <- ss                                                       ]
                         ++ [("null",          show s,                   mkThm1 SS.null          null          s      ) | s <- ss                                                       ]
                         ++ [("head",          show s,                   mkThm1 SS.head          head          s      ) | s <- ss, not (null s)                                         ]
                         ++ [("tail",          show s,                   mkThm1 SS.tail          tail          s      ) | s <- ss, not (null s)                                         ]
                         ++ [("charToStr",     show c,                   mkThm1 SS.charToStr     (: [])        c      ) | c <- cs                                                       ]
                         ++ [("implode",       show s,                   mkThmI SS.implode                     s      ) | s <- ss                                                       ]
                         ++ [("strToNat",      show s,                   mkThm1 SS.strToNat      strToNat      s      ) | s <- ss                                                       ]
                         ++ [("natToStr",      show i,                   mkThm1 SS.natToStr      natToStr      i      ) | i <- iUBs                                                     ])
          ++ map mkTest2 (  [("strToStrAt",    show s, show i,           mkThm2 SS.strToStrAt    strToStrAt    s i    ) | s <- ss, i  <- range s                                        ]
                         ++ [("strToCharAt",   show s, show i,           mkThm2 SS.strToCharAt   strToCharAt   s i    ) | s <- ss, i  <- range s                                        ]
                         ++ [("concat",        show s, show s1,          mkThm2 SS.concat        (++)          s s1   ) | s <- ss, s1 <- ss                                             ]
                         ++ [("isInfixOf",     show s, show s1,          mkThm2 SS.isInfixOf     isInfixOf     s s1   ) | s <- ss, s1 <- ss                                             ]
                         ++ [("isSuffixOf",    show s, show s1,          mkThm2 SS.isSuffixOf    isSuffixOf    s s1   ) | s <- ss, s1 <- ss                                             ]
                         ++ [("isPrefixOf",    show s, show s1,          mkThm2 SS.isPrefixOf    isPrefixOf    s s1   ) | s <- ss, s1 <- ss                                             ]
                         ++ [("take",          show s, show i,           mkThm2 SS.take          genericTake   i s    ) | s <- ss, i <- iUBs                                            ]
                         ++ [("drop",          show s, show i,           mkThm2 SS.drop          genericDrop   i s    ) | s <- ss, i <- iUBs                                            ]
                         ++ [("indexOf",       show s, show s1,          mkThm2 SS.indexOf       indexOf       s s1   ) | s <- ss, s1 <- ss                                             ])
          ++ map mkTest3 (  [("subStr",        show s, show  i, show j,  mkThm3 SS.subStr        subStr        s i  j ) | s <- ss, i  <- range s, j <- range s, i + j <= genericLength s]
                         ++ [("replace",       show s, show s1, show s2, mkThm3 SS.replace       replace       s s1 s2) | s <- ss, s1 <- ss, s2 <- ss                                   ]
                         ++ [("offsetIndexOf", show s, show s1, show i,  mkThm3 SS.offsetIndexOf offsetIndexOf s s1 i ) | s <- ss, s1 <- ss, i <- range s                               ])
  where strLen :: String -> Integer
        strLen = fromIntegral . length

        strToNat :: String -> Integer
        strToNat s
          | all C.isDigit s && not (null s) = read s
          | True                            = -1

        natToStr :: Integer -> String
        natToStr i
          | i >= 0 = show i
          | True   = ""

        range :: String -> [Integer]
        range s = map fromIntegral [0 .. length s - 1]

        indexOf :: String -> String -> Integer
        indexOf s1 s2 = go 0 s1
          where go i x
                 | s2 `isPrefixOf` x = i
                 | True              = case x of
                                          "" -> -1
                                          (_:r) -> go (i+1) r

        strToStrAt :: String -> Integer -> String
        s `strToStrAt` i = [s `strToCharAt` i]

        strToCharAt :: String -> Integer -> Char
        s `strToCharAt` i = s `genericIndex` i

        subStr :: String -> Integer -> Integer -> String
        subStr s i j = genericTake j (genericDrop i s)

        replace :: String -> String -> String -> String
        replace s x y = go s
          where go "" = ""
                go h@(c:rest) | x `isPrefixOf` h = y ++ drop (length x) h
                              | True             = c : go rest

        offsetIndexOf :: String -> String -> Integer -> Integer
        offsetIndexOf x y i = case indexOf (genericDrop i x) y of
                                -1 -> -1
                                r  -> r+i

        mkTest1 (nm, x, t)       = testCase ("genStrings-" ++ nm ++ "." ++ x)                         (assert t)
        mkTest2 (nm, x, y, t)    = testCase ("genStrings-" ++ nm ++ "." ++ x ++ "_" ++ y)             (assert t)
        mkTest3 (nm, x, y, z, t) = testCase ("genStrings-" ++ nm ++ "." ++ x ++ "_" ++ y ++ "_" ++ z) (assert t)

        mkThmI sop s = isTheorem $ do let v c = do sc <- free_
                                                   constrain $ sc .== literal c
                                                   return sc
                                      vs <- mapM v s
                                      return $ literal s .== sop vs

        mkThm1 sop cop arg            = isTheorem $ do a <- free "a"
                                                       constrain $ a .== literal arg
                                                       return $ literal (cop arg) .== sop a
        mkThm2 sop cop arg1 arg2      = isTheorem $ do a <- free "a"
                                                       b <- free "b"
                                                       constrain $ a .== literal arg1
                                                       constrain $ b .== literal arg2
                                                       return $ literal (cop arg1 arg2) .== sop a b
        mkThm3 sop cop arg1 arg2 arg3 = isTheorem $ do a <- free "a"
                                                       b <- free "b"
                                                       c <- free "c"
                                                       constrain $ a .== literal arg1
                                                       constrain $ b .== literal arg2
                                                       constrain $ c .== literal arg3
                                                       return $ literal (cop arg1 arg2 arg3) .== sop a b c

-- Concrete test data
xsSigned, xsUnsigned :: (Num a, Bounded a) => [a]
xsUnsigned = [0, 1, maxBound - 1, maxBound]
xsSigned   = xsUnsigned ++ [minBound, minBound + 1, -1]

w8s :: [Word8]
w8s = xsUnsigned

w16s :: [Word16]
w16s = xsUnsigned

w32s :: [Word32]
w32s = xsUnsigned

w64s :: [Word64]
w64s = xsUnsigned

i8s :: [Int8]
i8s = xsSigned

i16s :: [Int16]
i16s = xsSigned

i32s :: [Int32]
i32s = xsSigned

i64s :: [Int64]
i64s = xsSigned

iUBs :: [Integer]
iUBs = [-1000000] ++ [-1 .. 1] ++ [1000000]

rs :: [AlgReal]
rs = [fromRational (i % d) | i <- is, d <- dens]
 where is   = [-1000000] ++ [-1 .. 1] ++ [10000001]
       dens = [5,100,1000000]

-- Admittedly paltry test-cases for float/double
fs :: [Float]
fs = xs ++ map (* (-1)) (filter (not . isNaN) xs) -- -nan is the same as nan
   where xs = [nan, infinity, 0, 0.5, 0.68302244, 0.5268265, 0.10283524, 5.8336496e-2, 1.0e-45]

ds :: [Double]
ds = xs ++ map (* (-1)) (filter (not . isNaN) xs) -- -nan is the same as nan
  where xs = [nan, infinity, 0, 0.5, 2.516632060108026e-2, 0.8601891300751106, 5.0e-324]

-- Currently we test over all latin-1 characters. But when Unicode comes along, we'll have to be more selective.
-- TODO: Unicode update here.
cs :: String
cs = map C.chr [0..255]

-- For pair char ops, take a subset.
reducedCS :: String
reducedCS = map C.chr $ [0..5] ++ [98..102] ++ [250..255]

-- Ditto for strings, just a few things
ss :: [String]
ss = ["", "palTRY", "teSTing", "SBV", "sTRIngs", "123", "surely", "thIS", "hI", "ly", "0"]

{-# ANN module ("HLint: ignore Reduce duplication" :: String) #-}
