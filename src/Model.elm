module Model exposing (Cell, Character(..), Model, Msg(..), Team(..), Terrain(..), encode)

import Dict exposing (Dict)
import Hexagons.Map exposing (Hash, Map, rectangularPointyTopMap)
import Json.Decode as D
import Json.Encode as E
import Json.Encode.Extra as EExtra


type Msg
    = NoOp
    | Clicked Hash


type alias Model =
    { map : Map
    , cells : Dict Hash Cell
    , selectedCell : Maybe Hash
    , height : Int
    , width : Int
    }


type alias Cell =
    { terrain : Terrain
    , character : Character
    , team : Team
    }


type Terrain
    = Grass
    | Rock
    | Mountain
    | Water
    | Forest


type Character
    = Peasant



-- | Soldier
-- | Archer
-- | Knight
-- | Sapper
-- | Squire
-- | Dog
-- | Catapult
-- | Castle


type Team
    = Human
    | AI


toStringTerrain terrain =
    case terrain of
        Grass ->
            "Grass"

        Rock ->
            "Rock"

        Mountain ->
            "Mountain"

        Water ->
            "Water"

        Forest ->
            "Forest"


fromStringTerrain string =
    case string of
        "Grass" ->
            Grass

        "Rock" ->
            Rock

        "Mountain" ->
            Mountain

        "Water" ->
            Water

        "Forest" ->
            Forest


toStringCharacter character =
    case character of
        Peasant ->
            "Peasant"


fromStringCharacter character =
    case character of
        "Peasant" ->
            Peasant


toStringTeam team =
    case team of
        Human ->
            "Human"

        AI ->
            "AI"


fromStringTeam team =
    case team of
        "Human" ->
            Human

        "AI" ->
            AI


encode : Int -> Model -> String
encode level model =
    let
        encodeHash ( a, b, c ) =
            E.list E.int [ a, b, c ]

        encodeCell cell =
            E.object
                [ ( "terrain", toStringTerrain cell.terrain |> E.string )
                , ( "character", toStringCharacter cell.character |> E.string )
                , ( "team", toStringTeam cell.team |> E.string )
                ]
    in
    E.encode 0 <|
        E.object
            [ ( "cells", E.dict (encodeHash >> E.encode 0) encodeCell model.cells )
            , ( "selectedCell", EExtra.maybe encodeHash model.selectedCell )
            , ( "height", E.int model.height )
            , ( "width", E.int model.width )
            ]


decode : String -> Result D.Error Model
decode =
    let
        decodeMap : D.Decoder Map
        decodeMap =
            D.map2 rectangularPointyTopMap
                (D.field "height" D.int)
                (D.field "width" D.int)

        decodeCell : D.Decoder Cell
        decodeCell =
            D.map3 Cell
                (D.field "terrain" (D.map fromStringTerrain D.string))
                (D.field "character" (D.map fromStringCharacter D.string))
                (D.field "team" (D.map fromStringTeam D.string))

        triple : D.Decoder (List a)
        triple list =
            case list of
                [ a, b, c ] ->
                    succeed ( a, b, c )

                _ ->
                    fail ""

        decodeHash : D.Decoder Hash
        decodeHash =
            D.list D.int
                |> D.andThen

        decodeModel : D.Decoder Model
        decodeModel =
            D.map5 Model
                decodeMap
                (D.field "cells" decodeCell)
                (D.field "selectedCell" D.string)
                (D.field "height" D.int)
                (D.field "width" D.int)
    in
    D.decodeString decodeModel
