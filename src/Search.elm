module Search exposing
    ( minimax
    , alphabeta
    )

{-|


# Adversarial search strategies

@docs minimax, alphaBeta

-}

import Cons


{-|

    ```
    function minimax(node, depth, maximizingPlayer) is
        if depth = 0 or node is a terminal node then
            return the heuristic value of node
        if maximizingPlayer then
            value := −∞
            for each child of node do
                value := max(value, minimax(child, depth − 1, FALSE))
            return value
        else (* minimizing player *)
            value := +∞
            for each child of node do
                value := min(value, minimax(child, depth − 1, TRUE))
            return value

    minimax(origin, depth, TRUE)
    ```

-}
minimax : Int -> Bool -> (a -> Bool) -> (a -> comparable) -> (a -> List a) -> a -> comparable
minimax depth maximizingPlayer isTerminal heuristic getChildren node =
    if depth == 0 then
        heuristic node

    else if maximizingPlayer then
        case List.maximum <| List.map (minimax (depth - 1) (not maximizingPlayer) isTerminal heuristic getChildren) (getChildren node) of
            Nothing ->
                heuristic node

            Just max ->
                max

    else
        case List.minimum <| List.map (minimax (depth - 1) (not maximizingPlayer) isTerminal heuristic getChildren) (getChildren node) of
            Nothing ->
                heuristic node

            Just max ->
                max


{-|

    ```
    function alphabeta(node, depth, α, β, maximizingPlayer) is
        if depth = 0 or node is a terminal node then
            return the heuristic value of node
        if maximizingPlayer then
            value := −∞
            for each child of node do
                value := max(value, alphabeta(child, depth − 1, α, β, FALSE))
                α := max(α, value)
                if α ≥ β then
                    break (* β cut-off *)
            return value
        else
            value := +∞
            for each child of node do
                value := min(value, alphabeta(child, depth − 1, α, β, TRUE))
                β := min(β, value)
                if α ≥ β then
                    break (* α cut-off *)
            return value
    ```
    alphabeta(origin, depth, −∞, +∞, TRUE)

-}
alphabeta : Int -> comparable -> comparable -> Bool -> (a -> Bool) -> (a -> comparable) -> (a -> List a) -> a -> comparable
alphabeta depth0 positiveInfinity negativeInfinity maximizingPlayer0 isTerminal heuristic getChildren node0 =
    let
        alphabeta0 depth alpha beta maximizingPlayer node =
            if depth == 0 then
                heuristic node

            else
                case getChildren node of
                    [] ->
                        heuristic node

                    children ->
                        if maximizingPlayer then
                            let
                                cutoff value alpha2 beta2 children2 =
                                    case children2 of
                                        [] ->
                                            value

                                        child :: children3 ->
                                            let
                                                value2 =
                                                    Basics.max value (alphabeta0 (depth - 1) alpha2 beta2 (not maximizingPlayer) child)

                                                alpha3 =
                                                    Basics.max value2 alpha2
                                            in
                                            if alpha3 >= beta2 then
                                                value2

                                            else
                                                cutoff value2 alpha3 beta2 children3
                            in
                            cutoff -2.0 alpha beta children

                        else
                            let
                                cutoff value alpha2 beta2 children2 =
                                    case children2 of
                                        [] ->
                                            value

                                        child :: children3 ->
                                            let
                                                value2 =
                                                    Basics.max value (alphabeta0 (depth - 1) alpha2 beta2 (not maximizingPlayer) child)

                                                alpha3 =
                                                    Basics.max value2 alpha2
                                            in
                                            if alpha3 >= beta2 then
                                                value2

                                            else
                                                cutoff value2 alpha3 beta2 children3
                            in
                            cutoff -2.0 alpha beta children
    in
    alphabeta0 depth0 positiveInfinity negativeInfinity maximizingPlayer0 node0
