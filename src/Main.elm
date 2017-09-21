module Main exposing (..)

import Html exposing (Html, text)
import Html.Events exposing (onClick)
import Json.Decode as JD
import Parallel.Http as Http
import RemoteData exposing (RemoteData(..), WebData)
import Task exposing (Task)


type alias Resp =
    { version : String, license : String }


requestBoth : Task Http.Error Resp
requestBoth =
    Http.map2 Resp
        (Http.get "/elm-package.json" (JD.field "summary" JD.string))
        (Http.get "/elm-package.json" (JD.field "license" JD.string))
        |> Http.andThen
            (\resp ->
                Http.get "/elm-package.json" (JD.field "version" JD.string)
                    |> Http.map (always resp)
            )
        |> Http.toTask


type Msg
    = Send
    | Receive Model


type alias Model =
    WebData Resp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Send ->
            ( Loading, requestBoth |> RemoteData.fromTask |> Task.perform Receive )

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
        { init = ( NotAsked, Cmd.none )
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }
