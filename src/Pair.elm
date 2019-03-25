module Pair exposing (Pair, first, fold, mapBoth, mapFirst, mapSecond, pair, second)

import Tuple exposing (..)


type alias Pair a =
    ( a, a )


pair =
    Tuple.pair


first =
    Tuple.first


second =
    Tuple.second


mapFirst =
    Tuple.mapFirst


mapSecond =
    Tuple.mapSecond


mapBoth f =
    Tuple.mapBoth f f


fold f ( a, b ) =
    f a b
