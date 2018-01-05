module Main where

import Prelude

import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Data.Array ((:))
import Data.Array as Array
import Data.Map (Map, insert, delete, values)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Signal as S
import Signal.Time as ST
import Data.Function (apply, applyFlipped)

-- Elm-style operators

infixr 0 apply as <|
infixl 1 applyFlipped as |>

-- Signal helpers

-- data Pool i a
--     = Pool
--         (Map i (S.Signal a))
--         (S.Signal a)

-- -- getPoolSignal :: forall i a. Pool i a -> S.Signal a
-- -- getPoolSignal (Pool _ signal) = signal

-- getSignal :: forall i a. Ord i => i -> Pool i a -> Maybe (S.Signal a)
-- getSignal id (Pool map _) =
--     Map.lookup id map

-- emptyPool :: forall i a. a -> Pool i a
-- emptyPool fallback =
--     (Pool Map.empty (S.constant fallback))

-- plug :: forall i a. Ord i => i -> S.Signal a -> Pool i a -> Pool i a
-- plug key signal (Pool map poolSignal) =
--     let
--         map' = insert key signal map
--         poolSignal' = S.merge poolSignal signal
--     in
--         (Pool map' poolSignal')

-- unplug :: forall i a. Ord i => i -> a -> Pool i a -> Pool i a
-- unplug key fallback (Pool map poolSignal) =
--     let
--         map' = delete key map
--         poolSignal' = case S.mergeMany (values map') of
--             Just signal -> signal
--             Nothing -> S.constant fallback
--     in
--         (Pool map' poolSignal')

-- RPD

type Id = String

type NetworkId = Id
type PatchId = Id
type NodeId = Id
type ChannelId = Id
type InletId = ChannelId
type OutletId = ChannelId
type LinkId = Id

-- `n` — node type
-- `c` — channel type
-- `a` — data type
-- `x` — error type

data NetworkMsg n c
    = AddPatch PatchId String
    | AddPatch' PatchId
    | SelectPatch PatchId
    | DeselectPatch
    | EnterPatch PatchId
    | ExitPatch PatchId
    | AddNode PatchId n NodeId String
    | AddNode' PatchId n NodeId
    | AddInlet PatchId NodeId c InletId String
    | AddInlet' PatchId NodeId c InletId
    | AddOutlet PatchId NodeId c OutletId String
    | AddOutlet' PatchId NodeId c OutletId
    | Connect PatchId NodeId NodeId InletId OutletId
    | Disconnect PatchId NodeId NodeId InletId OutletId
    -- Hide Inlet'
    -- Disable Link'

data FlowMsg c a x
    = Send (Inlet' c) a -- send data to Outlets?
    | Attach (Inlet' c) (S.Signal a) -- send streams to Outlets?
    | SendError (Inlet' c) x

type Network' n c a x =
    { id :: NetworkId
    , patches :: Map PatchId (Patch n c a x)
    , selected :: Maybe PatchId
    , entered :: Array PatchId
    }

type Patch' n c a x =
    { id :: PatchId
    , title :: String
    , nodes :: Map NodeId (Node n c a x)
    , links :: Map LinkId (Link c a x)
    }

type Node' n c a x =
    { id :: NodeId
    , title :: String
    , type :: n
    , inlets :: Map InletId (Inlet c a x)
    , outlets :: Map OutletId (Outlet c a x)
    }

type Inlet' c =
    { id :: InletId
    , label :: String
    , type :: c
    }

type Outlet' c =
    { id :: OutletId
    , label :: String
    , type :: c
    }

-- type Link' c =
--     { id :: LinkId
--     , inlet :: Inlet' c
--     , outlet :: Outlet' c
--     }

data Flow a x
    = Bang
    | Data a
    | Error x

type FSignal a x = S.Signal (Flow a x)

data Network n c a x = Network (Network' n c a x) (FSignal a x)

data Patch n c a x = Patch (Patch' n c a x) (FSignal a x)

data Node n c a x = Node (Node' n c a x) (FSignal a x)

data Inlet c a x = Inlet (Inlet' c) (FSignal a x)

data Outlet c a x = Outlet (Outlet' c) (FSignal a x)

data Link c a x = Link (Outlet c a x) (Inlet c a x)

-- main functions

init :: forall n c a x. NetworkId -> Network n c a x
init id =
    Network
        { id : id
        , patches : Map.empty
        , selected : Nothing
        , entered : []
        }
        (S.constant Bang)

update :: forall n c a x. NetworkMsg n c -> Network n c a x -> Network n c a x
update (AddPatch id title) = addPatch id title
update (AddPatch' id) = addPatch id id
update (SelectPatch id) = selectPatch id
update DeselectPatch = deselectPatch
update (EnterPatch id) = enterPatch id
update (ExitPatch id) = exitPatch id
update (AddNode patchId type_ id title) = addNode patchId type_ id title
update (AddNode' patchId type_ id) = addNode patchId type_ id id
update (AddInlet patchId nodeId type_ id title) = addInlet patchId nodeId type_ id title
update (AddInlet' patchId nodeId type_ id) = addInlet patchId nodeId type_ id id
update (AddOutlet patchId nodeId type_ id title) = addOutlet patchId nodeId type_ id title
update (AddOutlet' patchId nodeId type_ id) = addOutlet patchId nodeId type_ id id
update (Connect patchId srcNodeId dstNodeId inletId outletId) =
    connect patchId srcNodeId dstNodeId inletId outletId
update (Disconnect patchId srcNodeId dstNodeId inletId outletId) =
    disconnect patchId srcNodeId dstNodeId inletId outletId

-- helpers

addPatch :: forall n c a x. PatchId -> String -> Network n c a x -> Network n c a x
addPatch id title (Network network networkSignal) =
    let
        patchSignal = S.constant Bang
        patch =
            Patch
                { id : id
                , title : title
                , nodes : Map.empty
                , links : Map.empty
                }
                patchSignal
        patches' = network.patches |> insert id patch
        networkSignal' = S.merge networkSignal patchSignal
    in
        Network
            network { patches = patches' }
            networkSignal'

selectPatch :: forall n c a x. PatchId -> Network n c a x -> Network n c a x
selectPatch id (Network network networkSignal) =
    Network
        network { selected = Just id }
        networkSignal

deselectPatch :: forall n c a x. Network n c a x -> Network n c a x
deselectPatch (Network network networkSignal) =
    Network
        network { selected = Nothing }
        networkSignal

enterPatch :: forall n c a x. PatchId -> Network n c a x -> Network n c a x
enterPatch id (Network network networkSignal) =
    Network
        network { entered = id : network.entered }
        networkSignal

exitPatch :: forall n c a x. PatchId -> Network n c a x -> Network n c a x
exitPatch id (Network network networkSignal) =
    Network
        network { entered = Array.delete id network.entered }
        networkSignal

addNode :: forall n c a x. PatchId -> n -> NodeId -> String -> Network n c a x -> Network n c a x
addNode patchId type_ id title network@(Network network' networkSignal) =
    case network'.patches |> Map.lookup patchId of
        Just patch ->
            let
                nodeSignal = (S.constant Bang)
                node =
                    Node
                        { id : id
                        , title : title
                        , type : type_
                        , inlets : Map.empty
                        , outlets : Map.empty
                        }
                        nodeSignal
                (Patch patch' patchSignal) = patch

                -- FIXME: we need to get patch with its pool anyway
                -- patch = find (\patch -> patch.id == patchId) network.patches
                -- patch' =
                --     Patch (patch { nodes = node : patch.nodes }) (S.merge patchSignal nodeSignal)
            in
                (Network network' networkSignal) -- FIXME: implement
        Nothing -> network -- return network unchanged in case of error. FIXME: return an error

addInlet
    :: forall n c a x
     . PatchId
    -> NodeId
    -> c
    -> InletId
    -> String
    -> Network n c a x
    -> Network n c a x
addInlet patchId nodeId type_ id title (Network network networkPool) =
    (Network network networkPool) -- FIXME: implement

addOutlet
    :: forall n c a x
     . PatchId
    -> NodeId
    -> c
    -> OutletId
    -> String
    -> Network n c a x
    -> Network n c a x
addOutlet patchId nodeId type_ id title (Network network networkPool) =
    (Network network networkPool) -- FIXME: implement

connect
    :: forall n c a x
     . PatchId
    -> NodeId
    -> NodeId
    -> InletId
    -> OutletId
    -> Network n c a x
    -> Network n c a x
connect patchId scrNodeId dstNodeId inletId outletId (Network network networkPool) =
    (Network network networkPool) -- FIXME: implement

disconnect
    :: forall n c a x
     . PatchId
    -> NodeId
    -> NodeId
    -> InletId
    -> OutletId
    -> Network n c a x
    -> Network n c a x
disconnect patchId scrNodeId dstNodeId inletId outletId (Network network networkPool) =
    (Network network networkPool) -- FIXME: implement

-- helpers 2

createPatch' :: forall n c a x. String -> Patch n c a x
createPatch' title =
    Patch
        { id : "test"
        , title : title
        , nodes : Map.empty
        , links : Map.empty
        }
        (S.constant Bang)

createNode' :: forall n c a x. String -> n -> Node n c a x
createNode' title nodeType =
    Node
        { id : "test"
        , title : title
        , type : nodeType
        , inlets : Map.empty
        , outlets : Map.empty
        }
        (S.constant Bang)

createInlet' :: forall c a x. String -> c -> Inlet c a x
createInlet' label inletType =
    Inlet
        { id : "test"
        , label : label
        , type : inletType
        }
        (S.constant Bang)

createOutlet' :: forall c a x. String -> c -> Outlet c a x
createOutlet' label outletType =
    Outlet
        { id : "test"
        , label : label
        , type : outletType
        }
        (S.constant Bang)

connect' :: forall c a x. Outlet c a x -> Inlet c a x -> Link c a x
connect' outlet inlet =
    Link outlet inlet

addNode' :: forall n c a x. Node n c a x -> Patch n c a x -> Patch n c a x
addNode' node@(Node node' nodeSignal) (Patch patch' patchSignal) =
    Patch
        (patch' { nodes = patch'.nodes |> insert node'.id node })
        (S.merge patchSignal nodeSignal)

addInlet' :: forall n c a x. Inlet c a x -> Node n c a x -> Node n c a x
-- addInlet inlet'@(Inlet inlet inletSignal) (Node node nodeSignal) =
--  Node (node { inlets = inlet' : node.inlets }) (S.merge nodeSignal inletSignal)
addInlet' inlet@(Inlet inlet' inletSignal) (Node node' nodeSignal) =
    Node
        (node' { inlets = node'.inlets |> insert inlet'.id inlet })
        (S.merge nodeSignal inletSignal)

addOutlet' :: forall n c a x. Outlet c a x -> Node n c a x -> Node n c a x
addOutlet' outlet@(Outlet outlet' outletSignal) (Node node' nodeSignal) =
    Node
        (node' { outlets = node'.outlets |> insert outlet'.id outlet })
        (S.merge nodeSignal outletSignal)

attach' :: forall c a x. S.Signal a -> Inlet c a x -> Inlet c a x
attach' dataSignal (Inlet inlet inletSignal) =
    let
        mappedSignal = (\d -> Data d) S.<~ dataSignal
    in
        Inlet inlet (S.merge inletSignal mappedSignal)

attachErrors' :: forall c a x. S.Signal x -> Inlet c a x -> Inlet c a x
attachErrors' errorSignal (Inlet inlet inletSignal) =
    let
        mappedSignal = (\x -> Error x) S.<~ errorSignal
    in
        Inlet inlet (S.merge inletSignal mappedSignal)

send' :: forall c a x. a -> Inlet c a x -> Inlet c a x
send' v =
    attach' (S.constant v)

sendError' :: forall c a x. x -> Inlet c a x -> Inlet c a x
sendError' e =
    attachErrors' (S.constant e)

-- instance showPercentage :: Show Percentage where
--   show (Percentage n) = show n <> "%"

-- rendering

stringRenderer :: forall n c a x. Show a => Show x => Patch n c a x -> S.Signal String
stringRenderer (Patch _ patchSignal) =
    patchSignal S.~> (\item ->
        case item of
            Bang -> show "Bang"
            Data d -> show d
             -- make data items require a Show instance,
             -- maybe even everywhere. Also create some type class which defines interfaces
             -- for Node type and Channel type?
            Error x -> show ("Error: " <> (show x)))

-- test stuff

hello :: S.Signal String
hello = (ST.every 1000.0) S.~> show

helloEffect :: forall eff. S.Signal (Eff (console :: CONSOLE | eff) Unit)
helloEffect = hello S.~> log

main_ :: forall eff. Eff (console :: CONSOLE | eff) Unit
main_ = S.runSignal helloEffect

-- main function with a custom patch

data MyNodeType = NumNode | StrNode

data MyInletType = NumInlet | StrInlet

main :: forall eff. Eff (console :: CONSOLE | eff) Unit
main =
    let
        patch = createPatch' "foo"
        node = createNode' "num" NumNode
        inlet = createInlet' "foo" StrInlet
        nodeWithInlet = addInlet' inlet node
        (Patch _ sumSignal) = addNode' nodeWithInlet patch
        -- signalLog = S.runSignal ((stringRenderer patch) S.~> log)
    in
        S.runSignal helloEffect
