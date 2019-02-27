module Model exposing (Cell, Character(..), Model, Msg(..), Team(..), Terrain(..), decode, encode)

import Dict exposing (Dict)
import Hexagons.Map exposing (Hash, Map)
import Json.Decode as D
import Json.Encode as E


type Msg
    = NoOp
    | Clicked Hash


type alias Model =
    { map : Map
    , cells : Dict Hash Cell
    , selectedCell : Maybe Hash
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


encode : Int -> Model -> E.Value


decode : String -> Model
