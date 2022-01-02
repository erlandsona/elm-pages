module Page.Form exposing (Data, Model, Msg, page)

import DataSource exposing (DataSource)
import Dict exposing (Dict)
import Form exposing (Form)
import Head
import Head.Seo as Seo
import Html
import Html.Attributes as Attr
import Page exposing (Page, PageWithState, StaticPayload)
import PageServerResponse exposing (PageServerResponse)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Server.Request as Request exposing (Request)
import Shared
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    Never


type alias RouteParams =
    {}


type alias User =
    { first : String
    , last : String
    , username : String
    , email : String
    , birthDay : String
    }


defaultUser : User
defaultUser =
    { first = "Jane"
    , last = "Doe"
    , username = "janedoe"
    , email = "janedoe@example.com"
    , birthDay = "1969-07-20"
    }


form : User -> Form User
form user =
    Form.succeed User
        |> Form.required
            (Form.input { name = "first", label = "First" }
                |> Form.withInitialValue user.first
            )
        |> Form.required
            (Form.input { name = "last", label = "Last" }
                |> Form.withInitialValue user.last
            )
        |> Form.required
            (Form.input { name = "username", label = "Username" }
                |> Form.withInitialValue user.username
                |> Form.withServerValidation
                    (\username ->
                        if username == "asdf" then
                            DataSource.succeed [ "username is taken" ]

                        else
                            DataSource.succeed []
                    )
            )
        |> Form.required
            (Form.input { name = "email", label = "Email" }
                |> Form.withInitialValue user.email
            )
        |> Form.required
            (Form.date { name = "dob", label = "Date of Birth" }
                |> Form.withInitialValue user.birthDay
                |> Form.withMinDate "1900-01-01"
                |> Form.withMaxDate "2022-01-01"
            )


page : Page RouteParams Data
page =
    Page.serverRender
        { head = head
        , data = data
        }
        |> Page.buildNoState { view = view }


type alias Data =
    { name : Maybe User
    , errors : Dict String (List String)
    }


data : RouteParams -> Request (DataSource (PageServerResponse Data))
data routeParams =
    Request.oneOf
        [ Form.toRequest2 (form defaultUser)
            |> Request.map
                (\userOrErrors ->
                    userOrErrors
                        |> DataSource.map
                            (\result ->
                                (case result of
                                    Ok user ->
                                        { name = Just user
                                        , errors = Dict.empty
                                        }

                                    Err errors ->
                                        { name = Nothing
                                        , errors = errors
                                        }
                                )
                                    |> PageServerResponse.RenderPage
                            )
                )
        , PageServerResponse.RenderPage
            { name = Nothing
            , errors = Dict.empty
            }
            |> DataSource.succeed
            |> Request.succeed
        ]


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "elm-pages"
        , image =
            { url = Pages.Url.external "TODO"
            , alt = "elm-pages logo"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = "TODO"
        , locale = Nothing
        , title = "TODO title" -- metadata.title -- TODO
        }
        |> Seo.website


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel static =
    let
        user =
            static.data.name
                |> Maybe.withDefault defaultUser
    in
    { title = "Form Example"
    , body =
        [ static.data.name
            |> Maybe.map
                (\user_ ->
                    Html.p
                        [ Attr.style "padding" "10px"
                        , Attr.style "background-color" "#a3fba3"
                        ]
                        [ Html.text <| "Successfully received user " ++ user_.first ++ " " ++ user_.last
                        ]
                )
            |> Maybe.withDefault (Html.p [] [])
        , Html.h1
            []
            [ Html.text <| "Edit profile " ++ user.first ++ " " ++ user.last ]
        , form user
            |> Form.toHtml static.data.errors
        ]
    }
