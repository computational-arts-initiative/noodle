module Hydra.Component.Node.Palette where


import Prelude

import Effect.Class (class MonadEffect)

-- import Data.String.Read (read)
--import Data.Parse
import Data.Maybe (fromMaybe)
import Data.Array ((:))
import Data.Array as Array
import Data.Map as Map
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\), type (/\))
import Data.Vec ((!!))
import Data.Typelevel.Num.Reps (d0, d1, d2)

import App.Toolkit.UI as UI
import App.Emitters as E

import JetBrains.Palettes as P

import Noodle.Node (Node)
import Noodle.Node as Node

import Hydra (Hydra, Value(..))
import Hydra as Hydra
import Hydra.Extract as HydraE
import Hydra.Component.Input as Input

import Halogen as H
import Halogen.Svg.Elements as HS
import Halogen.Svg.Elements.None as HS
import Halogen.Svg.Attributes as HSA
import Data.Color as C


type State = Mode /\ P.PaletteId


data Mode
    = Modifier
    | Solid


data Action
    = Change P.PaletteId


bodyWidth = 110.0 -- FIXME: pass from outside


-- defaultPalette :: Hydra.Color
-- defaultPalette = Hydra.Color { r = Num


initialState :: Mode -> UI.NodeInput Hydra -> State
initialState mode _ =
    mode /\ "JetBrains"


render :: forall m. State -> H.ComponentHTML Action () m
render (_ /\ paletteId) =
    HS.g
        []
        [ (HS.g [] $ Array.mapWithIndex colorRect colors)
        , Input.button $ Change "PyCharm"
        ]
    where
        colors = P.toArray palette
        palette = fromMaybe P.default $ Map.lookup paletteId P.palettes
        colorsCount = Array.length colors
        colorRectWidth = bodyWidth / toNumber colorsCount
        colorRect i color =
            HS.g
                [ ]
                [ HS.rect
                    [ HSA.x $ colorRectWidth * toNumber i
                    , HSA.y 0.0
                    , HSA.width colorRectWidth
                    , HSA.height 55.0 -- FIXME
                    , HSA.fill $ Just color
                    ]
                ]


handleAction :: forall m. MonadEffect m => Action -> H.HalogenM State Action () (UI.NodeOutput Hydra) m Unit
handleAction = case _ of
    Change paletteId -> do
        mode /\ _ <- H.get
        H.modify_ (\(mode /\ _) -> mode /\ paletteId)
        let palette = fromMaybe P.default $ Map.lookup paletteId P.palettes
        H.raise $ UI.SendToInlet "palette" $ case mode of
            Modifier -> Hydra.justModifier $ Hydra.color $ P.toColorMod palette
            Solid -> Hydra.hydraOf $ Hydra.entityOf $ P.toSolidSource palette


component :: forall m. MonadEffect m => Mode -> UI.NodeComponent m Hydra
component mode =
    H.mkComponent
        { initialState : initialState mode
        , render
        , eval: H.mkEval H.defaultEval { handleAction = handleAction }
        }