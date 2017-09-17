module Main exposing (..)

import Html exposing (Html, text)
import Html.Events exposing (onClick)
import Http
import Task exposing (Task)


requestBoth : Task Http.Error ()
requestBoth =
    Http.map2 (\_ _ -> ())
        (Http.getString "/.gitpignore" |> Http.map (always ()))
        (Http.getString "/besluitvorming-frontend.zip" |> Http.map (always ()))
        |> Http.toTask


type Msg
    = Send
    | Receive Model


type alias Model =
    Result Http.Error ()


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Send ->
            ( model, requestBoth |> Task.attempt Receive )

        Receive m ->
            ( m, Cmd.none )


view : Model -> Html Msg
view model =
    Html.div []
        [ Html.pre [] [ Html.text <| toString model ]
        , Html.button [ onClick Send ] [ text "send" ]
        ]


main : Program Never Model Msg
main =
    Html.program
        { init = ( Ok (), Cmd.none )
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }
