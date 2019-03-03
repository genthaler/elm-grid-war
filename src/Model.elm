module Model exposing (Cell, Character, Class(..), Model, Msg(..), Team(..), Terrain(..), decodeModel, encodeModel)

import Dict exposing (Dict)
import Hexagons.Map exposing (Hash, Map, rectangularPointyTopMap)
import Json.Decode as D
import Json.Decode.Extra as DExtra
import Json.Encode as E
import Json.Encode.Extra as EExtra


type Msg
    = NoOp
    | Clicked Hash
    | Export
    | Import
    | ExportChanged String


type alias Model =
    { map : Map
    , cells : Dict Hash Cell
    , selectedCell : Maybe Hash
    , height : Int
    , width : Int
    , export : String
    , verify : String
    }


decodeModel : D.Decoder Model
decodeModel =
    D.map7 Model
        decodeMap
        (D.field "cells" <| DExtra.dict2 decodeHash decodeCell)
        (D.field "selectedCell" <| D.maybe decodeHash)
        (D.field "height" D.int)
        (D.field "width" D.int)
        (D.succeed "")
        (D.succeed "adsf")


encodeModel : Model -> E.Value
encodeModel model =
    E.object
        [ ( "cells", E.dict (encodeHash >> E.encode 0) encodeCell model.cells )
        , ( "selectedCell", EExtra.maybe encodeHash model.selectedCell )
        , ( "height", E.int model.height )
        , ( "width", E.int model.width )
        ]


type alias Cell =
    { terrain : Terrain
    , character : Maybe Character
    }


decodeCell : D.Decoder Cell
decodeCell =
    D.map2 Cell
        (D.field "terrain" decodeTerrain)
        (D.field "character" <| D.maybe decodeCharacter)


encodeCell : Cell -> E.Value
encodeCell cell =
    E.object
        [ ( "terrain", toStringTerrain cell.terrain |> E.string )
        , ( "character", EExtra.maybe encodeCharacter cell.character )
        ]


type Terrain
    = Grass
    | Rock
    | Mountain
    | Water
    | Forest


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
            Ok Grass

        "Rock" ->
            Ok Rock

        "Mountain" ->
            Ok Mountain

        "Water" ->
            Ok Water

        "Forest" ->
            Ok Forest

        _ ->
            Err "Unrecognised Terrain"


decodeTerrain =
    D.string |> D.andThen (DExtra.fromResult << fromStringTerrain)


type alias Character =
    { class : Class
    , team : Team
    }


type Class
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


toStringClass class =
    case class of
        Peasant ->
            "Peasant"


fromStringClass class =
    case class of
        "Peasant" ->
            Ok Peasant

        _ ->
            Err "Unrecognised Character"


toStringTeam team =
    case team of
        Human ->
            "Human"

        AI ->
            "AI"


fromStringTeam team =
    case team of
        "Human" ->
            Ok Human

        "AI" ->
            Ok AI

        _ ->
            Err "Unrecognised Team"


encodeHash : Hash -> E.Value
encodeHash ( a, b, c ) =
    E.list E.int [ a, b, c ]


encodeCharacter character =
    E.object
        [ ( "class", toStringClass character.class |> E.string )
        , ( "team", toStringTeam character.team |> E.string )
        ]


decodeHash : D.Decoder Hash
decodeHash =
    let
        triple list =
            case list of
                [ a, b, c ] ->
                    if a + b + c == 0 then
                        D.succeed ( a, b, c )

                    else
                        D.fail "The sum of this hash doesn't equal zero"

                _ ->
                    D.fail "Not a list with exactly 3 integers"
    in
    D.list D.int |> D.andThen triple


decodeClass =
    D.string |> D.andThen (DExtra.fromResult << fromStringClass)


decodeTeam =
    D.string |> D.andThen (DExtra.fromResult << fromStringTeam)


decodeCharacter =
    D.map2 Character
        (D.field "class" decodeClass)
        (D.field "team" decodeTeam)


decodeMap : D.Decoder Map
decodeMap =
    D.map2 rectangularPointyTopMap
        (D.field "height" D.int)
        (D.field "width" D.int)
