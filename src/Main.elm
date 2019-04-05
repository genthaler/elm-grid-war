module Main exposing (main)

import Basics.Extra exposing (curry, flip, uncurry)
import Bool.Extra
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
import Pair
import Platform
import Platform.Sub
import Random exposing (Generator, Seed)
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



-- Model


type Msg
    = NoOp
    | New
    | Restart
    | Import
    | MapJsonChanged String
    | SeedChanged (Maybe Int)
    | UseSeed
    | Tick Time.Posix
    | Attack
    | Clicked Hash
    | Cancel


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
    , movesLeft : Int
    , experience : Int
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


type alias CellMap =
    Dict Hash Cell


type alias CellRef =
    ( Hash, Cell )


type alias CellRefPair =
    ( CellRef, CellRef )


type alias Battlefield =
    { height : Int
    , width : Int
    , cells : CellMap
    , selectedCell : Maybe Hash
    , teams : RollingList.RollingList Team
    , seed : Seed
    , initialSeedSeed : Int
    , messages : List String
    }


directions =
    [ NE, E, SE, SW, W, NW ]


type Model
    = Init (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } {})
    | GettingTimeForNewSeed (State { waitingForStart : Allowed } {})
    | GettingSeed (State { gettingSeed : Allowed, waitingForStart : Allowed } { maybeBattlefield : Maybe Battlefield, seedSeed : Maybe Int })
    | GettingMapJson (State { waitingForStart : Allowed } { maybeBattlefield : Maybe Battlefield, mapJson : String, maybeNewBattlefield : Maybe Battlefield })
    | WaitingForStart (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed, attacking : Allowed } Battlefield)
    | Attacking (State { attacking : Allowed, gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed, turningOver : Allowed, ending : Allowed } Battlefield)
    | TurningOver (State { attacking : Allowed, gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } Battlefield)
    | Ending (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } Battlefield)
    | Error (State { gettingTimeForNewSeed : Allowed, gettingSeed : Allowed, gettingMapJson : Allowed } { message : String })



-- Model Encoders/Decoders


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
    D.map4 Character
        (D.field "c" decodeClass)
        (D.field "t" decodeTeam)
        (D.succeed 0)
        (D.succeed 1)


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
            Battlefield h w mergedCells s allTeams (Random.initialSeed 1) 1 []
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



-- State Machine


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


toTurningOver : State { a | turningOver : Allowed } Battlefield -> Model
toTurningOver (State state) =
    TurningOver <| State state


toEnding : State { a | ending : Allowed } Battlefield -> Model
toEnding (State state) =
    Ending <| State state


toError : String -> Model
toError message =
    Error <| State { message = message }



-- Init


allTeams =
    RollingList.fromList [ AI, Human ]


randomCellRef seed0 (( hash, hex ) as cellRef0) =
    let
        ( x, seed1 ) =
            Random.step (Random.int 0 10) seed0

        cellRef1 =
            ( hash
            , { terrain = Grass
              , character =
                    case x of
                        0 ->
                            Just <| Character Peasant Human 1 0

                        1 ->
                            Just <| Character Peasant AI 1 0

                        _ ->
                            Nothing
              , hex = hex
              }
            )
    in
    ( seed1, cellRef1 )


mapHeight =
    10


mapWidth =
    10


initBattlefield : Int -> Battlefield
initBattlefield seedSeed =
    let
        seed =
            Random.initialSeed seedSeed

        teamSize =
            10

        ( newSeed, randomCells ) =
            rectangularPointyTopMap mapHeight mapWidth
                |> Dict.toList
                |> LExtra.mapAccuml randomCellRef seed
                |> Tuple.mapSecond Dict.fromList
    in
    { height = mapHeight
    , width = mapWidth
    , cells = randomCells
    , selectedCell = Nothing
    , teams = allTeams
    , seed = newSeed
    , initialSeedSeed = seedSeed
    , messages = []
    }


init : flags -> ( Model, Cmd Msg )
init _ =
    ( toInit, Cmd.none )



-- Update


crash message =
    ( toError message, Cmd.none )


invalidMessageState =
    crash "Unexpected message/state combination"


randomDice : Int -> Int -> Generator Bool
randomDice max succeed =
    Random.int 1 max |> Random.map ((<=) succeed)


randomCell : CellMap -> Generator (Result String CellRef)
randomCell =
    Dict.toList
        >> Random.List.choose
        >> Random.map Tuple.first
        >> Random.map (Result.fromMaybe "Couldn't find a fighter")


getCurrentTeam : Battlefield -> Result String Team
getCurrentTeam b =
    b.teams |> RollingList.current |> Result.fromMaybe "There's no team left!"


getTeamMembersWithMoves : Team -> Dict Hash Cell -> Dict Hash Cell
getTeamMembersWithMoves team =
    Dict.filter
        (\k v ->
            v.character
                |> Maybe.map (Bool.Extra.allPass [ .team >> (==) team, .movesLeft >> (<) 0 ])
                |> Maybe.withDefault False
        )


resetMovesLeft : Battlefield -> Battlefield
resetMovesLeft battlefield =
    let
        reset =
            mapBattlefieldCells
                << Dict.map
                << always
                << mapCellCharacter
                << Maybe.map
            <|
                \character ->
                    { character
                        | movesLeft =
                            if character.team == (battlefield.teams |> RollingList.current |> Maybe.withDefault AI) then
                                1

                            else
                                character.movesLeft
                    }
    in
    reset battlefield


mapBattlefieldCells : (CellMap -> CellMap) -> Battlefield -> Battlefield
mapBattlefieldCells f battlefield =
    { battlefield | cells = f battlefield.cells }


mapBattlefieldTeams : (RollingList.RollingList Team -> RollingList.RollingList Team) -> Battlefield -> Battlefield
mapBattlefieldTeams f battlefield =
    { battlefield | teams = f battlefield.teams }


mapBattlefieldMessages : (List String -> List String) -> Battlefield -> Battlefield
mapBattlefieldMessages f battlefield =
    { battlefield | messages = f battlefield.messages }


mapCellCharacter : (Maybe Character -> Maybe Character) -> Cell -> Cell
mapCellCharacter f cell =
    { cell | character = f cell.character }


mapCharacterMovesLeft : (Int -> Int) -> Character -> Character
mapCharacterMovesLeft f character =
    { character | movesLeft = f character.movesLeft }


mapMovesLeft : (Int -> Int) -> CellRef -> CellRef
mapMovesLeft =
    Tuple.mapSecond << mapCellCharacter << Maybe.map << mapCharacterMovesLeft


decrementMovesLeft : CellRef -> CellRef
decrementMovesLeft =
    mapMovesLeft ((+) -1)


allMoves : CellRef -> CellMap -> List CellRefPair
allMoves cellRef =
    Dict.toList >> List.map (Pair.pair cellRef)


inRange : CellRefPair -> Bool
inRange =
    Pair.map (Pair.second >> .hex)
        >> Pair.fold Hexagons.Hex.distance
        >> (>=) 1


sameCellRef : CellRefPair -> Bool
sameCellRef =
    Pair.fold (==)


sameTeam : CellRefPair -> Bool
sameTeam =
    Pair.map (Pair.second >> .character >> Maybe.map .team)
        >> Pair.fold (Maybe.map2 (==))
        >> Maybe.withDefault False


validMoves : CellRef -> CellMap -> List CellRefPair
validMoves cellRef =
    allMoves cellRef >> List.filter (Bool.Extra.allPass [ not << sameCellRef, not << sameTeam, inRange ])


randomMove : CellRef -> CellMap -> Generator (Result String CellRefPair)
randomMove (( hash, cell ) as cellRef) =
    validMoves cellRef
        >> Random.List.choose
        >> Random.map Pair.first
        >> Random.map (Result.fromMaybe "Couldn't find a destination")


moveTo : CellRefPair -> CellRefPair
moveTo ( ( srcHash, srcCell ), ( destHash, destCell ) ) =
    ( ( srcHash, { srcCell | character = Nothing } )
    , ( destHash, { destCell | character = srcCell.character } )
    )


subsume : CellRefPair -> CellRefPair
subsume ( ( srcHash, srcCell ), ( destHash, destCell ) ) =
    ( ( srcHash, { srcCell | character = Nothing } )
    , ( destHash
      , { destCell
            | character =
                destCell.character
                    |> Maybe.map2
                        (\srcCharacter destCharacter ->
                            { destCharacter | experience = destCharacter.experience + srcCharacter.experience }
                        )
                        srcCell.character
        }
      )
    )


updateCellRef : CellRef -> Battlefield -> Battlefield
updateCellRef (( hash, cell ) as cellRef) battlefield =
    { battlefield | cells = Dict.insert hash cell battlefield.cells }


updateCellRefPair : CellRefPair -> Battlefield -> Battlefield
updateCellRefPair ( cellRef1, cellRef2 ) =
    updateCellRef cellRef1 >> updateCellRef cellRef2


removeFrom : CellRef -> CellRef
removeFrom =
    Tuple.mapSecond << mapCellCharacter <| always Nothing


fight : CellRefPair -> Battlefield -> Bool -> Result String Battlefield
fight ( srcRef, destRef ) battlefield win =
    battlefield
        |> (if win then
                updateCellRefPair (subsume ( srcRef, destRef ))

            else
                updateCellRef (removeFrom srcRef)
           )
        |> Ok


randomFight : CellRefPair -> Battlefield -> Generator (Result String Battlefield)
randomFight ( srcRef, destRef ) battlefield =
    randomDice 2 1
        |> Random.map (fight ( srcRef, destRef ) battlefield)


randomGo : CellRefPair -> Battlefield -> Generator (Result String Battlefield)
randomGo pair =
    Random.constant << Ok << updateCellRefPair (moveTo pair)


randomFightOrGo : CellRefPair -> Battlefield -> Generator (Result String Battlefield)
randomFightOrGo ( ( _, src ) as srcRef, ( _, dest ) as destRef ) =
    case ( src.character, dest.character ) of
        ( Just srcTeam, Just destTeam ) ->
            if srcTeam /= destTeam then
                randomFight ( srcRef, destRef )

            else
                Random.constant << always (Err "We're trying to fight a team mate, shouldn't have happened")

        _ ->
            randomGo ( srcRef, destRef )


liftRandomMaybe : x -> ( Maybe a, b ) -> Result x ( a, b )
liftRandomMaybe x ( a, b ) =
    Maybe.map (flip Tuple.pair b) a |> Result.fromMaybe x


liftResultRandom : ( Result x a, b ) -> Result x ( a, b )
liftResultRandom ( a, b ) =
    Result.map (flip Tuple.pair b) a


nextMove : Battlefield -> Result String Battlefield
nextMove battlefield =
    getCurrentTeam battlefield
        |> Result.map (flip getTeamMembersWithMoves battlefield.cells)
        |> Result.andThen (\cells -> Random.step (randomCell cells) battlefield.seed |> liftResultRandom)
        |> Result.map (\( cell, seed ) -> ( decrementMovesLeft cell, seed ))
        |> Result.andThen (\( cell, seed ) -> Random.step (randomMove cell battlefield.cells) seed |> liftResultRandom)
        |> Result.andThen (\( pair, seed ) -> Random.step (randomFightOrGo pair battlefield) seed |> liftResultRandom)
        |> Result.map (\( battlefield2, seed ) -> { battlefield2 | seed = seed })


perform : msg -> Cmd msg
perform msg =
    Task.perform identity (Task.succeed msg)


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

        ( Attacking (State startingBattlefield), Tick posix ) ->
            case nextMove startingBattlefield of
                Ok newBattlefield ->
                    ( toAttacking <| State <| newBattlefield, Cmd.none )

                Err error ->
                    ( toTurningOver <| State <| mapBattlefieldMessages ((::) error) <| startingBattlefield, perform NoOp )

        ( TurningOver (State startingBattlefield), NoOp ) ->
            ( toTurningOver <| State <| resetMovesLeft <| mapBattlefieldTeams RollingList.roll <| mapBattlefieldMessages ((::) "End of turn") <| startingBattlefield
            , perform Attack
            )

        ( TurningOver (State startingBattlefield), Attack ) ->
            ( toAttacking <| State <| startingBattlefield, Cmd.none )

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



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        Attacking _ ->
            Time.every 100 Tick

        _ ->
            Sub.none



-- View


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
    String.join " "
        [ String.fromFloat (-cellWidth + cellWidth * 0.1)
        , String.fromFloat -(cellHeight + 0)
        , String.fromInt svgWidth
        , String.fromInt svgHeight
        ]


{-| Helper to convert points to SVG string coordinates
-}
pointsToString : List Point -> String
pointsToString points =
    String.join " " (List.map pointToStringCoords points)


{-| Helper to convert points to SVG string coordinates
-}
pointToStringCoords : Point -> String
pointToStringCoords ( x, y ) =
    String.join "," [ String.fromFloat x, String.fromFloat y ]


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
                [ Svg.text_ [] [ Svg.text "hello" ] ]
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



-- viewMessages State a Battlefield -> Html Msg


viewMessages (State battlefield) =
    Html.ul [] <|
        List.map (\string -> Html.li [] [ text string ]) battlefield.messages


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
                    , viewMessages state
                    ]

                TurningOver state ->
                    [ viewBattlefield state
                    , br [] []
                    , viewAttackButton state
                    , viewNewButton state
                    , viewRestartButton state
                    , viewImportButton state
                    , viewMessages state
                    ]

                Ending state ->
                    [ text "You won!"
                    , br [] []
                    , viewNewButton state
                    , viewRestartButton state
                    , viewImportButton state
                    , viewMessages state
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


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , subscriptions = subscriptions
        , view = view
        , update = update
        }
