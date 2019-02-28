module Update exposing (init, update)

import Dict exposing (Dict)
import Hexagons.Hex
import Hexagons.Map exposing (Hash, Map, rectangularPointyTopMap)
import Model exposing (Cell, Character(..), Model, Msg(..), Team(..), Terrain(..))


init : Model
init =
    let
        initialMap : Dict Hash Hexagons.Hex.Hex
        initialMap =
            rectangularPointyTopMap 10 10

        initialCells : Dict Hash Cell
        initialCells =
            initialMap
                |> Dict.map
                    (\( x, y, z ) v ->
                        { terrain =
                            case Basics.modBy 5 x of
                                0 ->
                                    Grass

                                1 ->
                                    Rock

                                2 ->
                                    Mountain

                                3 ->
                                    Water

                                _ ->
                                    Forest
                        , character = Peasant
                        , team = Human
                        }
                    )
        initModel
    in
    { map = initialMap
    , cells = initialCells
    , selectedCell = Nothing
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model

        Clicked cell ->
            { model | selectedCell = Just cell }
