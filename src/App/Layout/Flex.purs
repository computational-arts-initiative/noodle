module App.Layout.Flex
  ( Align(..)
  , Cell(..)
  , Flex(..)
  , Flex2
  , Flex3
  , Padding(..)
  , PreEval(..)
  , Rule(..)
  , alignPlain
  , class Flexy
  , fillSizes
  , find
  , find'
  , fit
  , flatten
  , flatten'
  , fold
  , fold'
  , fold''
  , fold'''
  , layout
  , make
  , make2
  , mapSize
  , posOf
  , toUnfoldable
  )
  where


import Prelude

import App.Style.Order (Order)


import Data.Maybe (Maybe(..))
import Data.Vec2 (Size, Size_, Pos, (<+>))
import Data.Vec2 as V2
import Data.Int (toNumber)
import Data.Array ((:))
import Data.Array as Array
import Data.Tuple (fst, snd, curry, uncurry)
import Data.Tuple.Nested ((/\), type (/\))

import Data.Foldable (foldr)
import Data.Bifunctor (class Bifunctor, bimap, lmap)
import Data.Unfoldable (class Unfoldable, unfoldr)


-- TODO: `IsLayout` instance (AutoSizedLayout?)


data Rule
    = Portion Int -- a.k.a Fill a.k.a Portion 1
    | Units Number -- a.k.a. Px or Units
    | Percentage Int
    -- | Cells Number
    | Min Number Rule
    | Max Number Rule
    | MinMax (Number /\ Number) Rule
    -- TODO: a -> Rule ?


data Cell a
    = Taken a
    | Space


data Padding
    = NoPadding
    | Padding Number


data Align
    = Justify
    | Start
    | End
    | Center
    | SpaceAround
    | SpaceBetween
    | SpaceEvenly
    | Gap Number -- TODO: Gap Rule


-- TODO: padding + spacing (VBox items have padding and Horz items have spacing)

-- TODO: constraints

-- add align + centering + distribute


-- TODO: append


-- data HBox s a = Horz (Array (s /\ VBox s a))
-- data VBox s a = Vert (Array (s /\ a))


{- data Direction
    = Horizontal
    | Vertical -}


-- Operator candidates: ⁅ ⁆ ≡ ⫴ ⊢ ⊣ ⊪ ⊩ ≬ ⟷ ⧦ ⟺ ∥ ⁞ ⁝ ‖ ᎒ ᎓ ੦ ᠁ … ‒ – — ― ⊲ ⊳ ⊽ ⎪ ⎜ ⎟ ⟺ ⟚ ⟛


{- data HBox s a = Horz Padding Align (Array (s /\ a))


data VBox s a = Vert Padding Align (Array (s /\ HBox s a)) -}


-- FIXME:

data Flex s a = Flex Padding Align (Array (s /\ a))

type Flex2 s a = Flex s (Flex s a)

type Flex3 s a = Flex2 s (Flex s a)



class Flexy (x :: Type -> Type -> Type) s a | x -> s, x -> a where
    items :: x s a -> Array (s /\ a)
    fit_ :: Number -> x Rule a -> x Number a
    -- fit' :: Number -> x Rule (Cell a) -> x Number (Сell a)
    align_ :: Number -> Align -> x Rule a -> x Number (Cell a)
    takes :: x Number a -> Number
    from :: Array (s /\ a) -> x s a

-- Rule as Container ?


-- both VBox and HBox implement `IsLayout`
-- plus, both may distribute or align inner items

-- fitting => solving (means)



{-
type FlexN a = Flex Number a


type FlexR a = Flex Rule a


type FlexS a = Flex Rule a
-}


instance functorFlex :: Functor (Flex s) where
    map :: forall a b. (a -> b) -> Flex s a -> Flex s b
    map f (Flex p a items) = Flex p a $ map f <$> items


instance bifunctorFlex :: Bifunctor Flex where
    bimap :: forall s1 s2 a b. (s1 -> s2) -> (a -> b) -> Flex s1 a -> Flex s2 b
    bimap f g (Flex p a items) = Flex p a $ bimap f g <$> items


make :: forall s a. Array (s /\ a) -> Flex s a
make = Flex NoPadding Justify


make2 :: forall s a. Array (s /\ Array (s /\ a)) -> Flex2 s a
make2 items = Flex NoPadding Justify $ map (Flex NoPadding Justify) <$> items


alignPlain :: forall a. Number -> Align -> Array (Number /\ a) -> Array (Number /\ Cell a)
alignPlain total how items =
    if sumTaken < total
        then doAlign how
        else map Taken <$> items
    where
        sumTaken = Array.foldr (+) 0.0 (fst <$> items)
        count = Array.length items
        doAlign Start = (map Taken <$> items) <> [ (total - sumTaken) /\ Space ]
        doAlign Center =
            let sideSpace = (total - sumTaken) / 2.0
            in
            [ sideSpace /\ Space ] <> (map Taken <$> items) <> [ sideSpace /\ Space ]
        doAlign End =
            [ (total - sumTaken) /\ Space ] <> (map Taken <$> items)
        doAlign SpaceBetween =
            let spaceBetween = (total - sumTaken) / (toNumber $ count - 1)
            in Array.intersperse (spaceBetween /\ Space) (map Taken <$> items)
        doAlign SpaceAround =
            let oneSpace = (total - sumTaken) / toNumber count
                halfSpace = oneSpace / 2.0
            in [ halfSpace /\ Space ] <> Array.intersperse (oneSpace /\ Space) (map Taken <$> items) <> [ halfSpace /\ Space ]
        doAlign SpaceEvenly =
            let evenSpace = (total - sumTaken) / toNumber (count + 1)
            in [ evenSpace /\ Space ] <> Array.intersperse (evenSpace /\ Space) (map Taken <$> items) <> [ evenSpace /\ Space ]
        doAlign (Gap n) =
            Array.intersperse (n /\ Space) (map Taken <$> items)


-- TODO: fitAll a.k.a. distribute a.k.a justify

-- TODO


data PreEval
    = Known Number
    | Portion_ Int


fit :: forall x. Number -> Flex2 Rule a -> Flex Number a -- TODO: Semiring n => Flex n a
fit



fit2 :: forall a. Size -> Flex2 Rule a -> Flex2 Number a
fit2 size (Flex padding align vbox) =

    Vert result
    where

        result :: Array (Number /\ HBox Number a)
        result =
            map
                (\(Horz hbox) -> Horz $ fitPlain' (V2.w size) hbox)
            <$> verticalFit


        verticalFit :: Array (Number /\ HBox Rule a)
        verticalFit = fitPlain' (V2.h size) vbox


        fitPlain' :: forall x. Number -> Array (Rule /\ x) -> Array (Number /\ x)
        fitPlain' amount items = Array.zip (fitPlain amount (fst <$> items)) (snd <$> items)


        fitPlain :: Number -> Array Rule -> Array Number
        fitPlain amount rules =
            fillPortionAmount <$> preEvaluated
            where

                preEvaluate (Portion n) = Portion_ n
                preEvaluate (Units n) = Known n
                preEvaluate (Percentage p) = Known $ amount * (toNumber p / 100.0)
                --toKnownAmount (Cells c) = Just $ c * cellSize

                preEvaluated = preEvaluate <$> rules

                extractKnown (Known n) = Just n
                extractKnown (Portion_ _) = Nothing

                extractPortion (Portion_ n) = Just n
                extractPortion (Known _) = Nothing

                portionCount = Array.foldr (+) 0 $ Array.catMaybes $ map extractPortion preEvaluated
                knownAmount = Array.foldr (+) 0.0 $ Array.catMaybes $ map extractKnown preEvaluated

                fillPortionAmount (Known n) = n
                fillPortionAmount (Portion_ n) = ((amount - knownAmount) / toNumber portionCount) * toNumber n


-- TODO: fitWrap (cut oversize)


-- add width data to vertical boxes and height data to horizontal ones
fillSizes :: forall a. Flex Number a -> Flex Size a
fillSizes (Vert vbox) =
    Vert
        $ (\(h /\ (Horz hbox)) ->
            ((foldr (+) 0.0 (fst <$> hbox)) <+> h)
            /\
            (lmap (\w' -> w' <+> h) $ Horz hbox)
        ) <$> vbox


layout :: forall a. Size -> Flex Rule a -> Flex Size a
layout size = fit size >>> fillSizes


mapSize :: forall s1 s2 a. (s1 -> s2) -> Flex s1 a -> Flex s2 a
mapSize = lmap


-- mapSize' :: forall s1 s2 a. (Direction -> s1 -> s2) -> Ordered s1 a -> Ordered s2 a
-- mapSize' f (Vert items) = Vert $ bimap (f Vertical) (lmap $ f Horizontal) <$> items


{- tryHorz :: forall a. Rule -> a -> Ordered Rule a -> Maybe (Ordered Rule a)
tryHorz _ _ ordered = ordered


tryVert :: forall a. Rule -> a -> Ordered Rule a -> Maybe (Ordered Rule a)
tryVert _ _ ordered = ordered -}


find :: forall a. Pos -> Flex Number a -> Maybe a
find pos ordered =
    snd <$> snd <$> find' pos ordered


find' :: forall a. Pos -> Flex Number a -> Maybe (Pos /\ Size /\ a)
find' pos =
    flatten >>> -- FIXME: use Unfoldable for faster search?
        foldr
            (\(pos' /\ size /\ a) _ ->
                if V2.inside pos (pos' /\ size) then Just (pos' /\ size /\ a) else Nothing
            )
            Nothing


{- get :: forall s a. Int /\ Int -> Ordered s a -> Maybe (Size_ s /\ a)
get (ny /\ nx) (Vert vbox) =
    Array.index vbox ny
        >>= (\(h /\ (Horz hbox)) -> ((<+>) h) <$> Array.index hbox nx) -}


toUnfoldable :: forall f s a. Unfoldable f => Flex s a -> f (Size_ s /\ a)
toUnfoldable =
    flatten' >>> Array.toUnfoldable -- TODO: make unfoldable manually?


{- sizeOf :: forall s a. Eq a => a -> Flex s a -> Maybe (Size_ s)
sizeOf a (Vert vbox) =
    Array.findMap
        (\(h /\ (Horz hbox)) ->
            Array.findMap
                (\(w /\ item) ->
                    if item == a then Just (w <+> h)
                    else Nothing
                )
                hbox
        )
        vbox -}


posOf :: forall a. Eq a => a -> Flex Number a -> Maybe Pos
posOf _ _ = Nothing


fold :: forall a b. (Pos -> Size -> a -> b -> b) -> b -> Flex Rule a -> b
fold f d = fit (1.0 <+> 1.0) >>> fold' f d


fold' :: forall a b. (Pos -> Size -> a -> b -> b) -> b -> Flex Number a -> b -- TODO: Number -> Semiring, where possible
fold' f def (Vert vbox) =
    snd $ foldr
        (\(h /\ (Horz hbox)) (y /\ b) ->
            (y + h)
            /\
            (snd $ foldr
                (\(w /\ a) (x /\ b') ->
                    (x + w)
                    /\
                    (f (x <+> y) (w <+> h) a b')
                )
                (0.0 /\ b)
                hbox
            )
        )
        (0.0 /\ def)
        vbox


fold'' :: forall a b. (Pos -> Size -> a -> b -> b) -> b -> Flex Size a -> b
fold'' f def (Vert vbox) =
    snd $ foldr
        (\(vsize /\ (Horz hbox)) (y /\ b) ->
            (y + V2.h vsize)
            /\
            (snd $ foldr
                (\(hsize /\ a) (x /\ b') ->
                    (x + V2.w hsize)
                    /\
                    (f (x <+> y) hsize a b')
                )
                (0.0 /\ b)
                hbox
            )
        )
        (0.0 /\ def)
        vbox


fold''' :: forall s a b. (Size_ s -> a -> b -> b) -> b -> Flex s a -> b
fold''' f def (Vert vbox) =
    foldr
        (\(h /\ (Horz hbox)) b ->
            foldr
                (\(w /\ a) b' ->
                    f (w <+> h) a b'
                )
                b
                hbox
        )
        def
        vbox


{- unfold :: forall s a. Ordered s a -> Array (s /\ Array (s /\ a))
unfold _ = [] -- fold (curry <<< ?wh) [] -}


-- unfold' :: forall a. Ordered Number a -> Array (Pos /\ Size /\ Array (Pos /\ Size /\ a))
-- unfold' _ = []


flatten :: forall a. Flex Number a -> Array (Pos /\ Size /\ a)
flatten = fold' (\p s a arr -> (p /\ s /\ a) : arr) []


flatten' :: forall s a. Flex s a -> Array (Size_ s /\ a)
flatten' = fold''' (curry (:)) []