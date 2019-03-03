module Update exposing (init, update)

import Dict exposing (Dict)
import Hexagons.Hex
import Hexagons.Map exposing (Hash, Map, rectangularPointyTopMap)
import Json.Decode as D
import Json.Encode as E
import Model exposing (Cell, Character, Class(..), Model, Msg(..), Team(..), Terrain(..), decodeModel, encodeModel)


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
                        , character =
                            Just
                                { class = Peasant
                                , team = Human
                                }
                        }
                    )
    in
    { map = initialMap
    , cells = initialCells
    , selectedCell = Nothing
    , height = 10
    , width = 10
    , export = ""
    , verify = ""
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model

        Clicked cell ->
            { model | selectedCell = Just cell }

        Export ->
            { model | export = E.encode 2 <| encodeModel model }

        Import ->
            case D.decodeString decodeModel model.export of
                Ok model2 ->
                    model2

                Err string ->
                    { model | export = D.errorToString string }

        ExportChanged string ->
            { model | export = string }
