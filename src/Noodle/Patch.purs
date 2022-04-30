module Noodle.Patch where


import Prelude
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)

-- import Data.Functor (lift)

import Data.Exists (Exists, mkExists, runExists)
import Data.Set (Set)
import Data.List (List)
import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Map (Map)
import Data.Map as Map
import Data.Map.Extra (type (/->))
import Data.Foldable (foldr, foldM)
import Data.Traversable (sequence, traverse)
import Data.Tuple (fst, snd, curry, uncurry) as Tuple
import Data.Tuple.Nested ((/\), type (/\))
import Unsafe.Coerce (unsafeCoerce)


import Noodle.Node (Node, Link)
import Noodle.Node as Node
import Noodle.Toolkit (Toolkit)
import Noodle.Toolkit as Toolkit
-- import Noodle.PatchM (PatchM)


type Id = String


type InletPath = Node.Id /\ Node.InletId
type OutletPath = Node.Id /\ Node.OutletId


-- data NodeS d state = NodeS state (state -> Node state d)
data NodeS d state = NodeS (Node state d)
type NodeE d = Exists (NodeS d)


data Patch d =
    Patch
        (Node.Id /-> NodeE d)
        ((OutletPath /\ InletPath) /-> Link)


infixl 4 connect as <~>
infixl 4 disconnect as <~/~>
infixl 5 send' as +>
infixl 5 produce' as ++>


empty :: forall d. Patch d
empty = Patch Map.empty Map.empty


addNode :: forall node_state d. Node.Id -> Node node_state d -> Patch d -> Patch d
addNode name node (Patch nodes links) =
    Patch
        (nodes # Map.insert name (mkExists $ NodeS node))
        links


addNodeFrom :: forall node_state d. Toolkit node_state d -> node_state -> Node.Family /\ Node.Id -> Patch d -> Effect (Patch d)
addNodeFrom toolkit state (nodeFamily /\ nodeId) patch =
    Toolkit.spawn' nodeFamily state toolkit
        <#> maybe patch (\node -> addNode nodeId node patch)


addNodeFrom' :: forall node_state d. Toolkit node_state d -> node_state -> Node.Family -> Patch d -> Effect (Node.Id /\ Patch d)
addNodeFrom' toolkit state nodeFamily patch =
    addNodeFrom toolkit state (nodeFamily /\ nextNodeId) patch
        <#> ((/\) nextNodeId)
    where nextNodeId = addUniqueNodeId patch nodeFamily


addNodesFrom :: forall node_state d. Toolkit node_state d -> node_state -> Array (Node.Family /\ Node.Id) -> Patch d -> Effect (Patch d)
addNodesFrom toolkit state pairs patch =
    foldr (\pair patchEff -> patchEff >>= addNodeFrom toolkit state pair) (pure patch) pairs


nodes :: forall d. Patch d -> Array (Node.Id /\ NodeE d)
nodes (Patch nodes _) = nodes # Map.toUnfoldable--Unordered


links :: forall node_state d. Patch d -> Set (OutletPath /\ InletPath)
links (Patch _ links) = links # Map.keys


findNode' :: forall d. Node.Id -> Patch d -> Maybe (NodeE d)
findNode' name (Patch nodes _) = nodes # Map.lookup name


findNode :: forall state d. Node.Id -> Patch d -> Maybe (Node state d)
findNode name p = unwrapNode <$> findNode' name p


nodesCount :: forall node_state d. Patch d -> Int
nodesCount (Patch nodes _) = Map.size nodes


linksCount :: forall node_state d. Patch d -> Int
linksCount (Patch _ links) = Map.size links


registerLink :: forall node_state d. OutletPath -> InletPath -> Link -> Patch d -> Patch d
registerLink outletPath inletPath link (Patch nodes links) =
    Patch nodes
        $ Map.insert (outletPath /\ inletPath) link
        $ links


forgetLink :: forall node_state d. OutletPath -> InletPath -> Patch d -> Patch d
forgetLink outletPath inletPath (Patch nodes links) =
    Patch nodes
        $ Map.delete (outletPath /\ inletPath)
        $ links


forgetNode :: forall node_state d. Node.Id -> Patch d -> Patch d
forgetNode nodeId (Patch nodes links) =
    Patch
        (Map.delete nodeId nodes)
        links


connect :: forall d. OutletPath -> InletPath -> Patch d -> Effect (Patch d)
connect (srcNodeName /\ outlet) (dstNodeName /\ inlet) patch =
    {- case (/\) <$> findNode srcNodeName patch <*> findNode dstNodeName patch of
        Just (srcNode /\ dstNode) ->
            Node.connect (?wh /\ outlet) (?wh /\ inlet)
            -- Node.connect (srcNode /\ outlet) (dstNode /\ inlet)
                <#> \link ->
                    registerLink (srcNodeName /\ outlet) (dstNodeName /\ inlet) link patch
        Nothing -> pure patch -}
    case findNode srcNodeName patch /\ findNode dstNodeName patch of
        (Just srcNode /\ Just dstNode) ->
            Node.connect (srcNode /\ outlet) (dstNode /\ inlet)
            -- Node.connect (srcNode /\ outlet) (dstNode /\ inlet)
                <#> \link ->
                    registerLink (srcNodeName /\ outlet) (dstNodeName /\ inlet) link patch
        _ -> pure patch


disconnect :: forall node_state d. OutletPath -> InletPath -> Patch d -> Effect (Patch d)
disconnect outletPath inletPath patch@(Patch _ links) =
    case links # Map.lookup (outletPath /\ inletPath) of
        Just link -> do
            Node.disconnect link
            pure $ forgetLink outletPath inletPath patch
        Nothing ->
            pure patch


removeNode :: forall node_state d. Node.Id -> Patch d -> Effect (Patch d)
removeNode nodeId patch@(Patch nodes _) =
    let linksWithNode = patch # linksToFromNode nodeId
    in do
        noMoreLinksPatch <- foldM (flip $ Tuple.uncurry disconnect) patch (Tuple.fst <$> linksWithNode)
        pure $ forgetNode nodeId noMoreLinksPatch


linksStartingFrom :: forall node_state d. OutletPath -> Patch d -> Array (InletPath /\ Link)
linksStartingFrom outletPath (Patch _ links) =
    links
        # Map.toUnfoldable
        # Array.mapMaybe
            (\((outletPath' /\ inletPath) /\ link) ->
                if outletPath' == outletPath
                then Just $ inletPath /\ link
                else Nothing
            )


linksLeadingTo :: forall node_state d. InletPath -> Patch d -> Array (OutletPath /\ Link)
linksLeadingTo inletPath (Patch _ links) =
    links
        # Map.toUnfoldable
        # Array.mapMaybe
            (\((outletPath /\ inletPath') /\ link) ->
                if inletPath' == inletPath
                then Just $ outletPath /\ link
                else Nothing
            )


linksToNode :: forall node_state d. Node.Id -> Patch d -> Array ((OutletPath /\ InletPath) /\ Link)
linksToNode nodeId (Patch _ links) =
    links
        # Map.toUnfoldable
        # Array.mapMaybe
            (\(linkPath@(_ /\ (nodeId' /\ _)) /\ link) ->
                if nodeId' == nodeId
                then Just $ linkPath /\ link
                else Nothing
            )


linksFromNode :: forall node_state d. Node.Id -> Patch d -> Array ((OutletPath /\ InletPath) /\ Link)
linksFromNode nodeId (Patch _ links) =
    links
        # Map.toUnfoldable
        # Array.mapMaybe
            (\(linkPath@((nodeId' /\ _) /\ _) /\ link) ->
                if nodeId' == nodeId
                then Just $ linkPath /\ link
                else Nothing
            )


linksToFromNode :: forall node_state d. Node.Id -> Patch d -> Array ((OutletPath /\ InletPath) /\ Link)
linksToFromNode node patch =
    Array.nubByEq samePath $ linksToNode node patch <> linksFromNode node patch
    where samePath (pathA /\ _) (pathB /\ _) = pathA == pathB


linksCountAtNode :: forall node_state d. Node.Id -> Patch d -> Node.LinksCount
linksCountAtNode node patch =
    let
        linksData = Tuple.fst <$> linksToFromNode node patch
        addOne (Just n) = Just $ n + 1
        addOne Nothing = Just 1
        addInletInfo (_ /\ inletPath) map =
            case inletPath of
                node' /\ inlet -> if node == node' then Map.alter addOne inlet map else map
        addOutletInfo (outletPath /\ _) map =
            case outletPath of
                node' /\ outlet -> if node == node' then Map.alter addOne outlet map else map
    in
    (foldr addInletInfo Map.empty linksData)
    /\
    (foldr addOutletInfo Map.empty linksData)


send :: forall node_state d. (Node.Id /\ Node.InletId) -> d -> Patch d -> Effect Unit
send (node /\ inlet) v patch =
    patch
        # findNode node
        <#> (flip Node.send (inlet /\ v))
        # fromMaybe (pure unit)


send' :: forall node_state d. (Node.Id /\ Node.InletId) -> d -> Patch d -> Effect (Patch d)
send' path v patch =
    send path v patch *> pure patch


produce :: forall d. (Node.Id /\ Node.OutletId) -> d -> Patch d -> Effect Unit
produce (node /\ outlet) v patch =
    patch
        # findNode node
        <#> (flip Node.produce (outlet /\ v))
        # fromMaybe (pure unit)


produce' :: forall node_state d. (Node.Id /\ Node.OutletId) -> d -> Patch d -> Effect (Patch d)
produce' path v patch =
    produce path v patch *> pure patch


addUniqueNodeId :: forall node_state d. Patch d -> Node.Family -> Node.Id
addUniqueNodeId patch nodeFamily =
    nodeFamily <> "-" <> (show $ nodesCount patch + 1)



unwrapNode :: forall state d. NodeE d -> Node state d
unwrapNode = runExists $ \(NodeS node) -> unsafeCoerce node


-- TODO: `withNode`