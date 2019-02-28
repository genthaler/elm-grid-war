module Model exposing (Cell, Character(..), Model, Msg(..), Team(..), Terrain(..), encode)

import Dict exposing (Dict)
import Hexagons.Map exposing (Hash, Map)
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


toStringCharacter character =
    case character of
        Peasant ->
            "Peasant"


toStringTeam team =
    case team of
        Human ->
            "Human"

        AI ->
            "AI"


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



decode : String -> Model
decode =
    let
        decodeModel = 
          D.map4 Model
                (D.field "cells" D.string)
                (D.field "height" D.float)
                (D.field "width" D.float)

    in
