module Noodle.Toolkit
  ( Toolkit(..)
  , empty
  , nodeFamilies
  , spawn, spawn'
  , register, register'
  )
  where


import Prelude ((<<<), (#), map, ($), unit, Unit)

import Effect (Effect)
import Effect.Aff (Aff)

import Data.Map as Map
import Data.Map.Extra (type (/->))
import Data.Tuple.Nested (type (/\))
import Data.Maybe (Maybe)
import Data.Set (Set)
import Data.Traversable (sequence)

import Noodle.Node (Node, NodeFn)
import Noodle.Node as Node
import Noodle.Channel as Channel
import Noodle.Fn.Stateful (make', name) as Fn


--type Toolkit d = Toolkit' Unit d


data Toolkit state d = Toolkit d (Node.Family /-> NodeFn state d)



-- make :: forall d. d -> Array (Node.Family /\ Def d) -> Toolkit d
-- make def = Toolkit def <<< Map.fromFoldable


empty :: forall state d. d -> Toolkit state d
empty def = Toolkit def $ Map.empty


register
    :: forall state d
     . Toolkit state d
    -> Node.Family
    -> Array (Node.InletId /\ Channel.Def d)
    -> Array (Node.OutletId /\ Channel.Def d)
    -> Node.NodeProcess state d
    -> Toolkit state d
register tk family inlets outlets process =
  register' tk $ Fn.make' family inlets outlets process


register' :: forall state d. Toolkit state d -> NodeFn state d -> Toolkit state d
register' (Toolkit def fns) fn =
  Toolkit def $ Map.insert (Fn.name fn) fn $ fns


spawn :: forall d. Node.Family -> Toolkit Unit d -> Effect (Maybe (Node Unit d))
spawn family = spawn' family unit


spawn' :: forall state d. Node.Family -> state -> Toolkit state d -> Effect (Maybe (Node state d))
spawn' family state (Toolkit def nodeDefs) =
    nodeDefs
        # Map.lookup family
        # map (Node.make' def)
        # sequence


nodeFamilies :: forall state d. Toolkit state d -> Set Node.Family
nodeFamilies (Toolkit _ nodeDefs) =
    nodeDefs # Map.keys