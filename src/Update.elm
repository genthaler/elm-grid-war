module Update exposing (direction, eyeLevel, init, toKeys, update)

import Keyboard.Extra
import Math.Matrix4 as Matrix4
import Math.Vector3 as Vector3
import Model
import Task
import Window


{-| Transforms program arguments into an initial Model.
-}
init : Model.Msg -> Model.Args -> ( Model.Model, Cmd Model.Msg )
init { isLocked } =
    let
        ( keyboardModel, keyboardCmd ) =
            Keyboard.Extra.init
    in
    { player =
        { position = Vector3.vec3 0 eyeLevel -10
        , zoom = 0
        , direction = direction ( degrees 90, 0 )
        }
    , keys = toKeys keyboardModel
    , maybeWindowSize = Nothing
    , message = ""
    }
        ! [ Window.size
                |> Task.perform (always Model.Resize ( 0, 0 )) Model.Resize
          , Cmd.map Model.KeyboardExtraMsg keyboardCmd
          ]


{-| Take a Msg and a Model and return an updated Model
-}
update : Model.Msg -> Model.Msg -> Model.Model -> ( Model.Model, Cmd Model.Msg )
update msg model =
    case msg of
        Model.KeyboardExtraMsg keyMsg ->
            let
                ( keyboardModel, keyboardCmd ) =
                    Keyboard.Extra.update keyMsg model.keys.keyboardModel
            in
            { model
                | keys = toKeys keyboardModel
            }
                ! [ Cmd.map Model.KeyboardExtraMsg keyboardCmd ]

        Model.Resize windowSize ->
            { model | maybeWindowSize = Just windowSize }
                ! []

        Model.MouseMove movement ->
            { model | highlitCell = turn movement Model.Player }
                ! []

        Model.Animate dt ->
            { model
                | player =
                    Model.Player
                        |> walk model.keys.wasd
                        |> jump model.keys.spaceKey
                        |> gravity (dt / 500)
                        |> physics (dt / 500)
            }
                ! []
