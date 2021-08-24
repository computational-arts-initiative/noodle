module Hydra.UI where

import Prelude (($), (<#>), const)

import Data.Maybe (Maybe(..))
import Effect.Class (class MonadEffect)

import Hydra (Hydra)
import Hydra.Toolkit.Generate as Gen
import Hydra.Toolkit.Generate (Kind(..))

import Hydra.Component.Background as BG
import Hydra.Component.Node.Num as NumNode
import Hydra.Component.Node.Osc as OscNode
import Hydra.Component.Node.Color as ColorNode
import Hydra.Component.Node.Seq as SeqNode
import Hydra.Component.Node.Palette as PaletteNode

import Noodle.Node as Node
import Noodle.Channel.Shape as Channel

import App.Toolkit.UI as UI
import App.Toolkit.UI (UI)
import App.Style as Style
import Data.Color (Color)
import Data.Color as Color


ui :: forall m. MonadEffect m => UI m Hydra
ui =
    { background, node, markNode, markChannel
    , flags :
        \family ->
            { customBody : hasCustomBody family
            , hasTitle : hasTitle family
            , hasRemoveButton : true
            }
    }


hasTitle :: Node.Family -> Boolean
hasTitle _ = true


hasCustomBody :: Node.Family -> Boolean
hasCustomBody "num" = true
hasCustomBody "osc" = true
hasCustomBody "color" = true
hasCustomBody "seq" = true
hasCustomBody "palette" = true
hasCustomBody _ = false


background :: forall m. MonadEffect m => Maybe (UI.BgComponent m Hydra)
background = Just BG.component


node :: forall m. MonadEffect m => Node.Family -> Maybe (UI.NodeComponent m Hydra)
node "num"     = Just $ NumNode.component
node "osc"     = Just $ OscNode.component
node "color"   = Just $ ColorNode.component
node "seq"     = Just $ SeqNode.component
node "palette" = Just $ PaletteNode.component
node _ = Nothing


-- #404E4D -- 64 78 77
-- #63595C -- 99 89 92
-- #646881 -- 100 104 129
-- #62BEC1 -- 98 190 193
-- #5AD2F4 -- 90 210 244
-- #F7CE5B -- 247 206 91
-- #F7B05B -- 247 176 91
-- #E3879E -- 227 135 158
-- #FEC0CE -- 254 192 206
-- #DDE392 -- 221 227 146


-- source : hsl(20, 100%, 70%) -- 255 153 102 -- #FF9966
-- geometry : hsl(80, 100%, 70%) -- 204 255 102 -- #CCFF66
-- color : hsl(140, 100%, 70%) -- 102 255 153 -- #66FF99
-- blend : hsl(200, 100%, 70%) -- 102 204 255 -- #66CCFF
-- modulate : hsl(260, 100%, 70%) -- 153 102 255 -- #9966FF


valueColor = Color.rgb 255 255 255 :: Color
entityColor = Color.rgb 98 190 193 :: Color
outColor = Color.rgb 221 227 146 :: Color


sourceColor = Color.rgb 255 153 102 :: Color
geomColor = Color.rgb 204 255 102 :: Color
colorColor = Color.rgb 102 255 153 :: Color
blendColor = Color.rgb 102 204 255 :: Color
modColor = Color.rgb 153 102 255 :: Color


isValueNode :: Node.Family -> Boolean
isValueNode "num" = true
isValueNode "time" = true
isValueNode "mouse" = true
isValueNode "seq" = true
isValueNode _ = false


markNode :: Node.Family -> Maybe Color
markNode family =
    if isValueNode family
        then Just $ Color.rgb 255 255 255
        else Gen.ofKind family <#> markByKind
    where
        markByKind Source = sourceColor
        markByKind Geom = geomColor
        markByKind Color = colorColor
        markByKind Blend = blendColor
        markByKind Mod = modColor


markChannel :: Channel.Id -> Maybe Color
markChannel "value" = Just valueColor
markChannel "entity" = Just entityColor
markChannel "out" = Just outColor
markChannel _ = Nothing