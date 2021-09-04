module App.Component.Patch where


import Prelude

import Debug (spy) as Debug

import Effect.Class (class MonadEffect, liftEffect)
import Color as C
import Color.Extra as C

import Data.Array as Array
import Data.BinPack.R2.Optional (Bin2)
import Data.BinPack.R2.Optional as R2
import Data.Int (toNumber, floor)
import Data.Number
import Data.List as List
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Maybe as Maybe
import Data.PinBoard (PinBoard)
import Data.PinBoard as PB
import Data.Set (Set)
import Data.Set as Set
import Data.Tuple (fst, snd) as Tuple
import Data.Tuple.Nested ((/\), type (/\))
import Data.Vec2 (Vec2, Pos, Size, (<+>))
import Data.Vec2 as V2
import Data.Foldable (foldr)

import Control.Alternative ((<|>))

import Type.Proxy (Proxy(..))

import Noodle.Node (Node) as Noodle
import Noodle.Node as Node
import Noodle.Patch (Patch) as Noodle
import Noodle.Patch as Patch
import Noodle.Toolkit (Toolkit) as Noodle
import Noodle.Toolkit as Toolkit
import Noodle.Node.Shape (InletId, OutletId)

import App.Emitters as Emitters
import App.Mouse as M
import App.Style (Style, NodeFlow(..), Flags, LinkType(..))
import App.Style as Style
import App.Style.Calculate as Calc
import App.Style.ClassNames as CS
import App.Svg.Extra (translateTo') as HSA
import App.Toolkit.UI (UI)
import App.Toolkit.UI (flagsFor) as UI

import App.Component.Node as NodeC
import App.Component.Link as LinkC
import App.Component.ButtonStrip as BS

import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.Svg.Attributes as HSA
import Halogen.Svg.Elements as HS
import Halogen.Svg.Elements.None as HS

import Web.HTML (window)
import Web.HTML.Window (document)
import Web.UIEvent.MouseEvent as ME

import App.Component.Link as Link
import App.Component.Patch.Mouse as Mouse
import App.Component.Patch.Mouse (Focusable(..)) as Clickable
import App.Component.Patch.Mouse (Clickable(..)) as Clickable
import App.Component.Patch.Mouse (Draggable(..)) as Draggable


type Slot id = forall query. H.Slot query Void id


type Slots = ( node :: NodeC.Slot Node.Id, link :: Link.Slot Int )


_node = Proxy :: Proxy "node"


_link = Proxy :: Proxy "link"


type Input m s d =
    { patch :: Noodle.Patch d
    , toolkit :: Noodle.Toolkit d
    , style :: Style
    , flow :: NodeFlow
    , offset :: Pos
    , ui :: UI m s d
    , area :: Size
    -- , bodyRenderer :: Node.Family -> Maybe (UI.NodeComponent m d)
    }


type State m s d =
    { patch :: Noodle.Patch d
    , toolkit :: Noodle.Toolkit d
    , style :: Style
    , flow :: NodeFlow
    , offset :: Pos
    , buttonStrip :: BS.ButtonStrip Node.Family
    , layout :: Bin2 Number Node.Id
    , pinned :: PinBoard Node.Id
    , mouse :: Mouse.State
    , ui :: UI m s d
    , area :: Size
    }


data Action m s d
    = Initialize
    | Receive (Input m s d)
    | FromNode Node.Id NodeC.Output
    | AddNode Node.Family
    | DetachNode Node.Id
    | PinNode Node.Id Pos
    | Connect Patch.OutletPath Patch.InletPath
    | Disconnect Patch.OutletPath Patch.InletPath
    | HandleMouse H.SubscriptionId ME.MouseEvent -- TODO Split mouse handing in different actions


initialState :: forall m s d. Input m s d -> State m s d
initialState { patch, toolkit, style, flow, offset, ui, area } =
    { patch, toolkit, style, flow
    , offset : offset
    , layout :
        R2.container area
            # addNodesFrom ui style flow patch
    , buttonStrip : BS.make (V2.w area) $ Toolkit.nodeFamilies toolkit
    , pinned : []
    , mouse : Mouse.init
    , ui, area
    }


render :: forall m s d. MonadEffect m => State m s d -> H.ComponentHTML (Action m s d) Slots m
render state =
    HS.g
        []
        [ mouseState
        , nodeButtons
        , existingLinks
        , nodesLayout
        , pinnedNodes
        , whatIsBeingDragged state.mouse
        ]
    where
        flow = state.flow
        mouseState =
            HS.text
                [ HSA.translateTo' $ 500.0 <+> -20.0
                , HSA.fill $ Just $ C.toSvg $ C.white
                ]
                [ HH.text $ show $ state.mouse ]
        assocNode (name /\ pos /\ bounds) =
            state.patch
                # Patch.findNode name
                <#> { name, node : _, x : V2.x pos, y : V2.y pos, w : V2.w bounds, h : V2.h bounds }
        packedNodes'
            = List.catMaybes $ assocNode <$> R2.toList state.layout
        pinnedNodes'
            = Array.catMaybes $ assocNode <$> PB.toArray state.pinned
        nodeButtons
            = HS.g
                [ HSA.classes CS.nodesTabs ]
                $ nodeButton <$> BS.unfold state.buttonStrip
        bsBottomY = V2.h $ BS.size state.buttonStrip
        bsOffset = V2.h' bsBottomY
        --absNodesOffset = bsBottomY
        -- cursorOffset = 0.0 <+> fullButtonHeight
        nodeButton (buttonPos /\ name) =
            HS.g
                [ HSA.classes $ CS.nodeButton name
                , HSA.translateTo' buttonPos
                , HE.onClick \_ -> AddNode name
                ]
                [ HS.rect
                    [ HSA.width $ V2.w BS.buttonSize, HSA.height $ V2.h BS.buttonSize
                    , HSA.fill $ C.toSvg <$> (state.ui.markNode name <|> Just state.style.nodeTab.background)
                    , HSA.stroke $ Just $ C.toSvg state.style.nodeTab.stroke
                    , HSA.strokeWidth 1.0
                    ]
                , HS.text [] [ HH.text $ "+ " <> name ]
                ]
        node' { node, name, x, y, w, h } = -- FIXME: use Vec2
            HS.g
                [ HSA.transform [ HSA.Translate x $ bsBottomY + y ]
                , HSA.classes $ CS.node state.flow name
                ]
                [ HH.slot _node name
                    NodeC.component
                        { node, name
                        , style : state.style, flow : state.flow, ui : state.ui
                        , linksCount : Patch.linksCountAtNode name state.patch
                        }
                    $ FromNode name
                ]
        nodesLayout =
            HS.g [ HSA.classes CS.nodes ] $ map node' $ List.toUnfoldable $ packedNodes' -- Patch.nodes patch
        pinnedNodes =
            HS.g [ HSA.classes CS.nodes ] $ map node' $ pinnedNodes'
        floatingNode pos (name /\ nodeOffset) =
            let
                nodeArea = areaOf state.ui state.style state.flow state.patch name # Maybe.fromMaybe zero
            in case assocNode ( name /\ (pos - nodeOffset - bsOffset - state.offset) /\ nodeArea ) of
                Just n -> node' n
                Nothing -> HS.none
        existingLinks =
            HS.g [] $ closedLink <$> (Array.fromFoldable $ Patch.links state.patch)
        drawLink Straight (x0 /\ y0) (x1 /\ y1) =
            HS.line
                [ HSA.x1 x0, HSA.x2 x1
                , HSA.y1 y0, HSA.y2 y1
                , HSA.strokeWidth 3.0, HSA.stroke $ Just $ C.toSvg C.white
                ] -- TODO: move to `Link` component
        drawLink Curve (x0 /\ y0) (x1 /\ y1) =
            HS.path
                [ HSA.d $ case state.flow of
                            Vertical -> LinkC.bezierByH { x0, y0, x1, y1 }
                            Horizontal -> LinkC.bezierByV { x0, y0, x1, y1 }
                , HSA.strokeWidth 1.5, HSA.stroke $ Just $ C.toSvg C.white
                , HSA.fill $ Just $ C.toSvg $ C.transparent
                ]
        drawLink Pipe (x0 /\ y0) (x1 /\ y1) =
            HS.path
                [ HSA.d $ LinkC.pipeByH { x0, y0, x1, y1 }
                , HSA.strokeWidth 1.5, HSA.stroke $ Just $ C.toSvg C.white
                , HSA.fill $ Just $ C.toSvg $ C.transparent
                ]
        linkEndsPositions (srcNodeName /\ outlet) (dstNodeName /\ inlet) =
            (\outletConnectorPos srcNodePos inletConnectorPos dstNodePos ->
                (srcNodePos + outletConnectorPos)
                /\ (dstNodePos + inletConnectorPos)
            )
                <$> (Patch.findNode srcNodeName state.patch
                        >>= NodeC.outletConnectorPos state.ui state.style state.flow outlet)
                <*> findNodePosition srcNodeName
                <*> (Patch.findNode dstNodeName state.patch
                        >>= NodeC.inletConnectorPos state.ui state.style state.flow inlet)
                <*> findNodePosition dstNodeName
        closedLink (outletPath /\ inletPath) =
            case linkEndsPositions outletPath inletPath of
                Just (outletPos /\ inletPos) ->
                    let
                        x1 /\ y1 = V2.toTuple $ bsOffset + outletPos
                        x2 /\ y2 = V2.toTuple $ bsOffset + inletPos
                    in drawLink state.style.link.type (x1 /\ y1) (x2 /\ y2)
                Nothing -> HS.none
        findNodePosition nodeName =
            (R2.find nodeName state.layout <#> Tuple.fst)
            <|> (PB.find nodeName state.pinned <#> Tuple.fst)
        openLink pos (nodeName /\ outlet) =
            case (/\)
                    <$> (Patch.findNode nodeName state.patch
                            >>= NodeC.outletConnectorPos state.ui state.style state.flow outlet
                        )
                    <*> findNodePosition nodeName of
                Just (outletConnectorPos /\ nodePos) ->
                    let
                        x1 /\ y1 = V2.toTuple $ bsOffset + nodePos + outletConnectorPos
                        x2 /\ y2 = V2.toTuple $ pos - state.offset
                    in drawLink state.style.link.type (x1 /\ y1) (x2 /\ y2)
                Nothing -> HS.none
        whatIsBeingDragged (M.StartDrag pos (offset /\ Draggable.Node node)) =
            HS.none
            --floatingNode pos (node /\ offset)
        whatIsBeingDragged (M.Dragging _ pos (offset /\ Draggable.Node node)) =
            floatingNode pos (node /\ offset)
        whatIsBeingDragged (M.Dragging _ pos (offset /\ Draggable.Link outlet maybeInlet)) =
            openLink pos outlet
        {- whatIsBeingDragged (Mouse.Dragging _ pos (Inlet inlet /\ pos)) =
            HS.none -}
            -- openLink pos outlet
        whatIsBeingDragged _ =
            HS.none


handleAction :: forall output m s d. MonadEffect m => Action m s d -> H.HalogenM (State m s d) (Action m s d) Slots output m Unit
handleAction = case _ of

    Initialize -> do
        document <- H.liftEffect $ document =<< window
        H.subscribe' $ Emitters.mouseDown document <<< HandleMouse
        H.subscribe' $ Emitters.mouseMove document <<< HandleMouse
        H.subscribe' $ Emitters.mouseUp document <<< HandleMouse

    Receive input ->
        H.modify_
            (\state ->
                state
                    { area = input.area
                    , layout = state.layout # R2.reflow' input.area
                    , buttonStrip = state.buttonStrip # BS.reflow (V2.w input.area)
                    }
            )

    AddNode name -> do
        toolkit <- H.gets _.toolkit
        maybeNode <- liftEffect $ Toolkit.spawn name toolkit
        case maybeNode of
            Just node -> do
                H.modify_ -- _ { patch = _.patch # Patch.addNode "sum" newNode }
                    (\state ->
                        let nodeName = Patch.addUniqueNodeId state.patch name
                            nodeArea = NodeC.areaOf state.ui state.style state.flow node
                        in state
                            { patch = state.patch # Patch.addNode nodeName node
                            , layout = R2.packOne state.layout (R2.item nodeArea nodeName)
                                        # Maybe.fromMaybe state.layout
                            }
                    )
            Nothing -> pure unit

    DetachNode nodeId ->
        H.modify_ $ \state ->
            state
            { layout =
                state.layout # R2.abandon nodeId
            , pinned =
                state.pinned # PB.unpin nodeId
            }

    PinNode nodeId pos ->
        H.modify_ $ \state ->
        let
            nodeArea =
                areaOf state.ui state.style state.flow state.patch nodeId
                    # Maybe.fromMaybe zero
        in
            state
                { pinned =
                    state.pinned # PB.pin (pos - state.offset) nodeArea nodeId
                }

    Connect outletPath inletPath -> do
        state <- H.get
        nextPatch  <- liftEffect $ Patch.disconnect outletPath inletPath state.patch
        nextPatch' <- liftEffect $ Patch.connect outletPath inletPath nextPatch
        H.modify_ (_ { patch = nextPatch' })

    Disconnect outletPath inletPath -> do
        state <- H.get
        nextPatch <- liftEffect $ Patch.disconnect outletPath inletPath state.patch
        H.modify_ (_ { patch = nextPatch })

    FromNode nodeId (NodeC.Replace family) ->
        pure unit

    FromNode nodeId NodeC.Remove -> do
        state <- H.get
        nextPatch <- liftEffect $ Patch.removeNode nodeId state.patch
        H.modify_ (_ { patch = nextPatch })

    HandleMouse _ mouseEvent -> do
        state <- H.get
        let
            bsOffset = V2.zh $ BS.size state.buttonStrip
            mouseOffset = state.offset + bsOffset
            nextMouse
                = state.mouse
                    # Mouse.apply
                            (flip (-) mouseOffset
                            >>> findSubjectUnderPos state
                            )
                    (clickableToDraggable state.patch)
                    (draggableToClickable state.patch)
                    mouseEvent
        H.modify_ (_ { mouse = nextMouse })
        case nextMouse of
            M.StartDrag _ (_ /\ Draggable.Node nodeId) ->
                handleAction $ DetachNode nodeId
            M.StartDrag _ (_ /\ Draggable.Link outlet (Just inlet)) ->
                handleAction $ Disconnect outlet inlet
            M.DropAt pos (offset /\ Draggable.Node nodeId) ->
                handleAction $ PinNode nodeId $ pos - bsOffset - offset
            M.DropAt pos (_ /\ Draggable.Link outlet Nothing) ->
                case findSubjectUnderPos state $ pos - mouseOffset of
                    Just (_ /\ Clickable.Inlet inlet) -> do
                        handleAction $ Connect outlet inlet
                    _ ->
                        pure unit
            _ ->
                pure unit

    where

        clickableToDraggable :: Noodle.Patch d -> Pos -> Mouse.Clickable -> Maybe Mouse.Draggable
        clickableToDraggable patch _ (Clickable.Header nodeId) = Just $ Draggable.Node nodeId
        clickableToDraggable patch _ (Clickable.Inlet inletPath) =
            patch
                 #  topLinkAt inletPath
                <#> (\outletPath -> Draggable.Link outletPath $ Just inletPath)
        clickableToDraggable patch _ (Clickable.Outlet outletPath) = Just $ Draggable.Link outletPath Nothing

        draggableToClickable :: Noodle.Patch d -> Pos -> Mouse.Draggable -> Maybe Mouse.Clickable
        draggableToClickable _ _ _ = Nothing

        liftSubject :: Node.Id -> NodeC.WhereInside -> Mouse.Clickable
        liftSubject nodeId NodeC.Header = Clickable.Header nodeId
        liftSubject nodeId (NodeC.Inlet inletId) = Clickable.Inlet $ nodeId /\ inletId
        liftSubject nodeId (NodeC.Outlet outletId) = Clickable.Outlet $ nodeId /\ outletId

        topLinkAt :: Patch.InletPath -> Noodle.Patch d -> Maybe Patch.OutletPath
        topLinkAt inletPath patch =
            patch
                 #  Patch.linksLeadingTo inletPath
                <#> Tuple.fst
                 #  Array.head

        findSubjectUnderPos :: State m s d -> Pos -> Maybe (Pos /\ Mouse.Clickable)
        findSubjectUnderPos state pos =
            (findNodeInLayout state pos <|> findNodeInPinned state pos)
                >>= \(nodeId /\ pos') ->
                        state.patch
                             #  Patch.findNode nodeId
                            >>= flip (whereInsideNode state) pos'
                            <#> liftSubject nodeId
                            <#> (/\) pos'

        whereInsideNode :: State m s d -> Noodle.Node d -> Pos -> Maybe NodeC.WhereInside
        whereInsideNode state =
            NodeC.whereInside state.ui state.style state.flow

        findNodeInLayout state =
            R2.sample state.layout

        findNodeInPinned state =
            flip PB.search state.pinned


component :: forall query output m s d. MonadEffect m => H.Component query (Input m s d) output m
component =
    H.mkComponent
        { initialState
        , render
        , eval:
            H.mkEval H.defaultEval
                { handleAction = handleAction
                , receive = Just <<< Receive
                , initialize = Just Initialize
                }
        }


addNodesFrom :: forall m s d. UI m s d -> Style -> NodeFlow -> Noodle.Patch d -> Bin2 Number Node.Id -> Bin2 Number Node.Id
addNodesFrom ui style flow patch layout =
    Patch.nodes patch
        # foldr
            (\(nodeName /\ node) layout' ->
                R2.packOne layout' (R2.item (NodeC.areaOf ui style flow node) nodeName)
                    # Maybe.fromMaybe layout'
            )
            layout


areaOf :: forall m s d. UI m s d -> Style -> NodeFlow -> Noodle.Patch d -> Node.Id -> Maybe Size
areaOf ui style flow patch nodeId =
    patch
        # Patch.findNode nodeId
        # map (NodeC.areaOf ui style flow)
