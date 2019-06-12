module AdversarialTest exposing (all)

import Adversarial exposing (..)
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Main exposing (..)
import Test exposing (..)


all : Test
all =
    describe "Adversarial Search"
        [ describe "Minimax"
            [ test "Already there" <|
                \_ ->
                    Expect.equal 1.0 <| minimax 0 True (always 1.0) (always []) ()
            , test "At the bottom with nowhere to go" <|
                \_ ->
                    Expect.equal 1.0 <| minimax 1 True (always 1.0) (always []) ()
            ]
        , describe "Alpha-beta pruning"
            [ test "Already there" <|
                \_ ->
                    Expect.equal 1.0 <| alphabeta 2.0 -2.0 0 True (always 1.0) (always []) ()
            , test "At the bottom with nowhere to go" <|
                \_ ->
                    Expect.equal 1.0 <| alphabeta 2.0 -2.0 1 True (always 1.0) (always []) ()
            ]
        ]
