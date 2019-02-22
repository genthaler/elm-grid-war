module Model exposing (Args, Keys, Model, MouseMovement, Msg(..), Player)

import Hexagons.Grid as Grid exposing (..)
import Keyboard.Extra
import Math.Vector3 as Vector3
import Time
import Window


{-| This is the applications's Model data structure.
I assume the Player's position is fixed; they can rotate the map, zoom into it.
The map is a grid, with one selected cell.
A cell is selected with the mouse.
The map is rotated with wasd.
Each cell must contain a Terrain.
Each cell may also contain a Fighter, depending on the type of Terrain and type of Fighter.
-}
type alias Model =
    { maybeWindowSize : Maybe Window.Size
    , grid : Hexagons.Grid
    , selectedCell : Hexagons.Axial
    , highlitCell : Hexagons.Axial
    }


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
