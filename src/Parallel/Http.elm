module Parallel.Http
    exposing
        ( Error
        , Expect
        , Part
        , Request
        , Response
        , andMap
        , andThen
        , expectJson
        , expectString
        , expectStringResponse
        , get
        , getString
        , header
        , map
        , map2
        , request
        , succeed
        , toTask
        )

import Dict exposing (Dict)
import Http
import Json.Decode exposing (Decoder, Value)
import Native.Http
import Task exposing (Task)


type alias Error =
    Http.Error


type Expect a
    = Expect
        { responseType : String
        , responseToResult : Response String -> Result String a
        }


expectStringResponse : (Response String -> Result String a) -> Expect a
expectStringResponse responseToResult =
    Expect { responseType = "text", responseToResult = responseToResult }


expectString : Expect String
expectString =
    (.body >> Ok)
        |> expectStringResponse


expectJson : Decoder a -> Expect a
expectJson decoder =
    (.body >> Json.Decode.decodeString decoder)
        |> expectStringResponse


type alias Response a =
    { body : a
    , status : { code : Int, message : String }
    , url : String
    , headers : Dict String String
    }


type Part
    = StringPart String String


header : String -> String -> Http.Header
header =
    Http.header


getString : String -> Request String
getString url =
    { expect = expectString
    , url = url
    , headers = []
    , method = "GET"
    , body = Http.emptyBody
    , withCredentials = False
    , timeout = Nothing
    }
        |> request


get : String -> Decoder a -> Request a
get url decoder =
    { expect = expectJson decoder
    , url = url
    , headers = []
    , method = "GET"
    , body = Http.emptyBody
    , withCredentials = False
    , timeout = Nothing
    }
        |> request


type Request a
    = Request


succeed : a -> Request a
succeed =
    Native.Http.succeed


request :
    { expect : Expect a
    , url : String
    , headers : List Http.Header
    , method : String
    , body : Http.Body
    , withCredentials : Bool
    , timeout : Maybe Int
    }
    -> Request a
request =
    Native.Http.request


map : (a -> b) -> Request a -> Request b
map =
    Native.Http.map


map2 : (a -> b -> c) -> Request a -> Request b -> Request c
map2 =
    Native.Http.map2


andThen : (a -> Request b) -> Request a -> Request b
andThen =
    Native.Http.andThen


andMap : Request a -> Request (a -> b) -> Request b
andMap =
    map2 (|>)


toTask : Request a -> Task Error a
toTask =
    Native.Http.toTask


send : (Result Error a -> msg) -> Request a -> Cmd msg
send tagger request =
    toTask request |> Task.attempt tagger
