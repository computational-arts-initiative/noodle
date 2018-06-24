module Rpd
    ( Rpd, run, RpdEff, RpdEffE
    , DataSource(..), Flow, getFlowOf
    , Network(..), Patch(..), Node(..), Inlet(..), Outlet(..), Link(..)
    , RunningNetwork
    , empty
    , network, patch, node, inlet, inlet', inletWithDefault, inletWithDefault', outlet, outlet'
    , connect, connect', disconnect, disconnect', disconnectTop
    , ProcessF, processWith
    , PatchId(..), NodePath(..), InletPath(..), OutletPath(..), LinkId(..)
    , patchId, nodePath, inletPath, outletPath
    , isNodeInPatch, isInletInPatch, isOutletInPatch, isInletInNode, isOutletInNode
    , notInTheSameNode
    , getPatchOfNode, getPatchOfInlet, getPatchOfOutlet, getNodeOfInlet, getNodeOfOutlet
    , findPatch, findNode, findOutlet, findInlet
    ) where

import Prelude

import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Array ((:), (!!), mapWithIndex, modifyAt, findMap, delete, filter, head)
import Data.Tuple.Nested ((/\))

import Control.Monad.Eff (Eff, kind Effect)

import FRP (FRP)
import FRP.Event (Event)


type Flow d = Event d


-- type ProcessF d = (Map InletPath d -> Map OutletPath d)
type ProcessF d = (Map String d -> Map String d)
-- type DirectProcessF d = (String -> d -> String /\ d)
-- type DirectProcessF' d = (String -> d -> d)
-- type OptionalProcessF d = (String -> d -> Maybe d)
-- type OptionalProcessF' d = (String -> d -> String /\ Maybe d)


data Rpd d = Rpd (Network d)

data PatchId = PatchId Int
data NodePath = NodePath PatchId Int
data InletPath = InletPath NodePath Int
data OutletPath = OutletPath NodePath Int
data LinkId = LinkId Int


data DataSource d
    = UserSource (Flow d)
    | OutletSource OutletPath (Flow d)
    -- | UISource (Flow d)

type PatchDef d =
    { name :: String
    , nodeDefs :: Array (NodeDef d)
    , linkDefs :: Array LinkDef -- TODO: links partly duplicate Inlet: sources, aren't they?
    -- TODO: maybe store Connections: Map InletPath (Array DataSource)
    }
type NodeDef d =
    { name :: String
    , inletDefs :: Array (InletDef d)
    , outletDefs :: Array (OutletDef d)
    , process :: ProcessF d
    -- , flow :: Flow (Map (Inlet d) d /\ Map (Outlet d) d)
    }
type InletDef d =
    { label :: String
    , default :: Maybe d
    -- , accept :: d
    -- , sources :: Array (DataSource d)
    -- Maybe (AdaptF d)
    }
type OutletDef d =
    { label :: String
    , flow :: Maybe (Flow d)
    }
type LinkDef = (Int /\ Int) /\ (Int /\ Int)

-- data BuilderContext
--     = BCPatch PatchId
--     | BCNode NodePath
--     |

-- data NetworkBuilder = NetworkBuilder BuilderContext

-- newPatch 'Test'
-- addNode 'aaa'
-- addNode' colorNode
-- addNode'' colorNode { name = 'CLR' }
-- addNode'' paletteNode { processF = ... }
-- addInlet 0 'ff'
-- send 0 0 (interval 5 foo)
-- addInlet' colorInlet
-- addInlet'' colorInlet { label = 'a' } -- may fail
-- addOutlet 0 'sum'
-- connect 0 0 1 0

-- TODO: normalize network, change to plain IDs maybe, or use paths as keys,
--       they implement Eq anyway
data Network d = Network -- (NetworkDef d)
    { name :: String
    }

data Patch d = Patch PatchId -- (PatchDef d)
    { name :: String
    , nodes :: Array (Node d)
    , links :: Array Link -- TODO: links partly duplicate Inlet: sources, aren't they?
    -- TODO: maybe store Connections: Map InletPath (Array DataSource)
    }
data Node d = Node NodePath -- (NodeDef d)
    { inlets :: Array (Inlet d)
    , outlets :: Array (Outlet d)
    }
-- S.constant is not able to send values afterwards, so we store the default value inside
-- TODO: inlet sources should be a set of outletPaths, so outlet-inlet pairs would be unique
data Inlet d = Inlet InletPath
    { label :: String
    , default :: Maybe d
    , sources :: Array (DataSource d)
    -- , accept :: d
    -- Maybe (AdaptF d)
    }
--data Inlet d = Inlet String (Maybe (AdaptF d))
data Outlet d = Outlet OutletPath
    { label :: String
    , flow :: Maybe (Flow d)
    }
data Link = Link OutletPath InletPath


-- data NormalizedNetwork d =
--     NormalizedNetwork
--         (Array (Patch' d))
--         (Array (Node' d))
--         (Array (Inlet' d))
--         (Array (Outlet' d))
--         (Array (Link' d))

-- type WithId e a = Eff ( random :: RANDOM | e ) a


-- data DataMsg d
--     = FromInlet InletPath d
--     | FromOutlet OutletPath d

-- foreign import data RPD :: Effect

type RpdEffE e = ( frp :: FRP | e )
type RpdEff e v = Eff (RpdEffE e) v

data RunningNetwork d e = RpdEff e (Network d)

-- may be it will make more sense when we'll do subscriptions before passing network to rederer
-- also, may be change to ehm... `UnpreparedNetwork`` and then the subscriber gets the `Real` one?
-- is it the place where RPD effect should be added to the result, like with subscriptions?
run :: forall d e. (Network d -> RpdEff e Unit) -> Network d -> RpdEff e Unit
run renderer nw = renderer nw


empty :: forall d. Network d
empty = Network { patches : [] }


-- network :: forall d. Array (Patch d) -> Network d
-- network lazyPatches =
--     Network { patches }
--     where
--         patches = mapWithIndex
--             (\idx lazyPatch -> lazyPatch $ PatchId idx) lazyPatches


newPatch :: forall d e. String -> Network d -> Network d
newPatch name (Network nw) =
    Network nw { patches = patch : nw.patches } where
        patchId = PatchId (length nw.patches)
        patch =
            Patch patch
                { name
                , nodes
                , links : []
                }

-- addPatch1 :: forall d e. PatchId -> String -> Network d -> Network d

-- addPatch' :: forall d e. String -> RunningNetwork d e -> RunningNetwork d e

addNode :: forall d. PatchId -> String -> Network d -> Network d
addNode = undefined


node :: forall d. String -> Array (Inlet d) -> Array (Outlet d) -> Node d
node name lazyInlets lazyOutlets =
    \nodePath ->
        let
            inlets = mapWithIndex
                (\idx lazyInlet ->
                    lazyInlet (InletPath nodePath idx)) lazyInlets
            outlets = mapWithIndex
                (\idx lazyOutlet ->
                    lazyOutlet (OutletPath nodePath idx)) lazyOutlets
        in
            Node
                { path : nodePath
                , name
                , inlets
                , outlets
                , process : const Map.empty
                }


inlet :: forall d. String -> Inlet d
inlet label =
    inlet_ label Nothing []


inlet' :: forall d. String -> Flow d -> Inlet d
inlet' label dataSource =
    inlet_ label Nothing [ UserSource dataSource ]


-- should not be exposed
inlet_ :: forall d. String -> Maybe d -> Array (DataSource d) -> Inlet d
inlet_ label maybeDefault sources =
    \inletPath ->
        Inlet
            { path : inletPath
            , label
            , default : maybeDefault
            , sources
            }


inletWithDefault :: forall d. String -> d -> Inlet d
inletWithDefault label defaultVal =
    -- inlet_ label defaultVal $ S.constant defaultVal
    inlet_ label (Just defaultVal) [ ]


inletWithDefault' :: forall d. String -> d -> Flow d -> Inlet d
inletWithDefault' label defaultVal dataSource  =
    inlet_ label (Just defaultVal) [ UserSource dataSource ]


outlet :: forall d. String -> Outlet d
outlet label =
    \outletPath ->
        Outlet
            { path : outletPath
            , label
            , flow : Nothing
            }


-- TODO: remove, outlets should only produce values from `process` function
outlet' :: forall d. String -> Flow d -> Outlet d
outlet' label flow =
    \outletPath ->
        Outlet
            { path : outletPath
            , label
            , flow : Just flow
            }


findTopConnection :: forall d. InletPath -> Network d -> Maybe OutletPath
findTopConnection inletPath network =
    findInlet inletPath network >>=
        (\(Inlet { sources }) -> findMap (\src ->
                case src of
                    UserSource _ -> Nothing
                    OutletSource outletPath _ -> Just outletPath
            ) sources
        )

findTopSource :: forall d. InletPath -> Network d -> Maybe (DataSource d)
findTopSource inletPath network =
    findInlet inletPath network >>= \(Inlet { sources }) -> head sources


findSource :: forall d. OutletPath -> InletPath -> Network d -> Maybe (DataSource d)
findSource outletPath inletPath network =
    findInlet inletPath network >>=
        (\(Inlet { sources }) -> findMap (\src ->
                -- OutletSource outletPath' _ <- src
                -- pure $ if (outletPath' == outletPath) then src else unit
                case src of
                    UserSource _ -> Nothing
                    OutletSource outletPath' _ ->
                        if (outletPath' == outletPath) then Just src
                        else Nothing
            ) sources
        )


isNodeInPatch :: NodePath -> PatchId -> Boolean
isNodeInPatch (NodePath patchId' _) patchId =
    patchId == patchId'


isInletInPatch :: InletPath -> PatchId -> Boolean
isInletInPatch (InletPath nodePath _) patchId =
    isNodeInPatch nodePath patchId


isOutletInPatch :: OutletPath -> PatchId -> Boolean
isOutletInPatch (OutletPath nodePath _) patchId =
    isNodeInPatch nodePath patchId


isInletInNode :: InletPath -> NodePath -> Boolean
isInletInNode (InletPath nodePath' _) nodePath =
    nodePath == nodePath'


isOutletInNode :: OutletPath -> NodePath -> Boolean
isOutletInNode (OutletPath nodePath' _) nodePath =
    nodePath == nodePath'


notInTheSameNode :: InletPath -> OutletPath -> Boolean
notInTheSameNode (InletPath iNodePath _) (OutletPath oNodePath _) =
    iNodePath /= oNodePath


findPatch :: forall d. PatchId -> Network d -> Maybe (Patch d)
findPatch (PatchId index) (Network { patches }) =
    patches !! index


findNode :: forall d. NodePath -> Network d -> Maybe (Node d)
findNode (NodePath patchId index) network =
    findPatch patchId network >>= (\(Patch { nodes }) -> nodes !! index)


findInlet :: forall d. InletPath -> Network d -> Maybe (Inlet d)
findInlet (InletPath nodePath index) network =
    findNode nodePath network >>= (\(Node { inlets }) -> inlets !! index)


findOutlet :: forall d. OutletPath -> Network d -> Maybe (Outlet d)
findOutlet (OutletPath nodePath index) network =
    findNode nodePath network >>= (\(Node { outlets }) -> outlets !! index)


-- TODO: change return type of the functions below to Maybe,
-- to identify the case when subject wasn't modified

updatePatch :: forall d. (Patch d -> Patch d) -> PatchId -> Network d -> Network d
updatePatch updater (PatchId patchId) (Network network) =
    Network network
        { patches = fromMaybe network.patches
            $ modifyAt patchId updater network.patches
        }


updateNode :: forall d. (Node d -> Node d) -> NodePath -> Network d -> Network d
updateNode updater (NodePath patchId nodeId) network =
    updatePatch (\(Patch patch) ->
        Patch patch
            { nodes = fromMaybe patch.nodes
                $ modifyAt nodeId updater patch.nodes
            }
    ) patchId network


updateInlet :: forall d. (Inlet d -> Inlet d) -> InletPath -> Network d -> Network d
updateInlet updater (InletPath nodePath inletId) network =
    updateNode (\(Node node) ->
        Node node
            { inlets = fromMaybe node.inlets
                $ modifyAt inletId updater node.inlets
            }
    ) nodePath network


updateOutlet :: forall d. (Outlet d -> Outlet d) -> OutletPath -> Network d -> Network d
updateOutlet updater (OutletPath nodePath outletId) network =
    updateNode (\(Node node) ->
        Node node
            { outlets = fromMaybe node.outlets
                $ modifyAt outletId updater node.outlets
            }
    ) nodePath network


processWith :: forall d. ProcessF d -> Node d -> Node d
processWith processF (Node node) =
    Node node { process = processF }


-- getInletLabel :: forall d. Node d -> InletPath -> Maybe String
-- getInletLabel (Node { inlets }) path' =
--     Array.filter (\(Inlet { path }) -> path == path') path inlets <#> \(Inlet { label }) -> label


-- processWith' :: forall d. ProcessF' d -> LazyNode d -> LazyNode d
-- processWith' processF =
--     processWith f
--     where
--         f inputs = Map.mapWithKey processF inputs


-- processWith'' :: forall d. ProcessF'' d -> d -> LazyNode d -> LazyNode d
-- processWith'' processF default =
--     processWith f
--     where
--         f inputs = map (fromMaybe default)
--                     $ Map.filter isJust
--                     $ Map.mapWithKey processF inputs


-- processWith''' :: forall d. ProcessF''' d -> d -> LazyNode d -> LazyNode d
-- processWith''' processF default =
--     processWith f
--     where
--         f inputs = map (fromMaybe default)
--                     $ Map.filter isJust
--                     $ Map.mapWithKey processF inputs


connect
    :: forall d
     . OutletPath
    -> InletPath
    -> Patch d
    -> Patch d
connect outletPath inletPath patchF =
    -- TODO: implement
    patchF


connect' :: forall d. OutletPath -> InletPath -> Network d -> Maybe (Network d)
connect' outletPath inletPath network = do
    outlet <- findOutlet outletPath network
    let (Outlet { flow }) = outlet
    flow' <- flow
    let
        -- flow' = fromMaybe' (\_ -> ) flow
        patchId = getPatchOfInlet inletPath
        newLink = Link outletPath inletPath
        network' = updatePatch
                    (\(Patch patch@{ links }) -> Patch patch { links = newLink : links })
                    patchId
                    network
        newSource = OutletSource outletPath flow'
    pure $ updateInlet
                (\(Inlet inlet@{ sources }) ->
                    Inlet inlet { sources = newSource : sources })
                inletPath
                network'


disconnect :: forall d. Outlet d -> Inlet d -> Patch d -> Patch d
disconnect outlet inlet patch =
    patch -- FIXME: implement


disconnect' :: forall d. OutletPath -> InletPath -> Network d -> Maybe (Network d)
disconnect' outletPath inletPath network = do
    network' <- removeLink outletPath inletPath network
    outlet <- findOutlet outletPath network'
    inlet <- findInlet inletPath network'
    -- source <- findSource outletPath inletPath network'
    let
        isFromOutlet oPath1 (OutletSource oPath2 _) = oPath1 == oPath2
        isFromOutlet _ _ = false
    -- TODO: optimize, do not search through network several times
    pure $ updateInlet
                (\(Inlet inlet@{ sources }) ->
                    -- Inlet inlet { sources = deleteBy cmpSources source sources })
                    Inlet inlet { sources = filter (not $ isFromOutlet outletPath) sources })
                inletPath
                network'


disconnectTop :: forall d. InletPath -> Network d -> Maybe (Network d)
disconnectTop inletPath network =
    -- TODO: optimize with searching last and updating simultaneously
    findTopConnection inletPath network
        >>= (\outletPath -> disconnect' outletPath inletPath network)


-- disconnectLast' :: forall d. InletPath -> Network d -> Maybe (Network d)

-- getConnections :: Node -> (Map OutletPath InletPath) or (Array Link)

-- getConnections :: Patch -> (Map OutletPath InletPath) or (Array Link)

-- TODO: findLink :: forall d. InletPath -> Network d -> Maybe (Link d)


removeLink :: forall d. OutletPath -> InletPath -> Network d -> Maybe (Network d)
removeLink outletPath inletPath network = do
    let
        oPatchId = getPatchOfOutlet outletPath
        iPatchId = getPatchOfInlet inletPath
    patchId <- if oPatchId == iPatchId then Just oPatchId else Nothing
    let
        network' = updatePatch
                    (\(Patch patch@{ links }) ->
                        Patch patch { links = delete (Link outletPath inletPath) links })
                    patchId
                    network
    pure network'


getFlowOf :: forall d. DataSource d -> Flow d
getFlowOf dataSource =
    case dataSource of
        UserSource flow -> flow
        OutletSource _ flow -> flow


patchId :: Int -> PatchId
patchId = PatchId


nodePath :: Int -> Int -> NodePath
nodePath pId nId = NodePath (PatchId pId) nId


inletPath :: Int -> Int -> Int -> InletPath
inletPath pId nId iId = InletPath (NodePath (PatchId pId) nId) iId


outletPath :: Int -> Int -> Int -> OutletPath
outletPath pId nId iId = OutletPath (NodePath (PatchId pId) nId) iId


getPatchOfNode :: NodePath -> PatchId
getPatchOfNode (NodePath pId _) = pId


getPatchOfInlet :: InletPath -> PatchId
getPatchOfInlet inlet = getPatchOfNode $ getNodeOfInlet inlet


getPatchOfOutlet :: OutletPath -> PatchId
getPatchOfOutlet outlet = getPatchOfNode $ getNodeOfOutlet outlet


getNodeOfInlet :: InletPath -> NodePath
getNodeOfInlet  (InletPath nPath _) = nPath


getNodeOfOutlet :: OutletPath -> NodePath
getNodeOfOutlet  (OutletPath nPath _) = nPath


-- connect inside a Patch??
-- connect :: forall d e. Inlet d -> Outlet d -> d -> Eff ( channel :: SC.CHANNEL | e ) (SC.Channel d)
-- connect inlet outlet defaultVal = do
--     channel <- SC.channel defaultVal
--     pure channel


unpackNodePath :: NodePath -> Array Int
unpackNodePath (NodePath (PatchId patchId) id) = [ patchId, id ]

unpackInletPath :: InletPath -> Array Int
unpackInletPath (InletPath nodePath id) = unpackNodePath nodePath <> [ id ]

unpackOutletPath :: OutletPath -> Array Int
unpackOutletPath (OutletPath nodePath id) = unpackNodePath nodePath <> [ id ]


instance showPatchId :: Show PatchId where
    show (PatchId id) = "P" <> show id

instance showNodePath :: Show NodePath where
    show (NodePath patchId id) = show patchId <> "/N" <> show id

instance showInletPath :: Show InletPath where
    show (InletPath nodePath id) = show nodePath <> "/I" <> show id

instance showOutletPath :: Show OutletPath where
    show (OutletPath nodePath id) = show nodePath <> "/O" <> show id

instance showLinkId :: Show LinkId where
    show (LinkId id) = "L" <> show id


instance eqPatchId :: Eq PatchId where
    eq (PatchId a) (PatchId b) = (a == b)

instance eqNodePath :: Eq NodePath where
    eq (NodePath pa a) (NodePath pb b) = (pa == pb) && (a == b)

instance eqInletPath :: Eq InletPath where
    eq (InletPath na a) (InletPath nb b) = (na == nb) && (a == b)

instance eqOutletPath :: Eq OutletPath where
    eq (OutletPath na a) (OutletPath nb b) = (na == nb) && (a == b)


instance ordPatchId :: Ord PatchId where
    compare (PatchId a) (PatchId b) = compare a b

instance ordNodePath :: Ord NodePath where
    compare nodePath1 nodePath2 =
        compare (unpackNodePath nodePath1)  (unpackNodePath nodePath2)

instance ordInletPath :: Ord InletPath where
    compare inletPath1 inletPath2 =
        compare (unpackInletPath inletPath1)  (unpackInletPath inletPath2)

instance ordOutletPath :: Ord OutletPath where
    compare outletPath1 outletPath2 =
        compare (unpackOutletPath outletPath1)  (unpackOutletPath outletPath2)


-- TODO: create HasId / HasPath typeclass
instance eqPatch :: Eq (Patch d) where
    eq (Patch { id : idA }) (Patch { id : idB }) = (idA == idB)

instance eqNode :: Eq (Node d) where
    eq (Node { path : pathA }) (Node { path : pathB }) = (pathA == pathB)

instance eqInlet :: Eq (Inlet d) where
    eq (Inlet { path : pathA }) (Inlet { path : pathB }) = (pathA == pathB)

instance eqOutlet :: Eq (Outlet d) where
    eq (Outlet { path : pathA }) (Outlet { path : pathB }) = (pathA == pathB)

instance eqLink :: Eq Link where
    eq (Link outletA inletA) (Link outletB inletB) = (outletA == outletB) && (inletA == inletB)
