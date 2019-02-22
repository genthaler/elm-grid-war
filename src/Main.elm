module MapExample exposing (main)

import Browser
import Model exposing (Model, Msg, init)
import Update exposing (update)
import View exposing (view)


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , view = view
        , update = update
        }
