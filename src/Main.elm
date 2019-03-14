module Main exposing (main)

import Base64.Decode as D64
import Base64.Encode as E64
import Basics.Extra exposing (flip)
import Browser
import Debug
import Dict exposing (Dict)
import Dict.Extra
import Hexagons.Hex exposing (Direction(..), Hex)
import Hexagons.Layout exposing (Point, orientationLayoutPointy, polygonCorners)
import Hexagons.Map exposing (Hash, Map, rectangularPointyTopMap)
import Html exposing (Html, br, button, div, h1, text, textarea)
import Html.Attributes as Attributes
import Html.Events as Events
import Json.Decode as D
import Json.Decode.Extra as DExtra
import Json.Encode as E
import Json.Encode.Extra as EExtra
import List.Extra as LExtra
import Maybe exposing (Maybe(..))
import Maybe.Extra
import Platform
import Platform.Sub
import Random
import Random.Dict
import Random.List
import Result.Extra as RExtra
import RollingList
import Set
import StateMachine as SM exposing (Allowed, State(..), untag)
import Svg exposing (Svg, g, polygon, svg)
import Svg.Attributes exposing (fill, points, stroke, strokeWidth, style, version, viewBox, x, y)
import Svg.Events as SvgEvents
import Svg.Lazy exposing (lazy, lazy2, lazy3)
import Task
import Time


type Msg
    = New
    | Restart
    | Import
    | MapJsonChanged String
    | SeedChanged (Maybe Int)
    | UseSeed
    | Tick Time.Posix
    | Attack
    | Clicked Hash
    | Cancel


type alias MoveState =
    { hash : Hash, movesLeft : Int }


type Terrain
    = Grass
    | Rock
    | Mountain
    | Water
    | Forest


type Class
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


type alias Character =
    { class : Class
    , team : Team
    }


type alias SemiCell =
    { terrain : Terrain
    , character : Maybe Character
    }


type alias Cell =
    { terrain : Terrain
    , character : Maybe Character
    , hex : Hex
    }


type alias Battlefield =
    { height : Int
    , width : Int
    , cells : Dict Hash Cell
    , selectedCell : Maybe Hash
    , teams : RollingList.RollingList Team
    , seed : Random.Seed
    , initialSeedSeed : Int
    }


directions =
    [ NE, E, SE, SW, W, NW ]


type Model
    = Init (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } {})
    | GettingTimeForNewSeed (State { waitingForStart : Allowed } {})
    | GettingSeed (State { gettingSeed : Allowed, waitingForStart : Allowed } { maybeBattlefield : Maybe Battlefield, seedSeed : Maybe Int })
    | GettingMapJson (State { waitingForStart : Allowed } { maybeBattlefield : Maybe Battlefield, mapJson : String, maybeNewBattlefield : Maybe Battlefield })
    | WaitingForStart (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed, attacking : Allowed } Battlefield)
    | Attacking (State { attacking : Allowed, gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed, ending : Allowed } Battlefield)
    | Ending (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } Battlefield)
    | Error (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } { message : String })


toInit : Model
toInit =
    Init <| State {}


toGettingTimeForNewSeed : State { a | gettingTimeForNewSeed : Allowed } b -> Model
toGettingTimeForNewSeed _ =
    GettingTimeForNewSeed <| State {}


toGettingSeed : State { a | gettingSeed : Allowed } { b | maybeBattlefield : Maybe Battlefield } -> Maybe Int -> Model
toGettingSeed (State state) seedSeed =
    GettingSeed <| State { maybeBattlefield = state.maybeBattlefield, seedSeed = seedSeed }


toGettingMapJson : State { a | gettingMapJson : Allowed } b -> Maybe Battlefield -> String -> Maybe Battlefield -> Model
toGettingMapJson (State state) maybeBattlefield mapJson maybeNewBattlefield =
    GettingMapJson <| State { maybeBattlefield = maybeBattlefield, mapJson = mapJson, maybeNewBattlefield = maybeNewBattlefield }


toWaitingForStart : State { a | waitingForStart : Allowed } b -> Battlefield -> Model
toWaitingForStart _ battlefield =
    WaitingForStart <| State battlefield


toAttacking : State { a | attacking : Allowed } Battlefield -> Model
toAttacking (State state) =
    Attacking <| State state


toEnding : State { a | ending : Allowed } Battlefield -> Model
toEnding (State state) =
    Ending <| State state


toError : String -> Model
toError message =
    Error <| State { message = message }


toStringTerrain terrain =
    case terrain of
        Grass ->
            "G"

        Rock ->
            "R"

        Mountain ->
            "M"

        Water ->
            "W"

        Forest ->
            "F"


fromStringTerrain string =
    case string of
        "G" ->
            Ok Grass

        "R" ->
            Ok Rock

        "M" ->
            Ok Mountain

        "W" ->
            Ok Water

        "F" ->
            Ok Forest

        _ ->
            Err "Unrecognised Terrain"


decodeTerrain =
    D.string |> D.andThen (DExtra.fromResult << fromStringTerrain)


encodeTerrain =
    E.string << toStringTerrain


toStringClass class =
    case class of
        Peasant ->
            "P"


fromStringClass class =
    case class of
        "P" ->
            Ok Peasant

        _ ->
            Err "Unrecognised Class"


decodeClass =
    D.string
        |> D.andThen (DExtra.fromResult << fromStringClass)


encodeClass =
    E.string << toStringClass


toStringTeam team =
    case team of
        Human ->
            "H"

        AI ->
            "A"


fromStringTeam team =
    case team of
        "H" ->
            Ok Human

        "A" ->
            Ok AI

        _ ->
            Err "Unrecognised Team"


decodeTeam =
    D.string |> D.andThen (DExtra.fromResult << fromStringTeam)


encodeTeam =
    E.string << toStringTeam


decodeHash =
    let
        triple list =
            case list of
                [ a, b, c ] ->
                    if a + b + c == 0 then
                        D.succeed ( a, b, c )

                    else
                        D.fail "The sum of this hash doesn't equal zero"

                _ ->
                    D.fail "Not a list with exactly 3 integers"
    in
    D.list D.int |> D.andThen triple


encodeHash ( a, b, c ) =
    E.list E.int [ a, b, c ]


decodeCharacter =
    D.map2 Character
        (D.field "c" decodeClass)
        (D.field "t" decodeTeam)


encodeCharacter character =
    E.object
        [ ( "c", encodeClass character.class )
        , ( "t", encodeTeam character.team )
        ]


decodeCell =
    D.map2 SemiCell
        (D.field "t" decodeTerrain)
        (D.field "c" <| D.maybe decodeCharacter)


encodeCell cell =
    E.object
        [ ( "t", encodeTerrain cell.terrain )
        , ( "c", EExtra.maybe encodeCharacter cell.character )
        ]


decodeMap =
    D.map2 rectangularPointyTopMap
        (D.field "height" D.int)
        (D.field "width" D.int)


decodeBattlefield : D.Decoder Battlefield
decodeBattlefield =
    let
        gather : List SemiCell -> Maybe Hash -> Int -> Int -> Battlefield
        gather c s h w =
            let
                map =
                    rectangularPointyTopMap h w

                cells =
                    List.map2 Tuple.pair (Dict.keys map) c

                mergedCells =
                    List.map2 (\( k1, v1 ) ( k2, v2 ) -> ( k1, Cell v2.terrain v2.character v1 )) (Dict.toList map) cells
                        |> Dict.fromList
            in
            Battlefield h w mergedCells s (cellsToTeams c) (Random.initialSeed 1) 1
    in
    D.map4
        gather
        (D.field "c" <| D.list decodeCell)
        (D.field "s" <| D.maybe decodeHash)
        (D.field "h" D.int)
        (D.field "w" D.int)


encodeBattlefield model =
    E.object
        [ ( "c", E.list encodeCell <| Dict.values model.cells )
        , ( "s", EExtra.maybe encodeHash model.selectedCell )
        , ( "h", E.int model.height )
        , ( "w", E.int model.width )
        ]


base64ErrorToString : D64.Error -> String
base64ErrorToString error =
    case error of
        D64.ValidationError ->
            "ValidationError"

        D64.InvalidByteSequence ->
            "InvalidByteSequence "


cellsToTeams : List { a | character : Maybe { b | team : Team } } -> RollingList.RollingList Team
cellsToTeams cells =
    cells |> List.map .character |> Maybe.Extra.values |> List.map .team |> RollingList.fromList


initBattlefield : Int -> Battlefield
initBattlefield seedSeed =
    let
        seed =
            Random.initialSeed seedSeed

        height =
            10

        width =
            10

        teamSize =
            10

        initialMap : Dict Hash Hexagons.Hex.Hex
        initialMap =
            rectangularPointyTopMap height width

        ( shuffledCells, newSeed ) =
            initialMap
                |> Dict.map
                    (\( x, y, z ) v ->
                        { terrain = Grass
                        , character =
                            case modBy 5 x of
                                0 ->
                                    Just
                                        { class = Peasant
                                        , team = Human
                                        }

                                1 ->
                                    Just
                                        { class = Peasant
                                        , team = AI
                                        }

                                _ ->
                                    Nothing
                        , hex = v
                        }
                    )
                |> Dict.toList
                |> Random.List.shuffle
                |> flip Random.step seed
                |> Tuple.mapFirst (mergeShuffledCells initialMap)
    in
    { height = height
    , width = width
    , cells = shuffledCells
    , selectedCell = Nothing
    , teams = shuffledCells |> Dict.values |> cellsToTeams
    , seed = newSeed
    , initialSeedSeed = seedSeed
    }


mergeShuffledCells oldCells shuffledCells =
    List.map2
        (\( k, _ ) ( _, v ) -> ( k, v ))
        (Dict.toList oldCells)
        shuffledCells
        |> Dict.fromList


init : flags -> ( Model, Cmd Msg )
init _ =
    ( toInit, Cmd.none )


crash message =
    ( toError message, Cmd.none )


invalidMessageState =
    crash "Unexpected message/state combination"



{-
   - init
      - Update all team members with new remaining moves

   - get current team
      - if AI
           - get random team member with remaining moves
           - if there is one,
                - get random cell that is in range that is on the map, has no team members on it
                    - decrement moves remaining
                    - if someone there
                        - fight them (randomly)
                            - if alive
                                - increase XP
                                - update new cell
                    - else
                        - go there
                           - update new cell
                    - clear previous cell of character

            - else
                - next team
                  - Update all team members with new remaining moves

      - if Human
          later...
-}


type alias CellRef =
    ( Hash, Cell )


type alias FightResult =
    { src : CellRef, dest : CellRef, attackSuccessful : Bool }


{-| todo fix this; if there's no team, do something sensible
-}
getCurrentTeam : Battlefield -> Result String Team
getCurrentTeam b =
    b.teams |> RollingList.current |> Result.fromMaybe "There's no team left!"


getTeamMembers : Dict Hash Cell -> Team -> Dict Hash Cell
getTeamMembers cells team =
    Dict.filter (\k v -> v.character |> Maybe.map (.team >> (==) team) |> Maybe.withDefault False) cells


randomCell : Dict Hash Cell -> Random.Generator (Maybe ( Hash, Cell ))
randomCell =
    Dict.toList >> Random.List.choose >> Random.map Tuple.first


inRange : ( Hash, Cell ) -> ( Hash, Cell ) -> Bool
inRange (( _, a ) as srcRef) (( _, b ) as destRef) =
    Hexagons.Hex.distance a.hex b.hex <= 1 && (Maybe.map2 (\c1 c2 -> c1.team /= c2.team) a.character b.character |> Maybe.withDefault True)


randomDestination : ( Hash, Cell ) -> Dict Hash Cell -> Random.Generator (Maybe ( Hash, Cell ))
randomDestination (( hash, cell ) as cellRef) =
    Dict.filter (\k v -> Tuple.pair k v |> inRange cellRef)
        >> Dict.toList
        >> Random.List.choose
        >> Random.map Tuple.first


randomFight : ( Hash, Cell ) -> ( Hash, Cell ) -> Random.Generator FightResult
randomFight srcRef destRef =
    Random.int 0 1 |> Random.map ((==) 1) |> Random.map (FightResult srcRef destRef)


nextMove : Battlefield -> Result String Battlefield
nextMove battlefield =
    getCurrentTeam battlefield
        |> Result.map (getTeamMembers battlefield.cells)
        |> Result.map randomCell
        |> Result.map (always battlefield)



-- let
--     (x, seed1) = Random.step (Random.int 0 100) battlefield.seed
--     (y, seed2) = Random.step (Random.int 0 100) seed1
--     (z, seed3) = Random.step (Random.int 0 100) seed2


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( model, msg ) of
        ( Init state, New ) ->
            ( toGettingTimeForNewSeed state, Task.perform Tick Time.now )

        ( Init state, Import ) ->
            ( toGettingMapJson state Nothing "" Nothing, Cmd.none )

        ( Init _, Restart ) ->
            ( toGettingSeed (State { maybeBattlefield = Nothing }) Nothing, Cmd.none )

        ( GettingTimeForNewSeed state, Tick posix ) ->
            ( toWaitingForStart state (initBattlefield <| Time.posixToMillis posix), Cmd.none )

        ( GettingSeed state, SeedChanged seedSeed ) ->
            ( toGettingSeed state seedSeed, Cmd.none )

        ( GettingSeed state, UseSeed ) ->
            case state |> untag |> .seedSeed of
                Just seedSeed ->
                    ( toWaitingForStart state <| initBattlefield <| seedSeed, Cmd.none )

                Nothing ->
                    invalidMessageState

        ( GettingMapJson (State state), MapJsonChanged mapJson ) ->
            case mapJson |> D.decodeString decodeBattlefield |> Result.mapError D.errorToString of
                Ok newBattlefield ->
                    ( GettingMapJson <| State { state | mapJson = mapJson, maybeNewBattlefield = Just newBattlefield }, Cmd.none )

                Err string ->
                    ( GettingMapJson <| State { state | mapJson = string, maybeNewBattlefield = Nothing }, Cmd.none )

        ( GettingMapJson state, Import ) ->
            case state |> untag |> .maybeNewBattlefield of
                Just newBattlefield ->
                    ( toWaitingForStart state newBattlefield, Cmd.none )

                Nothing ->
                    invalidMessageState

        ( GettingMapJson state, Cancel ) ->
            case state |> untag |> .maybeBattlefield of
                Just battlefield ->
                    ( toWaitingForStart state battlefield, Cmd.none )

                Nothing ->
                    ( toInit, Cmd.none )

        ( WaitingForStart state, New ) ->
            ( toGettingTimeForNewSeed state, Task.perform Tick Time.now )

        ( WaitingForStart state, Restart ) ->
            ( toGettingSeed (State { maybeBattlefield = state |> untag |> Just }) (state |> untag |> .initialSeedSeed |> Just), Cmd.none )

        ( WaitingForStart state, Import ) ->
            ( toGettingMapJson state (state |> untag |> Just) (state |> untag |> encodeBattlefield |> E.encode 2) (state |> untag |> Just), Cmd.none )

        ( WaitingForStart state, Attack ) ->
            ( toAttacking state, Cmd.none )

        ( WaitingForStart state, Clicked cell ) ->
            ( model, Cmd.none )

        ( Attacking state, New ) ->
            ( toGettingTimeForNewSeed state, Task.perform Tick Time.now )

        ( Attacking state, Restart ) ->
            ( toGettingSeed (State { maybeBattlefield = state |> untag |> Just }) (state |> untag |> .initialSeedSeed |> Just), Cmd.none )

        ( Attacking state, Import ) ->
            ( toGettingMapJson state (state |> untag |> Just) (state |> untag |> encodeBattlefield |> E.encode 2) (state |> untag |> Just), Cmd.none )

        ( Attacking state, Clicked cell ) ->
            ( toAttacking (SM.map (\model2 -> { model2 | selectedCell = Just cell }) state), Cmd.none )

        ( Attacking state, Tick posix ) ->
            case nextMove <| untag <| state of
                Ok battlefield ->
                    ( toAttacking <| State <| battlefield, Cmd.none )

                Err error ->
                    crash error

        ( Ending state, New ) ->
            ( toGettingTimeForNewSeed state, Task.perform Tick Time.now )

        ( Ending state, Restart ) ->
            ( toGettingSeed (State { maybeBattlefield = state |> untag |> Just }) (state |> untag |> .initialSeedSeed |> Just), Cmd.none )

        ( Ending state, Import ) ->
            ( toGettingMapJson state (state |> untag |> Just) (state |> untag |> encodeBattlefield |> E.encode 2) (state |> untag |> Just), Cmd.none )

        ( Error state, New ) ->
            ( toGettingTimeForNewSeed state, Task.perform Tick Time.now )

        ( Error state, Restart ) ->
            ( toGettingSeed (State { maybeBattlefield = Nothing }) Nothing, Cmd.none )

        _ ->
            invalidMessageState


cellWidth =
    20.0


cellHeight =
    20.0


svgWidth =
    500


svgHeight =
    500


layout =
    { orientation = orientationLayoutPointy
    , size = ( cellWidth, cellHeight )
    , origin = ( 0.0, 0.0 )
    }


viewBoxStringCoords : String
viewBoxStringCoords =
    String.fromFloat (-cellWidth + cellWidth * 0.1)
        ++ " "
        ++ String.fromFloat -(cellHeight + 0)
        ++ " "
        ++ String.fromInt svgWidth
        ++ " "
        ++ String.fromInt svgHeight


{-| Helper to convert points to SVG string coordinates
-}
pointsToString : List Point -> String
pointsToString points =
    String.join " " (List.map pointToStringCoords points)


{-| Helper to convert points to SVG string coordinates
-}
pointToStringCoords : Point -> String
pointToStringCoords ( x, y ) =
    String.fromFloat x ++ "," ++ String.fromFloat y


mapPolygonCorners : Hex -> List Point
mapPolygonCorners =
    polygonCorners layout


hexGrid : Battlefield -> Html Msg
hexGrid battlefield =
    let
        toSvg : Hash -> Cell -> Svg Msg
        toSvg hexLocation cell =
            g
                []
                (toPolygon hexLocation (pointsToString <| mapPolygonCorners <| cell.hex))

        isSelected : Hash -> Bool
        isSelected hash =
            battlefield.selectedCell |> Maybe.map ((==) hash) |> Maybe.withDefault False

        normalCellColour hash =
            Dict.get hash battlefield.cells
                |> Maybe.andThen .character
                |> Maybe.map .team
                |> Maybe.map
                    (\team ->
                        case team of
                            Human ->
                                "red"

                            AI ->
                                "blue"
                    )
                |> Maybe.withDefault "lightgrey"

        selectedCellColour =
            "#777777"

        cellColour hash =
            if isSelected hash then
                selectedCellColour

            else
                normalCellColour hash

        toPolygon : Hash -> String -> List (Svg Msg)
        toPolygon hash cornersCoords =
            [ polygon
                [ style "cursor: pointer"
                , stroke "#ffff00"
                , strokeWidth "1px"
                , fill <|
                    cellColour hash
                , points cornersCoords
                , SvgEvents.onClick <|
                    Clicked hash
                ]
                []
            ]
    in
    g
        []
    <|
        Dict.values <|
            Dict.map toSvg battlefield.cells


inputDecoder : D.Decoder Msg
inputDecoder =
    D.map MapJsonChanged
        (D.at [ "target", "value" ] D.string)



-- (at [ "target", "scrollHeight" ] int)


viewNewButton : State { a | gettingTimeForNewSeed : Allowed } b -> Html Msg
viewNewButton _ =
    button [ Events.onClick New ] [ text "New Game" ]


viewRestartButton : State { a | gettingSeed : Allowed } b -> Html Msg
viewRestartButton _ =
    button [ Events.onClick Restart ] [ text "Restart Game" ]


viewImportButton : State { a | gettingMapJson : Allowed } b -> Html Msg
viewImportButton _ =
    button [ Events.onClick Import ] [ text "Import/Export Game" ]


viewCancelButton : State { a | waitingForStart : Allowed } b -> Html Msg
viewCancelButton _ =
    button [ Events.onClick Cancel ] [ text "Cancel" ]


viewAttackButton : State { a | attacking : Allowed } b -> Html Msg
viewAttackButton _ =
    button [ Events.onClick Attack ] [ text "Attack" ]


viewBattlefield : State { a | attacking : Allowed } Battlefield -> Html Msg
viewBattlefield state =
    svg
        [ version "1.1"
        , x "0"
        , y "0"
        , Svg.Attributes.height (String.fromInt svgHeight)
        , Svg.Attributes.width (String.fromInt svgWidth)
        , viewBox viewBoxStringCoords
        ]
        [ state |> untag |> lazy hexGrid
        ]


view : Model -> Browser.Document Msg
view model =
    let
        body =
            case model of
                Init state ->
                    [ viewNewButton state
                    , viewRestartButton state
                    , viewImportButton state
                    ]

                GettingTimeForNewSeed state ->
                    []

                GettingSeed state ->
                    [ Html.input [ Events.onInput (String.toInt >> SeedChanged), state |> untag |> .seedSeed |> Maybe.map String.fromInt |> Maybe.withDefault "" |> Attributes.value ]
                        []
                    , button [ Events.onClick UseSeed ] [ text "Use Seed" ]
                    ]

                GettingMapJson state ->
                    let
                        importButtonDisabled =
                            state |> untag |> .maybeNewBattlefield |> Maybe.Extra.isNothing
                    in
                    [ button [ Events.onClick Import, Attributes.disabled importButtonDisabled ] [ text "Import" ]
                    , viewCancelButton state
                    , br [] []
                    , textarea
                        [ Events.on "input" inputDecoder
                        , Attributes.cols 100
                        , Attributes.rows 10
                        ]
                        [ text (state |> untag |> .mapJson) ]
                    ]

                WaitingForStart state ->
                    [ div []
                        [ viewBattlefield state
                        , br [] []
                        , viewAttackButton state
                        , viewNewButton state
                        , viewRestartButton state
                        , viewImportButton state
                        ]
                    ]

                Attacking state ->
                    [ viewBattlefield state
                    , br [] []
                    , viewNewButton state
                    , viewRestartButton state
                    , viewImportButton state
                    ]

                Ending state ->
                    [ text "You won!"
                    , br [] []
                    , viewNewButton state
                    , viewRestartButton state
                    , viewImportButton state
                    ]

                Error state ->
                    [ h1 [] [ text "Error!" ]
                    , state |> untag |> .message |> text
                    , br [] []
                    , viewNewButton state
                    , viewRestartButton state
                    , viewImportButton state
                    ]
    in
    { title = "Elm Grid War"
    , body = body
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        Attacking _ ->
            Time.every 1000 Tick

        _ ->
            Sub.none


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , subscriptions = subscriptions
        , view = view
        , update = update
        }
