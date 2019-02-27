module Model exposing (Model, Msg(..), Cell, Terrain(..), Character(..), Team(..))

import Dict exposing (Dict)
import Hexagons.Map exposing (Hash, Map)


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

