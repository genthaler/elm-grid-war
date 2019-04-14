module Pair exposing (Pair, first, fold, map, mapFirst, mapSecond, pair, repeat, second, flip)

{-| This module implements a Tuple where both elements are the same type.


# Type

@docs Pair, first, fold, map, mapFirst, mapSecond, pair, repeat, second, flip

# Functions from Tuple

## Create

@docs pair

## Access

@docs first, second

## Map

@docs mapFirst, mapSecond

# Functions from List

@docs fold, map, repeat

# Functions from Basics

@docs flip
-}

import Tuple exposing (..)


{-| Defines a Pair.
-}
type alias Pair a =
    ( a, a )


{-| Creates a 2-tuple.
-}
pair =
    Tuple.pair


{-| Creates a Pair using the same value twice.
-}
repeat a =
    Tuple.pair a a


{-| Extracts the first value from a Pair.
-}
first =
    Tuple.first


{-| Extracts the second value from a Pair.
-}
second =
    Tuple.second


{-| Transforms the first value in a Pair.
-}
mapFirst =
    Tuple.mapFirst


{-| Transforms the second value in a Pair.
-}
mapSecond =
    Tuple.mapSecond


{-| Transforms both parts of a Pair.
-}
map f =
    Tuple.mapBoth f f


{-| Reduces a Pair.
-}
fold f ( a, b ) =
    f a b


{-| Swaps the parts of a Pair.
-}
flip ( a, b ) =
    ( b, a )
