module Rpd.Renderer.Html.Html where

import Data.Either (Either(..))
import Data.Tuple.Nested (type (/\), (/\))

import Rpd.API (RpdError) as R
import Rpd.Network (Network) as R
import Rpd.Render as R
import Rpd.Command (Command(..)) as C
import Rpd.RenderMUV (Renderer(..), PushMsg, Message(..)) as R

import Spork.Html (Html)
import Spork.Html as H


type Model =
    {
    }


data Msg
    = ClickAt (Int /\ Int)


type Message d = R.Message d Msg


type PushMsg d = R.PushMsg d Msg


type View = Html Msg


init :: Model
init =
    {
    }


type HtmlRenderer d = R.Renderer d Model View Msg


emptyView :: View
emptyView = H.div [ H.id_ "network" ] []


htmlRenderer :: forall d. HtmlRenderer d
htmlRenderer =
    R.Renderer
        { from : emptyView
        , init : init
        , update
        , view
        }


view :: forall d. PushMsg d -> Either R.RpdError (Model /\ R.Network d) -> View
view pushMsg (Right (ui /\ nw)) =
    emptyView
view pushMsg (Left err) =
    emptyView


update :: forall d. Message d -> (Model /\ R.Network d) -> (Model /\ Array (Message d))
update (R.Core C.Bang) (ui /\ _) = ui /\ []
update _ (ui /\ _) = ui /\ []
