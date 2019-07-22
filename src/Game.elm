module Game exposing (Game, GameState(..), Msg(..), PositionStatus(..), init, update, view)

import Board exposing (..)
import Html exposing (Html, button, div, li, p, span, table, td, text, th, tr, ul)
import Html.Attributes exposing (attribute, class, style)
import Html.Events exposing (onClick)
import List.Extra as ElmList
import Player exposing (..)
import Random exposing (..)
import Random.Extra as ElmRandom



--TYPES


type Msg
    = NoOp
    | RestartGame
    | HumanVsHuman
    | HumanVsRandom
    | HumanVsSuper
    | MakeMove Int
    | RandomMove
    | SuperMove
    | HumanMove Int


type alias Document msg =
    { title : String
    , body : List (Html msg)
    }


type GameState
    = NewGame
    | InProgress
    | Won Player
    | Draw


type PositionStatus
    = Valid
    | PositionTaken


type alias ScoredPosition =
    { position : Int
    , score : Int
    }



--MODEL


type alias Game =
    { state : GameState
    , board : Board
    , currentPlayer : Player
    , opponent : Player
    , positionStatus : Maybe PositionStatus
    }



-- CREATE


init : () -> ( Game, Cmd Msg )
init _ =
    ( { state = NewGame
      , board = Board.init 3
      , currentPlayer = Player "O" Nothing
      , opponent = Player "X" Nothing
      , positionStatus = Nothing
      }
    , Cmd.none
    )



--UPDATE


update : Msg -> Game -> ( Game, Cmd Msg )
update msg ({ state, currentPlayer, opponent } as game) =
    case msg of
        NoOp ->
            ( game, Cmd.none )

        RestartGame ->
            ( { game | state = NewGame }, Cmd.none )

        HumanVsHuman ->
            let
                newGame =
                    init ()
                        |> Tuple.first
                        |> setMode Human Human
            in
            ( { newGame | state = InProgress }, Cmd.none )

        HumanVsRandom ->
            let
                newGame =
                    init ()
                        |> Tuple.first
                        |> setMode Human Random
            in
            ( { newGame | state = InProgress }, Cmd.none )

        HumanVsSuper ->
            let
                newGame =
                    init ()
                        |> Tuple.first
                        |> setMode Human Super
            in
            ( { newGame | state = InProgress }, Cmd.none )

        MakeMove position ->
            ( nextMove position game, Cmd.none )

        RandomMove ->
            ( game, Random.generate MakeMove (getRandomPosition game) )

        SuperMove ->
            update (MakeMove (getBestPosition game)) game

        HumanMove position ->
            let
                nextGame =
                    nextMove position game
            in
            case ( nextGame.positionStatus, nextGame.state, opponent.typePlayer ) of
                ( Just Valid, InProgress, Just Random ) ->
                    update RandomMove nextGame

                ( Just Valid, InProgress, Just Super ) ->
                    update SuperMove nextGame

                ( _, _, _ ) ->
                    ( nextGame, Cmd.none )



-- VIEW


view : Game -> Document Msg
view game =
    { title = "Tic tac toe"
    , body =
        case game.state of
            NewGame ->
                [ div [ class "centered" ]
                    [ div []
                        [ div [ class "title" ] [ text "Welcome to TTT" ]
                        , div [ class "subtitle" ] [ text "Choose a mode to play" ]
                        ]
                    , viewMode game
                    ]
                ]

            InProgress ->
                [ div [ class "centered" ]
                    [ div [ class "infoTitle" ] [ text "Play!" ]
                    , viewBoard game.board
                    , viewCurrentPlayer game
                    ]
                ]

            Draw ->
                [ div [ class "centered" ]
                    [ div [ class "infoTitle" ] [ text "OOhhhhhh" ]
                    , viewBoard game.board
                    , div [ class "subtitle" ] [ text "It's a draw" ]
                    , button [ class "restartButton", onClick RestartGame ] [ text "Restart game" ]
                    ]
                ]

            Won player ->
                [ div [ class "centered" ]
                    [ div [ class "infoTitle" ] [ text "🎊 Congrats! 🎊" ]
                    , viewBoard game.board
                    , div [ class "subtitle" ]
                        [ span [] [ viewPlayer player ]
                        , span [] [ text " won!" ]
                        ]
                    , button [ class "restartButton", onClick RestartGame ] [ text "Restart game" ]
                    ]
                ]
    }


viewMode : Game -> Html Msg
viewMode game =
    [ li [ class "mode", onClick HumanVsHuman, label "human-vs-human" ] [ text "Human vs Human" ]
    , li [ class "mode", onClick HumanVsRandom, label "human-vs-random" ] [ text "Human vs Random" ]
    , li [ class "mode", onClick HumanVsSuper ] [ text "Human vs Super" ]
    ]
        |> ul []


viewCurrentPlayer : Game -> Html Msg
viewCurrentPlayer game =
    [ span [ class "subtitle" ] [ text "Current player: " ]
    , ul [ class "listPlayers" ]
        [ li [ class "players" ] [ viewPlayer game.currentPlayer ]
        , li [ class "transparent players" ] [ viewPlayer game.opponent ]
        ]
    ]
        |> div [ class "footer" ]


viewPlayer : Player -> Html Msg
viewPlayer player =
    text player.mark


viewBoard : Board -> Html Msg
viewBoard board =
    board
        |> List.indexedMap Tuple.pair
        |> ElmList.groupsOf (Board.size board)
        |> List.map (\row -> viewRow row)
        |> table [ label "board" ]


label =
    attribute "data-label"


viewRow : List ( Int, String ) -> Html Msg
viewRow row =
    row
        |> List.map (\( index, position ) -> viewPosition index position)
        |> tr []


viewPosition : Int -> String -> Html Msg
viewPosition index position =
    td [ positionColor position, onClick (HumanMove index) ] [ text position ]


positionColor position =
    case position of
        "X" ->
            style "color" "red"

        "O" ->
            style "color" "blue"

        _ ->
            style "color" "black"



--TRANSFORM


setMode : TypePlayer -> TypePlayer -> Game -> Game
setMode type1 type2 ({ currentPlayer, opponent } as game) =
    { game | currentPlayer = Player.addType type1 currentPlayer, opponent = Player.addType type2 opponent }


nextMove : Int -> Game -> Game
nextMove position currentGame =
    let
        game =
            currentGame |> validatePosition position
    in
    if game.positionStatus == Just Valid then
        game
            |> updateBoard position
            |> updateState
            |> swapPlayers

    else
        game


getRandomPosition : Game -> Generator Int
getRandomPosition game =
    game.board
        |> Board.availablePositions
        |> ElmRandom.sample
        |> map (Maybe.withDefault 0)


validatePosition : Int -> Game -> Game
validatePosition position ({ currentPlayer, board } as game) =
    let
        updatedPositionStatus =
            if Board.positionAvailable position board then
                Just Valid

            else
                Just PositionTaken
    in
    { game | positionStatus = updatedPositionStatus }


swapPlayers : Game -> Game
swapPlayers ({ currentPlayer, opponent } as game) =
    { game | currentPlayer = opponent, opponent = currentPlayer }


updateState : Game -> Game
updateState ({ currentPlayer, opponent, board } as game) =
    let
        updatedState =
            if Board.isWinner currentPlayer board then
                Won currentPlayer

            else if Board.isWinner opponent board then
                Won opponent

            else if Board.full board then
                Draw

            else
                InProgress
    in
    { game | state = updatedState }


updateBoard : Int -> Game -> Game
updateBoard position ({ currentPlayer, board } as game) =
    { game | board = Board.register position currentPlayer board }



--MINIMAX


getBestPosition : Game -> Int
getBestPosition game =
    allPositionsScored game 0
        |> highestScoredPosition


highestScoredPosition : List ScoredPosition -> Int
highestScoredPosition positionsScored =
    positionsScored
        |> ElmList.maximumBy (\{ position, score } -> score)
        |> Maybe.withDefault (ScoredPosition 0 0)
        |> .position


allPositionsScored : Game -> Int -> List ScoredPosition
allPositionsScored game depth =
    game.board
        |> Board.availablePositions
        |> List.map (\position -> scoreEachPosition position game depth)


scoreEachPosition : Int -> Game -> Int -> ScoredPosition
scoreEachPosition position game depth =
    let
        newGame =
            nextMove position game
    in
    ScoredPosition position <| scorePosition newGame depth


scorePosition : Game -> Int -> Int
scorePosition ({ state, currentPlayer } as newGame) depth =
    case state of
        InProgress ->
            case currentPlayer.typePlayer of
                Just Super ->
                    allPositionsScored newGame (depth + 1)
                        |> highestScore

                _ ->
                    allPositionsScored newGame (depth + 1)
                        |> lowestScore

        Won player ->
            case player.typePlayer of
                Just Super ->
                    10 - depth

                _ ->
                    depth - 10

        _ ->
            0


highestScore : List ScoredPosition -> Int
highestScore positionsScores =
    positionsScores
        |> ElmList.maximumBy (\{ position, score } -> score)
        |> Maybe.withDefault (ScoredPosition 0 0)
        |> .score


lowestScore : List ScoredPosition -> Int
lowestScore positionsScores =
    positionsScores
        |> ElmList.minimumBy (\{ position, score } -> score)
        |> Maybe.withDefault (ScoredPosition 0 0)
        |> .score
