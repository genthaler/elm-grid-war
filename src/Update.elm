module Update exposing (init, update)

import Base64.Decode as D64
import Base64.Encode as E64
import Dict exposing (Dict)
import Hexagons.Hex
import Hexagons.Map exposing (Hash, Map, rectangularPointyTopMap)
import Json.Decode as D
import Json.Encode as E
import Model exposing (Cell, Character, Class(..), Model, Msg(..), Team(..), Terrain(..), decodeModel, encodeModel)
import Result
import Result.Extra as RExtra


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
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model

        Clicked cell ->
            { model | selectedCell = Just cell }

        Export ->
            { model | export = encodeModel model |> E.encode 0 |> E64.string |> E64.encode }

        Import ->
            case model.export |> D64.decode D64.string |> Result.mapError base64ErrorToString |> Result.andThen (D.decodeString decodeModel >> Result.mapError D.errorToString) of
                Ok model2 ->
                    model2

                Err string ->
                    { model | export = string }

        ExportChanged string ->
            { model | export = string }


base64ErrorToString : D64.Error -> String
base64ErrorToString error =
    case error of
        D64.ValidationError ->
            "ValidationError"

        D64.InvalidByteSequence ->
            "InvalidByteSequence "
