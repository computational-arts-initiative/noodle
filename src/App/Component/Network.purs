module App.Component.Network where

import Prelude

import Type.Proxy (Proxy(..))

import Effect.Class (class MonadEffect)
import Effect.Aff.Class (class MonadAff)

import Color.Extra as C

import Data.Maybe (Maybe(..))
import Data.Int (toNumber)
import Data.Tuple as Tuple
import Data.Vec2 ((<+>), Size)
import Data.Vec2 as V2
import Data.NonEmpty (NonEmpty, singleton) as NE

import Noodle.Network (Network) as Noodle
import Noodle.Network as Network
import Noodle.Patch as Patch
import Noodle.Toolkit (Toolkit) as Noodle

import App.Style (Style, NodeFlow)
import App.Style.ClassNames as CS
import App.Component.Patch as PatchC
import App.Emitters as Emitters
import App.Toolkit.UI (UI)
import App.Toolkit.UI as UI
import App.Svg.Extra as HSA

import Halogen as H
import Halogen.HTML as HH
import Halogen.Svg.Elements as HS
import Halogen.Svg.Elements.None as HS
import Halogen.Svg.Attributes as HSA
import Halogen.HTML.CSS as CSS
import CSS as CSS

import Web.HTML (window)
import Web.HTML.Window as Window


type Slots d =
    ( patch :: PatchC.Slot Unit
    , background :: UI.BgSlot d Unit
    )


_patch = Proxy :: Proxy "patch"

_background = Proxy :: Proxy "background"


type Input m d =
    { network :: Noodle.Network d
    , toolkit :: Noodle.Toolkit d
    , style :: Style
    , flow :: NodeFlow
    , currentPatch :: Maybe Patch.Id
    , ui :: UI m d
    }


type State m d =
    { network :: Noodle.Network d
    , toolkit :: Noodle.Toolkit d
    , currentPatch :: Maybe Patch.Id
    , windowSize :: Size
    , currentFrame :: Number
    , style :: Style
    , flow :: NodeFlow
    , ui :: UI m d
    }


data Action
    = Initialize
    | SelectPatch Patch.Id
    | AnimationFrame H.SubscriptionId Number
    | WindowResize H.SubscriptionId { w :: Int, h :: Int }
    -- | HandlePatch (PatchC.Action d)


initialState :: forall m d. Input m d -> State m d
initialState { network, toolkit, style, flow, currentPatch, ui } =
    { network, toolkit, style, flow, ui
    , currentPatch
    , windowSize : 1000.0 <+> 1000.0
    , currentFrame : 0.0
    }


render :: forall d m. MonadEffect m => State m d -> H.ComponentHTML Action (Slots d) m
render (s@{ network, toolkit, style, flow }) =
    HH.div
        [ CSS.style $ do
            CSS.fontFamily style.font.family $ NE.singleton CSS.sansSerif
            CSS.fontSize $ CSS.pt style.font.size
        ]
        [ HS.svg
            [ HSA.width $ V2.w s.windowSize, HSA.height $ V2.h s.windowSize
            , HSA.id "noodle"
            ]
            [ background
            , curFrame
            , patchesTabs
            , maybeCurrent $ (flip Network.patch $ network) =<< s.currentPatch
            ]
        ]
    where
        curFrame =
            HS.text
                [ HSA.translateTo' $ 200.0 <+> 0.0 ]
                [ HH.text $ show s.currentFrame ]
        tabHeight = 20.0
        tabPadding = 4.0
        tabLength = 60.0
        patchOffset = 0.0 <+> (tabHeight + tabPadding)
        background =
            HS.g
                []
                [ HS.rect
                    [ HSA.width $ V2.w s.windowSize, HSA.height $ V2.h s.windowSize
                    , HSA.fill $ Just $ C.toSvg style.bg.fill
                    ]
                , case s.ui.background of
                    Nothing ->
                        HS.none
                    Just userBgComp ->
                        HH.slot _background unit userBgComp { network, size : s.windowSize } absurd
                ]
        patchesTabs = HS.g [ HSA.classes CS.patchesTabs ] (patchTab <$> Tuple.fst <$> Network.patches network)
        patchTab label =
            HS.g
                [ HSA.classes $ CS.patchTab label ]
                [ HS.rect [ HSA.width tabLength, HSA.height tabHeight
                , HSA.fill $ Just $ C.toSvg style.patchTab.background
                , HSA.stroke $ Just $ C.toSvg style.patchTab.stroke
                , HSA.strokeWidth 1.0
                ]
                , HS.text
                    [ HSA.translateTo' $ 3.0 <+> 3.0 ]
                    [ HH.text label ]
                ]
        maybeCurrent (Just patch) =
            HS.g
                [ HSA.translateTo' $ 0.0 <+> tabHeight + tabPadding ]
                [ HH.slot _patch unit
                    PatchC.component
                    { patch, toolkit, style, flow, offset : patchOffset, ui : s.ui, area : s.windowSize - patchOffset }
                    absurd
                ]
        maybeCurrent Nothing =
            HS.text
                [ HSA.translateTo' $ 0.0 <+> tabHeight + tabPadding ]
                [ HH.text "No patch selected" ]


handleAction :: forall output m d. MonadAff m => MonadEffect m => Action -> H.HalogenM (State m d) Action (Slots d) output m Unit
handleAction = case _ of
    Initialize -> do
        innerWidth <- H.liftEffect $ Window.innerWidth =<< window
        innerHeight <- H.liftEffect $ Window.innerHeight =<< window
        H.modify_ _ { windowSize = toNumber innerWidth <+> toNumber innerHeight }
        -- pure unit
        {- animFrame <- H.liftEffect Emitters.animationFrame
        H.subscribe' $ \sid -> AnimationFrame sid <$> animFrame -}
        windowResize <- H.liftEffect Emitters.windowDimensions
        H.subscribe' $ \sid -> WindowResize sid <$> windowResize
    SelectPatch _ ->
        H.modify_ \state -> state
    -- HandlePatch _ ->
    --     H.modify_ \state -> state
    AnimationFrame _ time ->
        H.modify_ \state -> state
            { currentFrame = time }
    WindowResize _ { w, h } ->
        H.modify_ \state -> state
            { windowSize = toNumber w <+> toNumber h }


component :: forall query output m d. MonadAff m => MonadEffect m => H.Component query (Input m d) output m
component =
    H.mkComponent
        { initialState
        , render
        , eval: H.mkEval H.defaultEval
            { handleAction = handleAction
            , initialize = Just Initialize
            }
        }