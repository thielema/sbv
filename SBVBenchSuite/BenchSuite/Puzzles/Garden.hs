-----------------------------------------------------------------------------
-- |
-- Module    : BenchSuite.Puzzles.Garden
-- Copyright : (c) Jeffrey Young
--                 Levent Erkok
-- License   : BSD3
-- Maintainer: erkokl@gmail.com
-- Stability : experimental
--
-- Bench suite for Documentation.SBV.Examples.Puzzles.Garden
-----------------------------------------------------------------------------

{-# OPTIONS_GHC -Wall -Werror #-}

module BenchSuite.Puzzles.Garden(benchmarks) where

import Data.List (isSuffixOf)

import Documentation.SBV.Examples.Puzzles.Garden

import Utils.SBVBenchFramework
import BenchSuite.Overhead.SBVOverhead


-- benchmark suite
benchmarks :: Runner 
benchmarks = runnerWith s "Garden" puzzle `using` setRunner allSatWith
  where s = z3{satTrackUFs = False, isNonModelVar = ("_modelIgnore" `isSuffixOf`)}
