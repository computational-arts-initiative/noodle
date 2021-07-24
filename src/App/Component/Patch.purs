module App.Component.Patch where


import Prelude

import Debug as Debug

import Effect.Class (class MonadEffect, liftEffect)

import Data.Array ((..))
import Data.Array as Array
import Data.Bifunctor (bimap)
import Data.BinPack.R2.Optional (Bin2)
import Data.BinPack.R2.Optional as R2
import Data.List as List
import Data.Map as Map
import Data.Map.Extra (type (/->))
import Data.Maybe (Maybe(..))
import Data.Maybe as Maybe
import Data.PinBoard (PinBoard)
import Data.PinBoard as PB
import Data.Set as Set
import Data.Tuple (curry, uncurry, fst)
import Data.Tuple.Nested ((/\), type (/\))
import Data.Unit (Unit, unit)
import Data.Vec2 (Vec2, Pos, Size, (<+>))
import Data.Vec2 as V2

import Control.Alternative ((<|>))

import Type.Proxy (Proxy(..))

import Noodle.Node (Node) as Noodle
import Noodle.Node as Node
import Noodle.Patch (Patch) as Noodle
import Noodle.Patch as Patch
import Noodle.Toolkit (Toolkit) as Noodle
import Noodle.Toolkit as Toolkit

import App.Component.Node as NodeC
import App.Emitters as Emitters
import App.Mouse as Mouse
import App.Style (Style, NodeFlow(..))
import App.Style as Style
import App.Style.Calculate as Calc
import App.Style.ClassNames as CS

import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.Svg.Attributes as HSA
import Halogen.Svg.Elements as HS

import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.HTMLFieldSetElement (name)
import Web.HTML.Window (document)
import Web.HTML.Window as Window
import Web.UIEvent.MouseEvent as ME
import Web.UIEvent.MouseEvent.EventTypes as MET


type Slot id = forall query. H.Slot query Void id


type Slots = ( node :: NodeC.Slot String )


_node = Proxy :: Proxy "node"


data Subject
    = Node String
    | Inlet (String /\ String)
    | Outlet (String /\ String)


type Input d =
    { patch :: Noodle.Patch d
    , toolkit :: Noodle.Toolkit d
    , style :: Style
    , flow :: NodeFlow
    , offset :: Pos
    }


type State d =
    { patch :: Noodle.Patch d
    , toolkit :: Noodle.Toolkit d
    , style :: Style
    , flow :: NodeFlow
    , offset :: Pos
    , layout :: Bin2 Number String
    , pinned :: PinBoard String
    , mouse :: Mouse.State (Subject /\ Pos)
    }


data Action d
    = Initialize
    | Receive (Input d)
    | AddNode String
    | HandleMouse H.SubscriptionId ME.MouseEvent -- TODO Split mouse handing in different actions


initialState :: forall d. Input d -> State d
initialState { patch, toolkit, style, flow, offset } =
    { patch, toolkit, style, flow
    , offset : offset + (V2.h' $ tabHeight + tabVertPadding)
    , layout : R2.container $ 1500.0 <+> 900.0
    , pinned : []
    , mouse : Mouse.init
    }


tabHeight = 20.0
tabVertPadding = 15.0
tabHorzPadding = 5.0
tabLength = 60.0


render :: forall d m. State d -> H.ComponentHTML (Action d) Slots m
render state =
    HS.g
        []
        [ mouseState
        , nodeButtons
        , nodesLayout
        , pinnedNodes
        , whatIsBeingDragged state.mouse
        ]
    where
        mouseState =
            HS.text
                [ HSA.transform [ HSA.Translate 100.0 0.0 ]
                , HSA.fill $ Just $ Style.white
                ]
                [ HH.text $ show $ state.mouse ]
        colors = state.style.colors
        assocNode (name /\ pos /\ bounds) =
            state.patch
                # Patch.findNode name
                <#> { name, node : _, x : V2.x pos, y : V2.y pos, w : V2.w bounds, h : V2.h bounds }
        packedNodes'
            = List.catMaybes $ assocNode <$> R2.toList state.layout
        pinnedNodes'
            = Array.catMaybes $ assocNode <$> PB.toArray state.pinned
        nodeButtons = HS.g [ HSA.classes CS.nodesTabs ] $ nodeButton <$> (Set.toUnfoldable $ Toolkit.nodeNames state.toolkit)
        nodeButton name =
            HS.g
                [ HSA.classes $ CS.nodeButton name
                , HSA.transform [ HSA.Translate tabHorzPadding 0.0 ]
                , HE.onClick \_ -> AddNode name
                ]
                [ HS.rect
                    [ HSA.width tabLength, HSA.height tabHeight
                    , HSA.fill $ Just colors.nodeTabBackground
                    , HSA.stroke $ Just colors.nodeTabStroke
                    , HSA.strokeWidth 1.0
                    ]
                , HS.text [] [ HH.text $ "+ " <> name ]
                ]
        node' { node, name, x, y, w, h } = -- FIXME: use Vec2
            HS.g
                [ HSA.transform [ HSA.Translate x $ tabHeight + tabVertPadding + y ]
                , HSA.classes $ CS.node state.flow name
                ]
                [ HH.slot _node name
                    NodeC.component { node, name, style : state.style, flow : state.flow }
                    absurd
                ]
        nodesLayout =
            HS.g [ HSA.classes CS.nodes ] $ map node' $ List.toUnfoldable $ packedNodes' -- Patch.nodes patch
        pinnedNodes =
            HS.g [ HSA.classes CS.nodes ] $ map node' $ pinnedNodes'
        floatingNode pos (name /\ nodeOffset) =
            let
                bounds = boundsOf' state name # Maybe.fromMaybe zero
            in case assocNode ( name /\ (pos - nodeOffset - state.offset) /\ bounds ) of
                Just n -> node' n
                Nothing -> HS.g [] []
        whatIsBeingDragged (Mouse.StartDrag pos (Node node /\ offset)) =
            floatingNode pos (node /\ offset)
        whatIsBeingDragged (Mouse.Dragging _ pos (Node node /\ offset)) =
            floatingNode pos (node /\ offset)
        whatIsBeingDragged _ =
            HS.g [] []



handleAction :: forall output m d. MonadEffect m => Action d -> H.HalogenM (State d) (Action d) Slots output m Unit
handleAction = case _ of

    Initialize -> do
        document <- H.liftEffect $ document =<< window
        H.subscribe' $ Emitters.mouseDown document <<< HandleMouse
        H.subscribe' $ Emitters.mouseMove document <<< HandleMouse
        H.subscribe' $ Emitters.mouseUp document <<< HandleMouse

    Receive _ ->
        pure unit
        --H.modify_ (\state -> state { patch = input.patch })

    AddNode name -> do
        toolkit <- H.gets _.toolkit
        case Toolkit.spawn name toolkit of
            Just newNode' -> do
                newNode <- liftEffect newNode'
                H.modify_ -- _ { patch = _.patch # Patch.addNode "sum" newNode }
                    (\state ->
                        let nodeName = makeUniqueName state.patch name
                            bounds = boundsOf state newNode
                        in state
                            { patch = state.patch # Patch.addNode nodeName newNode
                            , layout = R2.packOne state.layout (R2.item bounds nodeName)
                                        # Maybe.fromMaybe state.layout
                            }
                    )
            Nothing -> pure unit
        where makeUniqueName patch name = name <> "-" <> (show $ Patch.nodesCount patch + 1)

    HandleMouse _ mouseEvent -> do
        state <- H.get
        let
            nextMouse
                = state.mouse
                    # Mouse.apply
                            (flip (-) state.offset
                            >>> findDragSubject state
                            )
                    mouseEvent
        H.modify_ (_ { mouse = nextMouse })
        H.modify_ $ \state' ->
            case nextMouse of
                Mouse.StartDrag _ (Node n /\ _) ->
                    state'
                        { layout =
                            state.layout # R2.abandon n
                        , pinned =
                            state.pinned # PB.unpin n
                        }
                Mouse.DropAt pos (Node n /\ offset) ->
                    let
                        bounds =
                            boundsOf' state n
                                # Maybe.fromMaybe zero
                    in
                        state'
                            { pinned =
                                state.pinned # PB.pin (pos - offset - state.offset) bounds n
                            }
                _ ->
                    state'
        case nextMouse of
            Mouse.DropAt pos (Outlet outlet /\ _) ->
                case findDragSubject state $ pos - state.offset of
                    Just (Inlet inlet /\ _) -> do
                        nextPatch <- liftEffect $ Patch.connect outlet inlet state.patch
                        H.modify_ (_ { patch = nextPatch })
                    _ ->
                        pure unit
            _ ->
                pure unit

    where
        findDragSubject state pos =
            (findNodeInLayout state pos <|> findNodeInPinned state pos)
                >>= whereInsideNode state
        whereInsideNode :: State d -> (String /\ Pos) -> Maybe (Subject /\ Pos)
        whereInsideNode state (nodeName /\ pos) =
            let
                flow = state.flow
                units = state.style.units flow
            in -- Just $ Node nodeName /\ inPos {-
            if V2.inside'
                (pos - Calc.namePos units flow)
                (Calc.namePlateSize units flow) then
                Just $ Node nodeName /\ pos
            else
                state.patch
                # Patch.findNode nodeName
                >>= \node ->
                    let inlets = Node.inlets node <#> fst # Array.mapWithIndex (/\)
                        outlets = Node.outlets node <#> fst # Array.mapWithIndex (/\)
                        isInSlot sl fn (idx /\ slotName) =
                            if V2.inside pos (fn idx /\ Calc.slotSize units flow)
                                then Just $ sl (nodeName /\ slotName) /\ pos
                                else Nothing
                        testInlets = Array.findMap (isInSlot Inlet $ Calc.inletRectPos units flow) inlets
                        testOutlets = Array.findMap (isInSlot Outlet $ Calc.outletRectPos units flow) outlets
                    in testOutlets <|> testInlets
        findNodeInLayout state =
            R2.sample state.layout
        findNodeInPinned state =
            flip PB.search state.pinned


component :: forall query output m d. MonadEffect m => H.Component query (Input d) output m
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


boundsOf :: forall d x. { flow :: NodeFlow, style :: Style | x } -> Noodle.Node d -> Size
boundsOf state =
    let
        flow = state.flow
        units = state.style.units
    in
        Calc.nodeBounds (units flow) flow


boundsOf' :: forall d x. { flow :: NodeFlow, style :: Style, patch :: Noodle.Patch d | x } -> String -> Maybe Size
boundsOf' state name =
    let
        flow = state.flow
        units = state.style.units
    in
        state.patch
            # Patch.findNode name
            # map (Calc.nodeBounds (units flow) flow)



instance showSubject :: Show Subject where
    show (Node n) = "node " <> n
    show (Inlet path) = "inlet " <> show path
    show (Outlet path) = "outlet " <> show path