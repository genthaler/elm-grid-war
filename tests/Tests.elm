module Tests exposing (all)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Main exposing (..)
import Test exposing (..)

all : Test
all =
  describe "Model JSON"
    [ test "Addition" <|
        \_ ->
          Expect.equal 10 (3 + 7)
    , test "String.left" <|
        \_ ->
          Expect.equal "a" (String.left 1 "abcdefg")
    ]
