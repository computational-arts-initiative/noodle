module RpdTest.Network.Flow
    ( spec ) where

import Prelude

import Data.Generic.Rep (class Generic)
import Data.Generic.Rep.Eq (genericEq)
import Data.Generic.Rep.Show (genericShow)
import Data.Time.Duration (Milliseconds(..))
import Data.Tuple.Nested ((/\), type (/\))
import Data.Map as Map
import Data.List as List
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import FRP.Event.Time (interval)
import Rpd ((</>))
import Rpd as R
import Rpd.Log as RL
import RpdTest.Network.CollectData (TraceItem(..))
import RpdTest.Network.CollectData as CollectData
import Test.Spec (Spec, describe, it, pending, pending')
import Test.Spec.Assertions (shouldEqual, shouldContain, shouldNotContain)


data Delivery
  = Damaged
  | Email
  | Letter
  | Parcel
  | TV
  | IKEAFurniture
  | Car
  | Notebook
  | Curse Int
  | Liver
  | Banana
  | Apple Int
  | Pills

derive instance genericDelivery :: Generic Delivery _

instance showDelivery :: Show Delivery where
  show = genericShow

instance eqDelivery :: Eq Delivery where
  eq = genericEq


type MyRpd = R.Rpd (R.Network Delivery)


producingNothingNode :: R.NodeDef Delivery
producingNothingNode =
  { name : "Nothing"
  , inletDefs : List.Nil
  , outletDefs : List.Nil
  , process : const Map.empty
  }


sumCursesToApplesNode :: R.NodeDef Delivery
sumCursesToApplesNode =
  -- TODO: implement
  { name : "Sum Curses to Apples"
  , inletDefs : List.Nil
  , outletDefs : List.Nil
  , process : const Map.empty
  }


spec :: Spec Unit
spec = do
  describe "data flow is functioning as expected" $ do

    pending "we are able to subscribe some specific inlet in the network"

    pending "we are able to subscribe some specific outlet in the network"

    pending "we are able to subscribe some specific node in the network"

    -- INLETS --

    it "we receive no data from the inlet when it has no flow or default value" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "no-data"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node"
            </> R.addInlet (nodePath 0 0) "inlet"

      rpd # withRpd \nw -> do
              collectedData <- nw #
                CollectData.channels (Milliseconds 100.0)
              collectedData `shouldEqual` []
              pure unit

      pure unit

    pending "we receive the default value of the inlet just when it was set"

    it "we receive the data sent directly to the inlet" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "network"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node"
            </> R.addInlet (nodePath 0 0) "inlet"

      rpd # withRpd \nw -> do
          collectedData <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw
            $ do
              _ <- nw
                    # R.sendToInlet (inletPath 0 0 0) Parcel
                    </> R.sendToInlet (inletPath 0 0 0) Pills
                    </> R.sendToInlet (inletPath 0 0 0) (Curse 5)
              pure []
          collectedData `shouldEqual`
              [ InletData (inletPath 0 0 0) Parcel
              , InletData (inletPath 0 0 0) Pills
              , InletData (inletPath 0 0 0) (Curse 5)
              ]
          pure unit

    it "we receive the values from the data stream attached to the inlet" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "network"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node"
            </> R.addInlet (nodePath 0 0) "inlet"

      rpd # withRpd \nw -> do
          collectedData <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw
            $ do
              cancel :: R.Canceler <-
                nw # R.streamToInlet
                    (inletPath 0 0 0)
                    (R.flow $ const Pills <$> interval 30)
              pure [ cancel ]
          collectedData `shouldContain`
              (InletData (inletPath 0 0 0) Pills)
          pure unit

      pure unit

    pending "it is possible to manually cancel the streaming-to-inlet procedure"

    it "attaching several simultaneous streams to the inlet allows them to overlap" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "network"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node"
            </> R.addInlet (nodePath 0 0) "inlet"

      rpd # withRpd \nw -> do
          collectedData <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw
            $ do
              c1 <- nw # R.streamToInlet
                    (inletPath 0 0 0)
                    (R.flow $ const Pills <$> interval 20)
              c2 <- nw # R.streamToInlet
                    (inletPath 0 0 0)
                    (R.flow $ const Banana <$> interval 29)
              pure [ c1, c2 ]
          collectedData `shouldContain`
            (InletData (inletPath 0 0 0) Pills)
          collectedData `shouldContain`
            (InletData (inletPath 0 0 0) Banana)
          pure unit

      pure unit

    it "when the stream itself was stopped, values are not sent to the inlet anymore" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "network"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node"
            </> R.addInlet (nodePath 0 0) "inlet"

      rpd # withRpd \nw -> do
          collectedData <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw
            $ do
              cancel <- nw # R.streamToInlet
                  (inletPath 0 0 0)
                  (R.flow $ const Pills <$> interval 20)
              pure [ cancel ] -- `cancel` is called by `collectDataAfter`
          collectedData `shouldContain`
            (InletData (inletPath 0 0 0) Pills)
          collectedData' <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw
            $ pure []
          collectedData' `shouldNotContain`
            (InletData (inletPath 0 0 0) Pills)
          pure unit

    it "two different streams may work for different inlets" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "network"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node"
            </> R.addInlet (nodePath 0 0) "inlet1"
            </> R.addInlet (nodePath 0 0) "inlet2"

      rpd # withRpd \nw -> do
          collectedData <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw
            $ do
              c1 <-
                nw # R.streamToInlet
                  (inletPath 0 0 0)
                  (R.flow $ const Pills <$> interval 30)
              c2 <-
                nw # R.streamToInlet
                  (inletPath 0 0 1)
                  (R.flow $ const Banana <$> interval 25)
              pure [ c1, c2 ]
          collectedData `shouldContain`
            (InletData (inletPath 0 0 0) Pills)
          collectedData `shouldContain`
            (InletData (inletPath 0 0 1) Banana)
          pure unit

      pure unit

    it "same stream may produce values for several inlets" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "network"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node"
            </> R.addInlet (nodePath 0 0) "inlet1"
            </> R.addInlet (nodePath 0 0) "inlet2"

      rpd # withRpd \nw -> do
          collectedData <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw
            $ do
              let stream = R.flow $ const Banana <$> interval 25
              c1 <- nw # R.streamToInlet (inletPath 0 0 0) stream
              c2 <- nw # R.streamToInlet (inletPath 0 0 1) stream
              pure [ c1, c2 ]
          collectedData `shouldContain`
            (InletData (inletPath 0 0 0) Banana)
          collectedData `shouldContain`
            (InletData (inletPath 0 0 1) Banana)
          pure unit

      pure unit

    pending "sending data to the inlet triggers the processing function of the node"

    pending "receiving data from the stream triggers the processing function of the node"

    pending "default value of the inlet is sent to its flow when it's added"

    -- OULETS (same as for inlets) --

    -- NODES --

    pending "adding an inlet inludes its flow into processing"

    pending "returning value from processing function actually sends values to the outlet"

    -- LINKS <-> NODES --

    it "connecting some outlet to some inlet makes data flow from this outlet to this inlet" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "network"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node1"
            </> R.addOutlet (nodePath 0 0) "outlet"
            </> R.addNode (patchId 0) "node2"
            </> R.addInlet (nodePath 0 1) "inlet"

      rpd # withRpd \nw -> do
          collectedData <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw
            $ do
              cancel <-
                nw # R.connect (outletPath 0 0 0) (inletPath 0 1 0)
                   </> R.streamToOutlet
                        (outletPath 0 0 0)
                        (R.flow $ const Notebook <$> interval 30)
              pure [ cancel ]
          collectedData `shouldContain`
            (OutletData (outletPath 0 0 0) Notebook)
          collectedData `shouldContain`
            (InletData (inletPath 0 1 0) Notebook)
          pure unit

      pure unit

    it "connecting some outlet having its own flow to some inlet directs this existing flow to this inlet" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "network"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node1"
            </> R.addOutlet (nodePath 0 0) "outlet"
            </> R.addNode (patchId 0) "node2"
            </> R.addInlet (nodePath 0 1) "inlet"

      rpd # withRpd \nw -> do
          collectedData <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw
            $ do
              cancel <-
                nw # R.streamToOutlet
                  (outletPath 0 0 0)
                  (R.flow $ const Notebook <$> interval 30)
              _ <- nw # R.connect
                  (outletPath 0 0 0)
                  (inletPath 0 1 0)
              pure [ cancel ]
          collectedData `shouldContain`
            (OutletData (outletPath 0 0 0) Notebook)
          collectedData `shouldContain`
            (InletData (inletPath 0 1 0) Notebook)
          pure unit

      pure unit

    it "disconnecting some outlet from some inlet makes the data flow between them stop" $ do
      let
        rpd :: MyRpd
        rpd =
          R.init "network"
            </> R.addPatch "patch"
            </> R.addNode (patchId 0) "node1"
            </> R.addOutlet (nodePath 0 0) "outlet"
            </> R.addNode (patchId 0) "node2"
            </> R.addInlet (nodePath 0 1) "inlet"

      rpd # withRpd \nw -> do
          nw' /\ collectedData <- CollectData.channelsAfter'
            (Milliseconds 100.0)
            nw
            $ do
              -- NB:we're not cancelling this data flow between checks
              _ <- nw # R.streamToOutlet
                   (outletPath 0 0 0)
                   (R.flow $ const Notebook <$> interval 30)
              nw' <- nw # R.connect
                   (outletPath 0 0 0)
                   (inletPath 0 1 0)
              pure $ nw' /\ []
          collectedData `shouldContain`
            (InletData (inletPath 0 1 0) Notebook)
          collectedData' <- CollectData.channelsAfter
            (Milliseconds 100.0)
            nw'
            $ do
              _ <-
                nw' # R.disconnectAll (outletPath 0 0 0) (inletPath 0 1 0)
              pure [ ]
          collectedData' `shouldContain`
            (OutletData (outletPath 0 0 0) Notebook)
          collectedData' `shouldNotContain`
            (InletData (inletPath 0 1 0) Notebook)
          pure unit


    pending "default value of the inlet is sent on connection"

    pending "default value for the inlet is sent on disconnection"

    -- NETWORK --

    it "we receive no data from the network when it's empty" $ do
      (R.init "no-data" :: MyRpd)
        # withRpd \nw -> do
            collectedData <- nw #
              CollectData.channels (Milliseconds 100.0)
            collectedData `shouldEqual` []
            pure unit

      pure unit

    pending "all the cancelers are called after running the system"


patchId :: Int -> R.PatchId
patchId = R.PatchId

nodePath :: Int -> Int -> R.NodePath
nodePath = R.NodePath <<< R.PatchId

inletPath :: Int -> Int -> Int -> R.InletPath
inletPath patchId nodeId inletId = R.InletPath (nodePath patchId nodeId) inletId
-- inletPath = R.InletPath ?_ nodePath

outletPath :: Int -> Int -> Int -> R.OutletPath
outletPath patchId nodeId outletId = R.OutletPath (nodePath patchId nodeId) outletId
-- inletPath = R.InletPath ?_ nodePath


withRpd
  :: forall d
   . (R.Network d -> Aff Unit)
  -> R.Rpd (R.Network d)
  -> Aff Unit
withRpd test rpd = do
  nw <- liftEffect $ getNetwork rpd
  test nw
  where
    --getNetwork :: R.Rpd d e -> R.RpdEff e (R.Network d e)
    getNetwork rpd = do
      nwTarget <- Ref.new $ R.emptyNetwork "f"
      _ <- RL.runRpdLogging (flip Ref.write $ nwTarget) rpd
      Ref.read nwTarget


-- logOrExec
--   :: forall a. Either R.RpdError (Effect a) -> Effect a
-- logOrExec effE =
--   either (log <<< show) identity effE
