module Main exposing (main)

import Color
import Data.Author
import Element exposing (Element)
import Element.Font as Font
import Global
import GlobalMetadata
import MarkdownRenderer
import MetadataNew
import MySitemap
import Pages exposing (images, pages)
import Pages.Manifest as Manifest
import Pages.Manifest.Category
import Pages.PagePath as PagePath exposing (PagePath)
import Pages.Platform exposing (Page)
import Rss
import RssPlugin
import SiteConfig
import TemplateDemultiplexer


manifest : Manifest.Config Pages.PathKey
manifest =
    { backgroundColor = Just Color.white
    , categories = [ Pages.Manifest.Category.education ]
    , displayMode = Manifest.Standalone
    , orientation = Manifest.Portrait
    , description = "elm-pages - A statically typed site generator."
    , iarcRatingId = Nothing
    , name = "elm-pages docs"
    , themeColor = Just Color.white
    , startUrl = pages.blog.staticHttp
    , shortName = Just "elm-pages"
    , sourceIcon = images.iconPng
    }


main : Pages.Platform.Program TemplateDemultiplexer.Model TemplateDemultiplexer.Msg GlobalMetadata.Metadata Global.RenderedBody
main =
    TemplateDemultiplexer.mainTemplate
        { documents =
            [ { extension = "md"
              , metadata = MetadataNew.decoder
              , body = MarkdownRenderer.view
              }
            ]
        , manifest = SiteConfig.manifest
        , canonicalSiteUrl = SiteConfig.canonicalUrl
        , subscriptions = \_ -> Sub.none
        }
        |> RssPlugin.generate
            { siteTagline = siteTagline
            , siteUrl = canonicalSiteUrl
            , title = "elm-pages Blog"
            , builtAt = Pages.builtAt
            , indexPage = Pages.pages.blog.index
            }
            metadataToRssItem
        |> MySitemap.install { siteUrl = canonicalSiteUrl } metadataToSitemapEntry
        |> Pages.Platform.toProgram


metadataToRssItem :
    { path : PagePath Pages.PathKey
    , frontmatter : GlobalMetadata.Metadata
    , body : String
    }
    -> Maybe Rss.Item
metadataToRssItem page =
    case page.frontmatter of
        GlobalMetadata.MetadataBlogPost blogPost ->
            if blogPost.draft then
                Nothing

            else
                Just
                    { title = blogPost.title
                    , description = blogPost.description
                    , url = PagePath.toString page.path
                    , categories = []
                    , author = blogPost.author.name
                    , pubDate = Rss.Date blogPost.published
                    , content = Nothing
                    }

        _ ->
            Nothing


metadataToSitemapEntry :
    List
        { path : PagePath Pages.PathKey
        , frontmatter : GlobalMetadata.Metadata
        , body : String
        }
    -> List { path : String, lastMod : Maybe String }
metadataToSitemapEntry siteMetadata =
    siteMetadata
        |> List.filter
            (\page ->
                case page.frontmatter of
                    GlobalMetadata.MetadataBlogPost blogPost ->
                        not blogPost.draft

                    _ ->
                        True
            )
        |> List.map
            (\page ->
                { path = PagePath.toString page.path, lastMod = Nothing }
            )


type alias Model =
    { showMobileMenu : Bool
    }


type Msg
    = OnPageChange
        { path : PagePath Pages.PathKey
        , query : Maybe String
        , fragment : Maybe String
        }
    | ToggleMobileMenu


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnPageChange page ->
            ( { model | showMobileMenu = False }, Cmd.none )

        ToggleMobileMenu ->
            ( { model | showMobileMenu = not model.showMobileMenu }, Cmd.none )


canonicalSiteUrl : String
canonicalSiteUrl =
    "https://elm-pages.com"


siteTagline : String
siteTagline =
    "A statically typed site generator - elm-pages"


tocView : MarkdownRenderer.TableOfContents -> Element msg
tocView toc =
    Element.column [ Element.alignTop, Element.spacing 20 ]
        [ Element.el [ Font.bold, Font.size 22 ] (Element.text "Table of Contents")
        , Element.column [ Element.spacing 10 ]
            (toc
                |> List.map
                    (\heading ->
                        Element.link [ Font.color (Element.rgb255 100 100 100) ]
                            { url = "#" ++ heading.anchorId
                            , label = Element.text heading.name
                            }
                    )
            )
        ]
