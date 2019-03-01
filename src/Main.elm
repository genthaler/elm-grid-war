module Main exposing (main)

import Browser
import Model exposing (Model, Msg)
import Update exposing (init, update)
import View exposing (view)


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , view = view
        , update = update
        }
