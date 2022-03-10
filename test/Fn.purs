module Test.Fn where

import Prelude

import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\), type (/\))

import Control.Monad.State (modify_)

import Effect.Class (class MonadEffect, liftEffect)
import Effect.Console as Console

import Test.Spec (Spec, pending, describe, it)
import Test.Spec.Assertions (fail, shouldEqual)
import Test.Signal (expectFn, expect)

-- import Noodle.Node.Shape (noInlets, noOutlets) as Shape
-- import Noodle.Node ((<~>), (+>), (<+))
import Noodle.Node (Node)
import Noodle.Node as Node
import Noodle.Fn (Fn, Fn')
import Noodle.Fn as Fn
import Noodle.Fn.Process as Fn
import Noodle.Fn.Transfer as Fn

import Signal ((~>), Signal)
import Signal as Signal
import Signal.Channel as Ch
import Signal.Time as SignalT


spec :: Spec Unit
spec = do

    describe "foo" $

        it "summing works" $ do
            let
                fn :: forall state m. MonadEffect m => Fn' String String state m Int
                fn =
                    Fn.make' "foo" [ "a", "b" ] [ "sum" ] $ do
                        a <- Fn.receive "a"
                        b <- Fn.receive "b"
                        Fn.send "sum" $ a + b
                logSend outputId val = Console.log $ outputId <> " +> " <> show val
            Fn.run
                (Fn.r [ "a" /\ 0, "b" /\ 0 ])
                (Fn.s logSend)
                0
                unit
                fn

    describe "bar" $ do
        pure unit
