module Hydra.Toolkit where


import Prelude ((<>), ($), (<$>))

import Noodle.Toolkit (Toolkit)
import Noodle.Toolkit (make) as T

import Data.Tuple.Nested ((/\))


import Hydra (Hydra)
import Hydra (default) as Hydra

import Hydra.Toolkit.Node as Node
import Hydra.Toolkit.Generate as Gen


toolkit :: Toolkit Hydra
toolkit =
  T.make Hydra.default $
    [ "num" /\ Node.number
    , "time" /\ Node.time
    , "mouse" /\ Node.mouse
    , "seq" /\ Node.seq
    ] <> (Gen.generate <$> Gen.all) <>
    [ "out" /\ Node.out
    ]
