module Http exposing (..)

import Dict exposing (Dict)
import Json.Encode exposing (Value)
import Native.Http
import Task exposing (Task)


type alias Header =
    ( String, String )


type Error
    = Error


type alias Expect a =
    Response String -> Result String a


type alias Response a =
    { body : a
    , status : { code : Int, message : String }
    , url : String
    , headers : Dict String String
    }


type Body
    = Empty
    | Json Value
    | StringBody String
    | Multipart (List Part)


type Part
    = StringPart String String


type alias RequestConfig a =
    { expect : Expect a
    , url : String

    -- TODO define these
    , responseType : String
    , headers : List Header
    , method : String

    -- TODO define these
    , body : Body
    , withCredentials : Bool
    , timeout : Maybe Int
    }


getString : String -> Request String
getString url =
    { expect = .body >> Ok
    , url = url
    , headers = []
    , method = "GET"
    , responseType = "text"
    , body = Empty
    , withCredentials = False
    , timeout = Nothing
    }
        |> request


type Request a
    = Request


succeed : a -> Request a
succeed =
    Native.Http.succeed


request : RequestConfig a -> Request a
request =
    Native.Http.request


map : (a -> b) -> Request a -> Request b
map =
    Native.Http.map


map2 : (a -> b -> c) -> Request a -> Request b -> Request c
map2 =
    Native.Http.map2


andMap : Request a -> Request (a -> b) -> Request b
andMap =
    map2 (|>)


toTask : Request a -> Task Error a
toTask =
    Native.Http.toTask


send : (Result Error a -> msg) -> Request a -> Cmd msg
send tagger request =
    toTask request |> Task.attempt tagger
