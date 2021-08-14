module App.Style where


import Prelude (class Show)

import App.Style.Color (Color)
import App.Style.Color as Color

import Data.Set (Set)
import Data.Set.Ordered (OSet)

import Data.Vec2 (Size_, Size, Pos, (<+>))
import Data.Tuple.Nested ((/\), type (/\))

import Noodle.Node (Family) as Node


type Flags =
    { hasTitle :: Boolean
    , customBody :: Boolean
    , hasRemoveButton :: Boolean
    }


type Radius = Number


data Connector
    = Square Number
    | Rect Size
    | Circle Radius
    | DoubleCircle Radius Radius


data NodeFlow
    = Vertical
    | Horizontal


data SlotDirection
    = Inside
    | Between
    | Outside


data SlotInfoVisibility
    = Always
    | OnHover
    | Never


data LinkType
    = Straight
    | Curve


data NodePart
    = Title
    | OnlyInlets
    | OnlyOutlets
    | UserBody Number
    | InletsAndOutlets
    | UserBodyBetweenSlots
    | UserBodyBetweenSlotsMin Number


data TitleMode
    = OutsideBody
    | InsideBody


type Order = OSet NodePart


data ShadowType
    = None
    | Solid { offset :: Pos }
    | Blurred { offset :: Pos, blur :: Number }


type CellStyle =
    { size :: Size
    }


type BackgroundStyle =
    { fill :: Color
    }


type PatchTabStyle =
    { background :: Color
    , stroke :: Color
    }


type NodeTabStyle =
    { background :: Color
    , stroke :: Color
    }


type SlotStyle =
    { stroke :: Color
    , fill :: Color
    , label :: { color :: Color, maxWidth :: Number }
    , value :: { color :: Color, maxWidth :: Number }
    , connector :: Connector
    , direction :: SlotDirection
    , info :: SlotInfoVisibility
    , strokeWidth :: Number
    }


type TitleStyle =
    { mode :: TitleMode
    , fill :: Color
    , background :: Color
    , size :: Number
    , padding :: Size
    }


type BodyStyle =
    { shadow :: ShadowType
    , size :: Number
    , margin :: Size
    , fill :: Color
    , stroke :: Color
    , strokeWidth :: Number
    , cornerRadius :: Number
    }


type LinkStyle =
    { type :: LinkType
    }


type Style =
    { slot :: SlotStyle
    , bg :: BackgroundStyle
    , body :: BodyStyle
    , title :: TitleStyle
    , link :: LinkStyle

    , patchTab :: PatchTabStyle
    , nodeTab :: NodeTabStyle

    , order :: Order
    , supportedFlows :: Set NodeFlow
    , font :: { size :: Number, family :: Array String }
    }


-- FIXME: get rid of, it's just a helper
type Units =
    { cell ::
        { size :: Size
        }
    , body ::
        { size :: Number
        , margin :: Size
        , strokeWidth :: Number
        , cornerRadius :: Number
        }
    , title ::
        { size :: Number
        , padding :: Size
        }
    -- , preview
    --    :: { size :: Size }
    , slot ::
        { area :: Size -- size of the rect: name/value + connector
        , radius :: Number
        , strokeWidth :: Number
        , labelMaxWidth :: Number
        , valueMaxWidth :: Number
        }
    }


-- FIXME: get rid of, it's just a helper
type Colors =
    { background :: Color
    , patchTab :: { background :: Color, stroke :: Color }
    , nodeTab :: { background :: Color, stroke :: Color }
    , slot :: { stroke :: Color, fill :: Color, label :: Color, value :: Color  }
    , body :: { fill :: Color, shadow :: Color, stroke :: Color }
    , title :: { fill :: Color, background :: Color }
    }



defaultFlags :: Flags
defaultFlags =
    { hasTitle : true
    , customBody : false
    , hasRemoveButton : true
    }


{- findBodySize :: NodeFlow -> (CalculateSide -> Number) -> BodySize -> Size
findBodySize Horizontal _ (h /\ Fixed w) = w <+> h
findBodySize Horizontal f (h /\ StretchByMax) = f StretchByMax <+> h
findBodySize Horizontal f (h /\ StretchBySum) = f StretchBySum <+> h -}



transparent :: Color
transparent = Color.rgba 0 0 0 0.0


white :: Color
white = Color.named "white"


black :: Color
black = Color.named "black"


instance showSlotDirection :: Show SlotDirection where
    show Inside = "inside"
    show Outside = "outside"
    show Between = "between"