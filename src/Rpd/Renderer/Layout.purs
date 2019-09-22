module Rpd.Renderer.Layout where

import Prelude

import Data.Array ((:))
import Data.Maybe (Maybe(..), fromMaybe, fromMaybe')
import Data.Map as Map
import Data.Sequence as Seq
import Data.Sequence (Seq)
import Data.Tuple (uncurry)
import Data.Tuple.Nested ((/\), type (/\))
import Data.Foldable (fold, foldr)
import Data.Lens (view) as L

import Data.BinPack.R2 as R2

import Rpd.Path as P
import Rpd.Util (Position, Rect, Bounds, type (/->), quickBounds', (+>))
import Rpd.UUID as UUID -- FIXME: use paths instead of UUIDs
import Rpd.Network as R
import Rpd.Optics (_networkPatches, _patchNodes) as L


type Layout =
    UUID.ToPatch /-> PatchLayout


type PatchLayout =
    { offset :: Position
    , stack :: NodesStack
    , pinned :: PinnedNodes
    --, floating :: UUID.ToNode /-> Position
    }


type NodesLayer = R2.Bin2 Number UUID.ToNode -- Store the nodes themselves
type NodesStack = Seq NodesLayer -- Shelving, may be?
type PinnedNodes = UUID.ToNode /-> Position


data LayerSize = LayerSize Rect
data NodeSize = NodeSize Rect


type GetNodeSize d n = R.Node d n -> NodeSize


layoutOf :: UUID.ToPatch -> Layout -> Maybe PatchLayout
layoutOf = Map.lookup


-- execute the function with the Stacks of the PatchLayout,
-- may be used to render the Stacks, where `x` is the `view`, then
withStackOf
    :: forall x
     . (UUID.ToNode -> Position -> Rect -> x)
    -> PatchLayout
    -> Array x
withStackOf fn patchLayout =
    fold $ R2.unfold ((:) <<< fn') [] <$> patchLayout.stack
    where
        fn' :: (UUID.ToNode /\ Number /\ Number /\ Number /\ Number) -> x
        fn' (uuid /\ x /\ y /\ width /\ height ) =
            fn uuid { x, y } { width, height }


-- execute the function with the pinned nodes of the PatchLayout,
-- may be used to render the pinned nodes, where `x` is the `view`, then
withPinnedOf
    :: forall x
     . (UUID.ToNode -> Position -> x)
    -> PatchLayout
    -> Array x
withPinnedOf fn patchLayout =
    uncurry fn <$> Map.toUnfoldable patchLayout.pinned


-- TODO: generic function : layoutOf + withStackOf + withPinnedOf


newLayer :: LayerSize -> NodesLayer
newLayer (LayerSize { width, height }) =
    R2.container width height


-- load the existing nodes from the network into Stacks
loadIntoStacks
    :: forall d c n
     . LayerSize
    -> GetNodeSize d n
    -> R.Network d c n
    -> (UUID.ToPatch /-> NodesStack)
loadIntoStacks layerSize getNodeSize nw =
    L.view L._networkPatches nw
        # map pairWithStack
        # Map.fromFoldable
    where
        pairWithStack (R.Patch patchUuid _ _) =
            patchUuid /\
            (foldr packNode initialStack
                $ fromMaybe Seq.empty
                $ L.view (L._patchNodes patchUuid) nw
            )
        packNode node stack =
            packInStack layerSize (getNodeSize node) node stack
        initialStack =
            Seq.singleton $ newLayer layerSize


unpackLayer :: NodesLayer -> (UUID.ToNode /-> Bounds)
unpackLayer packing =
    Map.fromFoldable $ ((<$>) quickBounds') <$> R2.toList packing
    -- R2.unfold (\tuple map -> ) Map.empty packing


packInStack
    :: forall d n
     . LayerSize
    -> NodeSize
    -> R.Node d n
    -> NodesStack
    -> NodesStack
packInStack layerSize (NodeSize { width, height }) node@(R.Node nodeUuid _ _ _ _) stack =
    case Seq.head stack of
        Just topLayer ->
            case packNode topLayer of
                Just topLayerWithNode ->
                    (fromMaybe Seq.empty $ Seq.tail stack)
                        +> topLayerWithNode
                Nothing ->
                    -- failed to fit on the top layer
                    stack +> nodeOnNewLayer
        Nothing ->
            stack +> nodeOnNewLayer
    where
        packNode :: NodesLayer -> Maybe NodesLayer
        packNode layer =
            R2.packOne layer $ R2.item width height nodeUuid
        nodeOnNewLayer
            = newLayer layerSize # packNode # fromMaybe' (const $ newLayer layerSize)


newPatchLayout :: Unit -> PatchLayout
newPatchLayout _ =
    { offset : { x : 0.0, y : 0.0 }
    , pinned : Map.empty
    , stack : Seq.empty
    }


-- TODO: internal, do not expose
modifyStack
    :: UUID.ToPatch
    -> (NodesStack -> NodesStack)
    -> Maybe PatchLayout
    -> Layout
    -> Layout
modifyStack patchUuid updateStack (Just patchLayout) layout =
    Map.insert patchUuid
        (patchLayout
            { stack = updateStack patchLayout.stack
            }
        )
        layout
modifyStack patchUuid updateStack Nothing layout =
    let
        newPLayout = newPatchLayout unit
    in
        Map.insert patchUuid
            (newPLayout
                { stack = updateStack newPLayout.stack
                }
            )
            layout


pack
    :: forall d n
     . LayerSize
    -> NodeSize
    -> UUID.ToPatch
    -> R.Node d n
    -> Layout
    -> Layout
pack layerSize nodeSize patchUuid node layout =
    modifyStack
        patchUuid
        (packInStack layerSize nodeSize node)
        (Map.lookup patchUuid layout)
        layout

resize
    :: LayerSize
    -> Layout
    -> Layout
resize newSize layout =
    layout -- FIXME: implement, use R2.repack


pinAt :: forall d c n. R.Patch d c n -> R.Node d n -> Position -> Layout -> Layout
pinAt (R.Patch patchUuid _ _) (R.Node nodeUuid nodePath _ _ _) position layout =
    case layout # layoutOf patchUuid of
        Just patchLayout ->
            Map.insert patchUuid (pinAtPatchLayout patchLayout) layout
        Nothing -> layout
    where
        pinAtPatchLayout patchLayout =
            patchLayout
                { pinned =
                    Map.insert nodeUuid position patchLayout.pinned
                }


initWithStacks :: (UUID.ToPatch /-> NodesStack) -> Layout
initWithStacks patchToStack =
    patchToStack <#> \stack ->
        let patchLayout = newPatchLayout unit
        in patchLayout { stack = stack } -- TODO: _.stack


freeUp :: forall d c n. R.Patch d c n -> R.Node d n -> Layout -> Layout
freeUp (R.Patch patchUuid _ _) (R.Node nodeUuid nodePath _ _ _) layout =
    case layout # layoutOf patchUuid of
        Just patchLayout ->
            Map.insert patchUuid (removeFromPatchLayout patchLayout) layout
        Nothing -> layout
    where
        removeFromPatchLayout patchLayout =
            patchLayout
                { stack =
                    R2.free nodeUuid <$> patchLayout.stack
                , pinned =
                    Map.delete nodeUuid patchLayout.pinned
                }


