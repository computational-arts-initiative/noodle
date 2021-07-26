module App.Emitters where


import Prelude

import Effect (Effect)
import Effect.Class (class MonadEffect)
import Effect.Aff as Aff

import Halogen as H
import Halogen.Query.Event (eventListener)
import Halogen.Subscription as HS

import Signal (Signal, (~>))
import Signal (runSignal) as Signal
import Signal.DOM as Signal

import Web.HTML.Window (document)
import Web.Event.Event (EventType)
import Web.UIEvent.UIEvent (UIEvent)
import Web.UIEvent.MouseEvent as ME
import Web.UIEvent.MouseEvent.EventTypes as MET
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.HTMLDocument (HTMLDocument)


mouse :: forall t. EventType -> HTMLDocument -> (ME.MouseEvent -> t) -> HS.Emitter t
mouse evtType document handler =
    eventListener
        evtType
        (HTMLDocument.toEventTarget document)
        (map handler <<< ME.fromEvent)


mouseDown :: forall t. HTMLDocument -> (ME.MouseEvent -> t) -> HS.Emitter t
mouseDown = mouse MET.mousedown


mouseUp :: forall t. HTMLDocument -> (ME.MouseEvent -> t) -> HS.Emitter t
mouseUp = mouse MET.mouseup


mouseMove :: forall t. HTMLDocument -> (ME.MouseEvent -> t) -> HS.Emitter t
mouseMove = mouse MET.mousemove


fromSignal :: forall m a. MonadEffect m => Effect (Signal a) -> m (HS.Emitter a)
fromSignal signalEff = H.liftEffect $ do
    { emitter, listener } <- HS.create
    signal <- signalEff
    Signal.runSignal $ signal ~> HS.notify listener
    pure emitter


windowDimensions :: forall m. MonadEffect m => m (HS.Emitter { w :: Int, h :: Int })
windowDimensions = fromSignal Signal.windowDimensions


animationFrame :: forall m. MonadEffect m => m (HS.Emitter Number)
animationFrame = fromSignal Signal.animationFrame -- could use Web.HTML.Window instead