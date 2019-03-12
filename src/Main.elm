module Main exposing (main)

import Base64.Decode as D64
import Base64.Encode as E64
import Browser
import Dict exposing (Dict)
import Hexagons.Hex exposing (Direction(..), Hex)
import Hexagons.Layout exposing (Point, orientationLayoutPointy, polygonCorners)
import Hexagons.Map exposing (Hash, Map, rectangularPointyTopMap)
import Html exposing (Html, br, button, div, text, textarea)
import Html.Attributes as Attributes
import Html.Events as HtmlEvents
import Json.Decode as D
import Json.Decode.Extra as DExtra
import Json.Encode as E
import Json.Encode.Extra as EExtra
import List.Extra as LExtra
import Maybe exposing (Maybe(..))
import Maybe.Extra as MExtra
import Platform
import Platform.Sub
import Random
import Random.List
import Result.Extra as RExtra
import RollingList
import Set
import StateMachine as SM exposing (Allowed, State(..), map)
import Svg exposing (Svg, g, polygon, svg)
import Svg.Attributes exposing (fill, points, stroke, strokeWidth, style, version, viewBox, x, y)
import Svg.Events as SvgEvents
import Svg.Lazy exposing (lazy, lazy2, lazy3)
import Task
import Time


type Msg
    = NoOp
    | NewGame
    | RestartGame
    | ImportGame
    | Tick Time.Posix
    | Clicked Hash
    | Export
    | Import
    | ExportChanged String
    | GetSeed (Maybe Int)
    | UseSeed



{-
   Construct initial UI, new game/saved game/restart game (saved seed)
   If new game,
   - Get new seed
   - shuffle new map,
   - animate constructing map
   If restart game
   - enter seed (prefill with seed if available)
   - go
   - shuffle map with seed
   - animate
   If saved game,
   - Get saved map JSON
   - Go
   - Parse JSON into map

   - Display map

   - Start game
   - For each Team
       - if AI
           - for each Character in Team
               - find all valid directions to move
               - get random direction
               - if someone there
                   - fight them
               - else
                   go there
        - if Human
            later...
-}


type Model
    = Init (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } {})
    | GettingTimeForNewSeed (State { waitingForStart : Allowed } {})
    | GettingSeed (State { gettingSeed : Allowed, waitingForStart : Allowed } { seedSeed : Maybe Int })
    | GettingMapJson (State { waitingForStart : Allowed } {})
    | WaitForStart (State { attacking : Allowed } { battlefield : Battlefield })
    | Attacking (State { ending : Allowed } { battlefield : Battlefield, team : Team })
    | Ending (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } { team : Team })


toInit : Model
toInit =
    Init <| State {}


toGettingTimeForNewSeed : State { a | gettingTimeForNewSeed : Allowed } {} -> Model
toGettingTimeForNewSeed (State state) =
    GettingTimeForNewSeed <| State state


toGettingSeed : State { a | gettingSeed : Allowed } b -> Maybe Int -> Model
toGettingSeed (State _) seedSeed =
    GettingSeed <| State { seedSeed = seedSeed }


toGettingMapJson : State { a | gettingMapJson : Allowed } {} -> Model
toGettingMapJson (State state) =
    GettingMapJson <| State state


toWaitForStart : State { a | waitingForStart : Allowed } b -> Battlefield -> Model
toWaitForStart (State state) battlefield =
    WaitForStart <| State { battlefield = battlefield }


toAttacking : State { a | attacking : Allowed } { battlefield : Battlefield } -> Team -> Model
toAttacking (State state) team =
    Attacking <| State { battlefield = state.battlefield, team = team }


toEnding : State { a | ending : Allowed } { b | team : Team } -> Model
toEnding (State { team }) =
    Ending <| State { team = team }


type alias MoveState =
    { hash : Hash, movesLeft : Int }


type alias Battlefield =
    { map : Map
    , height : Int
    , width : Int
    , cells : Dict Hash Cell
    , selectedCell : Maybe Hash
    , export : String
    , teams : RollingList.RollingList Team
    }


directions =
    [ NE, E, SE, SW, W, NW ]


decodeBattlefield : D.Decoder Battlefield
decodeBattlefield =
    let
        gather c s h w =
            let
                map =
                    rectangularPointyTopMap h w
            in
            Battlefield map h w (Dict.fromList <| List.map2 Tuple.pair (Dict.keys map) c) s "" (cellsToTeams c)
    in
    D.map4
        gather
        (D.field "c" <| D.list decodeCell)
        (D.field "s" <| D.maybe decodeHash)
        (D.field "h" D.int)
        (D.field "w" D.int)


encodeModel model =
    E.object
        [ ( "c", E.list encodeCell <| Dict.values model.cells )
        , ( "s", EExtra.maybe encodeHash model.selectedCell )
        , ( "h", E.int model.height )
        , ( "w", E.int model.width )
        ]


type alias Cell =
    { terrain : Terrain
    , character : Maybe Character
    }


decodeCell =
    D.map2 Cell
        (D.field "t" decodeTerrain)
        (D.field "c" <| D.maybe decodeCharacter)


encodeCell cell =
    E.object
        [ ( "t", encodeTerrain cell.terrain )
        , ( "c", EExtra.maybe encodeCharacter cell.character )
        ]


type Terrain
    = Grass
    | Rock
    | Mountain
    | Water
    | Forest


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


type alias Character =
    { class : Class
    , team : Team
    }


decodeCharacter =
    D.map2 Character
        (D.field "c" decodeClass)
        (D.field "t" decodeTeam)


encodeCharacter character =
    E.object
        [ ( "c", encodeClass character.class )
        , ( "t", encodeTeam character.team )
        ]


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


type Team
    = Human
    | AI


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


decodeMap =
    D.map2 rectangularPointyTopMap
        (D.field "height" D.int)
        (D.field "width" D.int)


cellsToTeams : List Cell -> RollingList.RollingList Team
cellsToTeams cells =
    cells |> List.map .character |> MExtra.values |> List.map .team |> RollingList.fromList


initBattlefield : Random.Seed -> Battlefield
initBattlefield seed =
    let
        height =
            10

        width =
            10

        teamSize =
            10

        initialMap : Dict Hash Hexagons.Hex.Hex
        initialMap =
            rectangularPointyTopMap height width

        initialCells : Dict Hash Cell
        initialCells =
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
                        }
                    )
    in
    { map = initialMap
    , cells = initialCells
    , selectedCell = Nothing
    , height = height
    , width = width
    , export = ""
    , teams = initialCells |> Dict.values |> cellsToTeams
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



-- , Random.generate ShuffledCellList (initialCells |> Dict.toList |> Random.List.shuffle)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( NewGame, Init state ) ->
            ( toGettingTimeForNewSeed state, Task.perform Tick Time.now )

        ( RestartGame, Init state ) ->
            ( toGettingSeed state Nothing, Cmd.none )

        ( ImportGame, Init state ) ->
            ( model, Cmd.none )

        ( Tick posix, GettingTimeForNewSeed state ) ->
            ( toWaitForStart state <| initBattlefield <| Random.initialSeed <| Time.posixToMillis posix, Cmd.none )

        ( GetSeed seedSeed, GettingSeed state ) ->
            ( toGettingSeed state seedSeed, Cmd.none )

        ( UseSeed, GettingSeed state ) ->
            ( model, Cmd.none )
            -- ( toWaitForStart state <| initBattlefield <| Random.initialSeed <| Time.posixToMillis posix, Cmd.none )

        ( NoOp, GettingSeed state ) ->
            ( model, Cmd.none )

        ( NoOp, GettingMapJson state ) ->
            ( model, Cmd.none )

        ( NoOp, WaitForStart ((State { battlefield }) as state) ) ->
            ( model, Cmd.none )

        ( NoOp, Attacking ((State { battlefield, team }) as state) ) ->
            ( model, Cmd.none )

        ( NoOp, Ending ((State { team }) as state) ) ->
            ( model, Cmd.none )

        -- ( Tick posix, GettingTimeForNewSeed (State state) ) ->
        -- ( model, Random.generate RandomCell (Random.int 1 6) )
        -- ( model,  Cmd.none )
        -- (Clicked cell,  ->
        --     ( { model | selectedCell = Just cell }
        --     , Cmd.none
        --     )
        -- Export ->
        --     -- { model | export = encodeModel model |> E.encode 0 |> E64.string |> E64.encode }
        --     ( { model | export = encodeModel model |> E.encode 2 }, Cmd.none )
        -- Import ->
        --     -- case model.export |> D64.decode D64.string |> Result.mapError base64ErrorToString |> Result.andThen (D.decodeString decodeModel >> Result.mapError D.errorToString) of
        --     case model.export |> D.decodeString decodeBattlefield |> Result.mapError D.errorToString of
        --         Ok model2 ->
        --             ( { model2 | export = model.export }, Cmd.none )
        --         Err string ->
        --             ( { model | export = string }, Cmd.none )
        -- ExportChanged string ->
        --     ( { model | export = string }, Cmd.none )
        _ ->
            ( model, Cmd.none )


base64ErrorToString : D64.Error -> String
base64ErrorToString error =
    case error of
        D64.ValidationError ->
            "ValidationError"

        D64.InvalidByteSequence ->
            "InvalidByteSequence "


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


getCell : ( Hash, Hex ) -> Hex
getCell =
    Tuple.second


mapPolygonCorners : Hex -> List Point
mapPolygonCorners =
    polygonCorners layout


hexGrid : Battlefield -> Html Msg
hexGrid battlefield =
    let
        toSvg : Hash -> String -> Svg Msg
        toSvg hexLocation cornersCoords =
            g
                []
                (toPolygon hexLocation cornersCoords)

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
        List.map2 toSvg
            (Dict.keys battlefield.map)
            (List.map (pointsToString << mapPolygonCorners << getCell) (Dict.toList battlefield.map))


inputDecoder : D.Decoder Msg
inputDecoder =
    D.map ExportChanged
        (D.at [ "target", "value" ] D.string)



-- (at [ "target", "scrollHeight" ] int)


view : Model -> Browser.Document Msg
view model =
    let
        body =
            case model of
                Init _ ->
                    [ button [ HtmlEvents.onClick NewGame ] [ text "New Game" ]
                    , button [ HtmlEvents.onClick RestartGame ] [ text "Restart Game" ]
                    , button [ HtmlEvents.onClick ImportGame ] [ text "Import Game" ]
                    ]

                GettingTimeForNewSeed _ ->
                    []

                GettingSeed _ ->
                    [ Html.input [ HtmlEvents.onInput (String.toInt >> GetSeed) ]
                        []
                    , button [ HtmlEvents.onClick UseSeed ] [ text "Use Seed" ]
                    ]

                GettingMapJson _ ->
                    [ button [ HtmlEvents.onClick Import ] [ text "Import" ]
                    , br [] []
                    , textarea
                        [ HtmlEvents.on "input" inputDecoder
                        , Attributes.cols 100
                        , Attributes.rows 10
                        ]
                        [ text "" ]
                    ]

                WaitForStart (State { battlefield }) ->
                    [ div []
                        [ svg
                            [ version "1.1"
                            , x "0"
                            , y "0"
                            , Svg.Attributes.height (String.fromInt svgHeight)
                            , Svg.Attributes.width (String.fromInt svgWidth)
                            , viewBox viewBoxStringCoords
                            ]
                            [ lazy hexGrid battlefield
                            ]
                        , br [] []
                        , button [ HtmlEvents.onClick Export ] [ text "Export" ]
                        , button [ HtmlEvents.onClick Import ] [ text "Import" ]
                        , br [] []
                        , textarea
                            [ HtmlEvents.on "input" inputDecoder
                            , Attributes.cols 100
                            , Attributes.rows 10
                            ]
                            [ text "" ]

                        --model.export
                        ]
                    ]

                -- Attacking (State { ending : Allowed } { battlefield : Battlefield, team : Team })
                -- Ending (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } { team : Team })
                _ ->
                    []
    in
    { title = "Elm Grid War"
    , body = body
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    -- case model.gameState of
    -- Init ->
    --     Time.every 1000 Tick
    -- Attack AI ->
    --     Time.every 1000 Tick
    -- _ ->
    Sub.none


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , subscriptions = subscriptions
        , view = view
        , update = update
        }
