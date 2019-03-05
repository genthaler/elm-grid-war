module View exposing (view)

import Dict
import Hexagons.Hex exposing (Hex)
import Hexagons.Layout exposing (Point, orientationLayoutPointy, polygonCorners)
import Hexagons.Map exposing (Hash, Map)
import Html exposing (Html, button, div, text, textarea)
import Html.Attributes as Attributes
import Html.Events as HtmlEvents
import Json.Decode as D
import Model exposing (Cell, Character, Class(..), Model, Msg(..), Team(..), Terrain(..))
import Svg exposing (Svg, g, polygon, svg)
import Svg.Attributes exposing (fill, points, stroke, strokeWidth, style, version, viewBox, x, y)
import Svg.Events as SvgEvents
import Svg.Lazy exposing (lazy, lazy2, lazy3)


cellWidth =
    40.0


cellHeight =
    40.0


svgWidth =
    1000


svgHeight =
    1000


layout =
    { orientation = orientationLayoutPointy
    , size = ( 40.0, 40.0 )
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
getCell ( key, hex ) =
    hex


mapPolygonCorners : Hex -> List Point
mapPolygonCorners =
    polygonCorners layout


hexGrid : Model -> Html Msg
hexGrid model =
    let
        toSvg : Hash -> String -> Svg Msg
        toSvg hexLocation cornersCoords =
            g
                []
                (toPolygon hexLocation cornersCoords)

        isSelected : Hash -> Bool
        isSelected hash =
            model.selectedCell |> Maybe.map ((==) hash) |> Maybe.withDefault False

        normalCellColour hash =
            case
                Dict.get hash model.cells
                    |> Maybe.map .terrain
                    |> Maybe.withDefault Grass
            of
                Grass ->
                    "#179f83"

                Rock ->
                    "#777777"

                Mountain ->
                    "#333333"

                Water ->
                    "#0000ff"

                Forest ->
                    "#11ff11"

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
            (Dict.keys model.map)
            (List.map (pointsToString << mapPolygonCorners << getCell) (Dict.toList model.map))


inputDecoder : D.Decoder Msg
inputDecoder =
    D.map ExportChanged
        (D.at [ "target", "value" ] D.string)



-- (at [ "target", "scrollHeight" ] int)


view : Model -> Html Msg
view model =
    div []
        [ svg
            [ version "1.1"
            , x "0"
            , y "0"
            , Svg.Attributes.height (String.fromInt svgHeight)
            , Svg.Attributes.width (String.fromInt svgWidth)
            , viewBox viewBoxStringCoords
            ]
            [ lazy hexGrid model
            ]
        , button [ HtmlEvents.onClick Export ] [ text "Export" ]
        , button [ HtmlEvents.onClick Import ] [ text "Import" ]
        , textarea
            [ HtmlEvents.on "input" inputDecoder
            , Attributes.cols 100
            , Attributes.rows 10
            ]
            [ text model.export ]
        ]
