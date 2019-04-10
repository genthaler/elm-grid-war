module Pair exposing (Pair, first, fold, map, mapFirst, mapSecond, pair, repeat, second)

import Tuple exposing (..)


type alias Pair a =
    ( a, a )


pair =
    Tuple.pair


repeat a =
    Tuple.pair a a


first =
    Tuple.first


second =
    Tuple.second


mapFirst =
    Tuple.mapFirst


mapSecond =
    Tuple.mapSecond


map f =
    Tuple.mapBoth f f


fold f ( a, b ) =
    f a b


swap ( a, b ) =
    ( b, a )
