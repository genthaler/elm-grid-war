module Update exposing (init, update)

import Dict exposing (Dict)
import Hexagons.Hex
import Hexagons.Map exposing (Hash, Map, rectangularPointyTopMap)
import Model exposing (Model, Msg(..), Cell, Terrain(..), Character(..), Team(..))


init : Model
init =
    let  
        initialMap : Dict Hash Hexagons.Hex.Hex
        initialMap = rectangularPointyTopMap 10 10

        initialCells : Dict Hash Cell 
        initialCells = initialMap |> Dict.map (\k v -> {terrain= Grass, character= Peasant, team = Human})
    in
    { map = initialMap
    , cells = initialCells
    , selectedCell = Nothing
    }
 

update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model

        Clicked cell ->
            { model | selectedCell = Just cell }
