module Update exposing (update)

import Model exposing (Model, Msg(..))


update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model

        SetGreen cell ->
            { model | greenCells = model.greenCells ++ [ cell ] }
