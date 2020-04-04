module Rpd.Test.Spec.FSM
    ( spec ) where

import Prelude

import Effect.Class (liftEffect)
import Effect.Ref (Ref)
import Effect.Ref as Ref

import Data.List as List
import Data.List ((:))
import Data.Maybe
import Data.Tuple.Nested ((/\))

import Rpd.UUID (UUID)
import Rpd.UUID as UUID

import Test.Spec (Spec, describe, it, pending', itOnly, describeOnly, pending)
import Test.Spec.Assertions (shouldEqual, fail)

import FSM as FSM

data Error
  = ErrorOne
  | ErrorTwo


data Model
  = Empty
  | HoldsString String
  | HoldsAction Action
  | HoldsUUID UUID


emptyModel :: Model
emptyModel = Empty


data Action
  = NoOp
  | ActionOne
  | StoreUUID UUID


spec :: Spec Unit
spec = do

  describeOnly "FSM" do

    describe "creating" do

      it "is easy to create" do
        let fsm = FSM.make unit (\_ _ -> unit /\ [])
        pure unit

      it "is easy to run" do
        let fsm = FSM.make unit (\_ _ -> unit /\ [])
        _ <- liftEffect $ FSM.run fsm List.Nil
        pure unit

      it "is easy to run with some actions" do
        let fsm = FSM.make unit (\_ _ -> unit /\ [])
        _ <- liftEffect $ FSM.run fsm $ List.singleton NoOp
        pure unit

    describe "updating" do

      it "calls the update function" do
        let
          myFsm = FSM.make emptyModel (\_ _ -> HoldsString "foo" /\ [])
        lastModel <- liftEffect $ do
          ref <- Ref.new Empty
          _ <- FSM.runAndSubscribe myFsm (flip Ref.write ref)
                  $ List.singleton NoOp
          Ref.read ref
        lastModel `shouldEqual` (HoldsString "foo")

      it "the action is actually sent" do
        let
          myFsm = FSM.make emptyModel (\action _ -> HoldsAction action /\ [])
        lastModel <- liftEffect $ do
          ref <- Ref.new Empty
          _ <- FSM.runAndSubscribe myFsm (flip Ref.write ref)
                  $ List.singleton ActionOne
          Ref.read ref
        lastModel `shouldEqual` (HoldsAction ActionOne)

      it "receives all the actions which were sent" do
        let
          myFsm = FSM.make emptyModel (\action _ -> HoldsAction action /\ [])
        lastModel <- liftEffect $ do
          ref <- Ref.new Empty
          _ <- FSM.runAndSubscribe myFsm (flip Ref.write ref)
                  $ (ActionOne : NoOp : List.Nil)
          Ref.read ref
        lastModel `shouldEqual` (HoldsAction NoOp)

    describe "effects" do

      it "performs the effect from the update function" do
        let
          updateF NoOp model = model /\ [ UUID.new >>= pure <<< StoreUUID ]
          updateF (StoreUUID uuid) _ = HoldsUUID uuid /\ []
          updateF _ model = model /\ []
          myFsm = FSM.make emptyModel updateF
        lastModel <- liftEffect $ do
          ref <- Ref.new Empty
          _ <- FSM.runAndSubscribe myFsm (flip Ref.write ref)
                  $ List.singleton NoOp
          Ref.read ref
        case lastModel of
          (HoldsUUID _) -> pure unit
          _ -> fail "should contain UUID in the model"

    describe "folding" do

      it "folds the models to the very last state" do
        let
          updateF NoOp _ = HoldsString "NoOp" /\ [ ]
          updateF ActionOne _ = HoldsString "ActionOne" /\ []
          updateF _ model = model /\ []
          myFsm = FSM.make emptyModel updateF
        (lastModel /\ _) <- liftEffect $ FSM.fold myFsm $ (NoOp : ActionOne : List.Nil)
        lastModel `shouldEqual` HoldsString "ActionOne"

      it "folds the models to the very last state with effects as well" do
        let
          updateF NoOp model = model /\ [ UUID.new >>= pure <<< StoreUUID ]
          updateF (StoreUUID uuid) _ = HoldsUUID uuid /\ []
          updateF _ model = model /\ []
          myFsm = FSM.make emptyModel updateF
        (lastModel /\ _) <- liftEffect $ FSM.fold myFsm $ (NoOp : ActionOne : List.Nil)
        case lastModel of
          (HoldsUUID _) -> pure unit
          _ -> fail "should contain UUID in the model"

    describe "pushing actions" do

      pending "TODO"



instance showAction :: Show Action where
    show NoOp = "NoOp"
    show ActionOne = "ActionOne"
    show (StoreUUID u) = "Store UUID" <> show u


instance showModel :: Show Model where
    show Empty = "Empty"
    show (HoldsString s) = "HoldsString: " <> s
    show (HoldsAction a) = "HoldsAction: " <> show a
    show (HoldsUUID u) = "HoldsUUID: " <> show u


instance eqAction :: Eq Action where
    eq NoOp NoOp = true
    eq ActionOne ActionOne = true
    eq (StoreUUID uuidA) (StoreUUID uuidB) = uuidA == uuidB
    eq _ _ = false


instance eqModel :: Eq Model where
    eq Empty Empty = true
    eq (HoldsString sA) (HoldsString sB) = sA == sB
    eq (HoldsAction aA) (HoldsAction aB) = aA == aB
    eq (HoldsUUID uA) (HoldsUUID uB) = uA == uB
    eq _ _ = false
