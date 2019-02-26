module Model exposing (Model, Msg(..), init)

import Hexagons.Map exposing (..)


init : Model
init =
    { map = rectangularPointyTopMap 10 10
    , greenCells = []
    }



-- UPDATE


{-| Users of our app can trigger messages by clicking and typing. These
messages are fed into the `update` function as they occur, letting us react
to them.
-}
type Msg
    = NoOp
    | SetGreen Hash


type alias Model =
    { map : Map
    , greenCells : List Hash
    }


{-| This is the applications's Model data structure.
I assume the Player's position is fixed; they can rotate the map, zoom into it.
The map is a grid, with one selected cell.
A cell is selected with the mouse.
The map is rotated with wasd.
Each cell must contain a Terrain.
Each cell may also contain a Fighter, depending on the type of Terrain and type of Fighter.
-}



-- type alias Model2 =
--     { maybeWindowSize : Maybe Window.Size
--     , grid : Hexagons.Grid
--     , selectedCell : Hexagons.Axial
--     , highlitCell : Hexagons.Axial
--     }


type alias TileContents =
    { terrain : Terrain
    , character : Character
    }


type Terrain
    = Grass



-- | Rock
-- | Mountain
-- | Water
-- | Forest


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
