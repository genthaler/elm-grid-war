module View exposing (view)

import Html
import Html.Attributes as Attributes
import Math.Matrix4 as Matrix4
import Math.Vector3 as Vector3
import Model
import View.Ground
import View.Wall
import WebGL
import Window


{-| generate a View from a Model
-}
view : Model.Model -> Html.Html Model.Msg
view { person, maybeWindowSize, maybeTexture } =
    case ( maybeWindowSize, maybeTexture ) of
        ( Nothing, _ ) ->
            Html.text ""

        ( _, Nothing ) ->
            Html.text ""

        ( Just windowSize, Just texture ) ->
            div []
                [ img [ src "/logo.svg" ] []
                , h1 [] [ text "Your Elm App is working!" ]
                ]
