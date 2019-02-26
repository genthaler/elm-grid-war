module Update exposing (init, update)

import Dict
import Hexagons.Hex
import Hexagons.Map exposing (Hash, Map, rectangularPointyTopMap)
import Model exposing (Model, Msg(..))


init : Model
init =
    { map = rectangularPointyTopMap 10 10
    , cells = Dict.empty
    , selectedCell = Nothing
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model

        Clicked cell ->
            { model | selectedCell = Just cell }
