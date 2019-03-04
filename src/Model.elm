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
    }


decodeModel : D.Decoder Model
decodeModel =
    let
        gather c s h w =
        
    in
    D.map4 
    D.map6 gather
        (D.field "c" <| DExtra.dict2 decodeHash decodeCell)
        (D.field "s" <| D.maybe decodeHash)
        (D.field "h" D.int)
        (D.field "w" D.int)
        |> 
        (D.succeed "")
        decodeMap

encodeModel model =
    E.object
        [ ( "c", E.list encodeCell <| Dict.values model.cells )
        , ( "s", EExtra.maybe encodeHash model.selectedCell )
        , ( "h", E.int model.height )
        , ( "w", E.int model.width )
        ]


type alias Cell =
    { terrain : Terrain
    , character : Maybe Character
    }


decodeCell =
    D.map2 Cell
        (D.field "t" decodeTerrain)
        (D.field "c" <| D.maybe decodeCharacter)


encodeCell cell =
    E.object
        [ ( "t", encodeTerrain cell.terrain )
        , ( "c", EExtra.maybe encodeCharacter cell.character )
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
            "G"

        Rock ->
            "R"

        Mountain ->
            "M"

        Water ->
            "W"

        Forest ->
            "F"


fromStringTerrain string =
    case string of
        "G" ->
            Ok Grass

        "R" ->
            Ok Rock

        "M" ->
            Ok Mountain

        "W" ->
            Ok Water

        "F" ->
            Ok Forest

        _ ->
            Err "Unrecognised Terrain"


decodeTerrain =
    D.string |> D.andThen (DExtra.fromResult << fromStringTerrain)


encodeTerrain =
    E.string << toStringTerrain


type alias Character =
    { class : Class
    , team : Team
    }


decodeCharacter =
    D.map2 Character
        (D.field "c" decodeClass)
        (D.field "t" decodeTeam)


encodeCharacter character =
    E.object
        [ ( "c", encodeClass character.class )
        , ( "t", encodeTeam character.team )
        ]


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


toStringClass class =
    case class of
        Peasant ->
            "P"


fromStringClass class =
    case class of
        "P" ->
            Ok Peasant

        _ ->
            Err "Unrecognised Class"


decodeClass =
    D.string
        |> D.andThen (DExtra.fromResult << fromStringClass)


encodeClass =
    E.string << toStringClass


type Team
    = Human
    | AI


toStringTeam team =
    case team of
        Human ->
            "H"

        AI ->
            "A"


fromStringTeam team =
    case team of
        "H" ->
            Ok Human

        "A" ->
            Ok AI

        _ ->
            Err "Unrecognised Team"


decodeTeam =
    D.string |> D.andThen (DExtra.fromResult << fromStringTeam)


encodeTeam =
    E.string << toStringTeam


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


encodeHash ( a, b, c ) =
    E.list E.int [ a, b, c ]


decodeMap =
    D.map2 rectangularPointyTopMap
        (D.field "height" D.int)
        (D.field "width" D.int)
