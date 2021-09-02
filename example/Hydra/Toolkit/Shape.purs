module Hydra.Toolkit.Shape where


import Prelude (($))

import Hydra (Hydra(..), Value(..), Modifier)
import Hydra as Hydra

import Noodle.Channel.Shape (Shape')
import Noodle.Channel.Shape as Channel


value :: Shape' Hydra
value =
  Channel.shapeBy "value" None Hydra.isValue


texture :: Shape' Hydra
texture =
  Channel.shapeBy "texture" None Hydra.isTexture


modifier :: Shape' Hydra
modifier =
  Channel.shapeBy "modifier" None Hydra.isModifier


out :: Shape' Hydra
out =
  Channel.shapeBy "out" None Hydra.isOut