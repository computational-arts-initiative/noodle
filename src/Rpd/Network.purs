module Rpd.Network
    ( Network(..)
    , Patch(..)
    , Node(..)
    , Inlet(..)
    , Outlet(..)
    , Link(..)
    , Entity(..)
    , InletFlow(..), OutletFlow(..)
    , InletsFlow(..), OutletsFlow(..)
    , PushToInlet(..), PushToOutlet(..)
    , PushToInlets(..), PushToOutlets(..)
    -- FIXME: do not expose constructors, provide all the optics as getters
    , empty
    ) where


import Prelude (class Eq, (==), class Show, show, (<>))

import Data.Map as Map
import Data.Sequence as Seq
import Data.Sequence (Seq)

import Data.Tuple.Nested ((/\), type (/\))

import Rpd.Path as Path
import Rpd.Path (Path)
import Rpd.UUID (UUID)
import Rpd.UUID as UUID
import Rpd.Util (type (/->), Canceler, Flow, PushF)
import Rpd.Process (ProcessF)


-- FIXME: UUID is internal and so should not be passed, I suppose.
--        I'll leave it here temporarily just for the debug purpose.
data InletFlow d = InletFlow (Flow d)
data InletsFlow d = InletsFlow (Flow (Path.ToInlet /\ UUID.ToInlet /\ d))
data PushToInlet d = PushToInlet (PushF d)
data PushToInlets d = PushToInlets (PushF (Path.ToInlet /\ UUID.ToInlet /\ d))
data OutletFlow d = OutletFlow (Flow d)
data OutletsFlow d = OutletsFlow (Flow (Path.ToOutlet /\ UUID.ToOutlet /\ d))
        -- FIXME: Flow (Maybe OutletInNode /\ d)
data PushToOutlet d = PushToOutlet (PushF d)
data PushToOutlets d = PushToOutlets (PushF (Path.ToOutlet /\ UUID.ToOutlet /\ d))
        -- FIXME: PushF (Maybe OutletInNode /\ d)


-- TODO: Make `Entity` a type kind?
data Entity d c n
    = PatchEntity (Patch d c n)
    | NodeEntity (Node d n)
    | InletEntity (Inlet d c)
    | OutletEntity (Outlet d c)
    | LinkEntity Link


data Network d c n =
    Network
        { name :: String
        , patches :: Seq UUID.ToPatch
        , registry :: UUID.Tagged /-> Entity d c n
        -- , pathToId :: Path /-> Set UUID
        , pathToId :: Path /-> UUID.Tagged
        , cancelers :: UUID /-> Array Canceler
        -- TODO: store the toolkit here
            -- { nodes :: UUID.ToNode /-> Array Canceler
            -- , inlets :: UUID.ToInlet /-> Array Canceler
            -- , outlets :: UUID.ToOutlet /-> Array Canceler
            -- , links :: UUID.ToLink /-> Array Canceler
            -- }
        }
data Patch d c n =
    Patch
        UUID.ToPatch
        Path.ToPatch
        { nodes :: Seq UUID.ToNode
        , links :: Seq UUID.ToLink
        }
data Node d n =
    Node
        UUID.ToNode
        Path.ToNode
        n
        (ProcessF d)
        { inlets :: Seq UUID.ToInlet
        , outlets :: Seq UUID.ToOutlet
        , inletsFlow :: InletsFlow d
        , outletsFlow :: OutletsFlow d
        , pushToInlets :: PushToInlets d
        , pushToOutlets :: PushToOutlets d
        }
data Inlet d c =
    Inlet
        UUID.ToInlet
        Path.ToInlet
        c
        { flow :: InletFlow d
        , push :: PushToInlet d
        }
data Outlet d c =
    Outlet
        UUID.ToOutlet
        Path.ToOutlet
        c
        { flow :: OutletFlow d
        , push :: PushToOutlet d
        }
data Link =
    Link
        UUID.ToLink
        { outlet :: UUID.ToOutlet
        , inlet :: UUID.ToInlet
        }


empty :: forall d c n. String -> Network d c n
empty networkName =
    Network
        { name : networkName
        , patches : Seq.empty
        , registry : Map.empty
        , pathToId : Map.empty
        , cancelers : Map.empty
            -- { nodes : Map.empty
            -- , inlets : Map.empty
            -- , outlets : Map.empty
            -- , links : Map.empty
            -- }
        }


instance eqPatch :: Eq (Patch d c n) where
    eq (Patch pidA _ _) (Patch pidB _ _) = (pidA == pidB)

instance eqNode :: Eq (Node d n) where
    eq (Node nidA _ _ _ _) (Node nidB _ _ _ _) = (nidA == nidB)

instance eqInlet :: Eq (Inlet d c) where
    eq (Inlet iidA _ _ _) (Inlet iidB _ _ _) = (iidA == iidB)

instance eqOutlet :: Eq (Outlet d c) where
    eq (Outlet oidA _ _ _) (Outlet oidB _ _ _) = (oidA == oidB)

instance eqLink :: Eq Link where
    eq (Link lidA _) (Link lidB _) = (lidA == lidB)


instance showNetwork :: Show (Network d c n) where
    show (Network { name }) = "Network " <> name

instance showPatch :: Show (Patch d c n) where
    show (Patch uuid path _) = "Patch " <> show uuid <> " " <> show path

instance showNode :: Show n => Show (Node d n) where
    show (Node uuid path n _ _) = "Node " <> show n <> " " <> show uuid <> " " <> show path

instance showInlet :: Show c => Show (Inlet d c) where
    show (Inlet uuid path c _) = "Inlet " <> show c <> " " <> show uuid <> " " <> show path

instance showOutlet :: Show c => Show (Outlet d c) where
    show (Outlet uuid path c _) = "Outlet " <> show c <> " " <> show uuid <> " " <> show path

instance showLink :: Show c => Show Link where
    show (Link uuid _) = "Link " <> show uuid
