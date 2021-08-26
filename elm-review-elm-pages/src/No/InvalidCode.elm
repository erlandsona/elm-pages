module No.InvalidCode exposing (rule)

{-|

@docs rule

-}

import Elm.Syntax.Declaration as Declaration exposing (Declaration)
import Elm.Syntax.Exposing as Exposing
import Elm.Syntax.Module as Module exposing (Module)
import Elm.Syntax.Node as Node exposing (Node)
import Elm.Syntax.TypeAnnotation as TypeAnnotation exposing (TypeAnnotation)
import Result.Extra
import Review.Rule as Rule exposing (Direction, Error, Rule)
import Set exposing (Set)


{-| Reports... REPLACEME

    config =
        [ No.InvalidCode.rule
        ]


## Fail

    a =
        "REPLACEME example to replace"


## Success

    a =
        "REPLACEME example to replace"


## When (not) to enable this rule

This rule is useful when REPLACEME.
This rule is not useful when REPLACEME.


## Try it out

You can try this rule out by running the following command:

```bash
elm-review --template dillonkearns/elm-review-elm-pages/example --rules No.InvalidCode
```

-}
rule : Rule
rule =
    Rule.newModuleRuleSchema "NoMissingDocumentationForExposedFunctions" { moduleName = [] }
        |> Rule.withModuleDefinitionVisitor moduleDefinitionVisitor
        |> Rule.withDeclarationVisitor declarationVisitor
        |> Rule.fromModuleRuleSchema


type alias Context =
    { moduleName : List String
    }


moduleDefinitionVisitor : Node Module -> Context -> ( List (Error {}), Context )
moduleDefinitionVisitor node context =
    case Node.value node |> Module.exposingList of
        Exposing.All _ ->
            ( []
            , { moduleName = Node.value node |> Module.moduleName
              }
            )

        Exposing.Explicit exposedValues ->
            case Set.diff (Set.fromList [ "Data", "Msg", "Model", "page" ]) (exposedNames exposedValues) |> Set.toList of
                [] ->
                    ( []
                    , { moduleName = Node.value node |> Module.moduleName
                      }
                    )

                nonEmpty ->
                    ( [ Rule.error
                            { message = "Unexposed Declaration in Page Module"
                            , details =
                                [ """Page Modules need to expose the following values:

- page
- Data
- Model
- Msg

But it is not exposing: """
                                    ++ (nonEmpty |> String.join ", ")
                                ]
                            }
                            (Node.range node)
                      ]
                    , { moduleName = Node.value node |> Module.moduleName }
                    )


exposedFunctionName : Node Exposing.TopLevelExpose -> Maybe String
exposedFunctionName value =
    case Node.value value of
        Exposing.FunctionExpose functionName ->
            Just functionName

        _ ->
            Nothing


routeParamsMatchesNameOrError : Node a -> Node TypeAnnotation -> List String -> List (Error {})
routeParamsMatchesNameOrError typeAliasNode annotation moduleName =
    case stringFields typeAliasNode annotation of
        Err error ->
            [ error ]

        Ok actualStringFields ->
            let
                expectedFields =
                    expectedRouteParamsFromModuleName moduleName

                missingFields : Set String
                missingFields =
                    Set.diff
                        expectedFields
                        actualStringFields
            in
            case missingFields |> Set.toList of
                [] ->
                    []

                nonEmptyMissingFields ->
                    [ Rule.error
                        { message = "RouteParams don't match Page Module name"
                        , details =
                            [ """Expected

"""
                                ++ expectedFieldsToRecordString expectedFields
                                ++ "\n"
                            ]
                        }
                        (Node.range typeAliasNode)
                    ]


expectedFieldsToRecordString : Set String -> String
expectedFieldsToRecordString expectedFields =
    "type alias RouteParams = { "
        ++ (expectedFields
                |> Set.map (\name -> name ++ " : String")
                |> Set.toList
                |> String.join ", "
           )
        ++ " }"


expectedRouteParamsFromModuleName : List String -> Set String
expectedRouteParamsFromModuleName moduleSegments =
    case moduleSegments of
        "Page" :: segments ->
            segments
                |> List.filterMap segmentToParam
                |> Set.fromList

        _ ->
            Set.empty


segmentToParam : String -> Maybe String
segmentToParam segment =
    if segment |> String.endsWith "_" then
        segment
            |> String.dropRight 1
            |> String.toLower
            -- TODO turn to lowerCamelCase
            |> Just

    else
        Nothing


stringFields : Node a -> Node TypeAnnotation -> Result (Error {}) (Set String)
stringFields outerTypeAnnotation typeAnnotation =
    case Node.value typeAnnotation of
        TypeAnnotation.Record recordDefinition ->
            let
                fields : List (Result (Error {}) String)
                fields =
                    recordDefinition
                        |> List.map Node.value
                        |> List.map
                            (\( name, annotation ) ->
                                if Node.value annotation |> isString then
                                    Ok (Node.value name)

                                else
                                    Err
                                        (Rule.error
                                            { message = "All fields in the RouteParams record must be Strings"
                                            , details =
                                                [ """Expected String field but was """ ++ Node.value name
                                                ]
                                            }
                                            (Node.range annotation)
                                        )
                            )
            in
            fields
                |> Result.Extra.combine
                |> Result.map Set.fromList

        _ ->
            Err
                (Rule.error
                    { message = "RouteParams must be a record type alias."
                    , details =
                        [ """Expected a record type alias."""
                        ]
                    }
                    (Node.range outerTypeAnnotation)
                )


isString : TypeAnnotation -> Bool
isString typeAnnotation =
    case typeAnnotation of
        --(Node ( ModuleName, String )) (List (Node TypeAnnotation))
        TypeAnnotation.Typed moduleContext _ ->
            -- TODO need to use module lookup table to handle Basics or aliases?
            if Node.value moduleContext == ( [], "String" ) then
                True

            else
                Debug.todo (Debug.toString moduleContext)

        _ ->
            False


declarationVisitor : Node Declaration -> Direction -> Context -> ( List (Error {}), Context )
declarationVisitor node direction context =
    case ( direction, Node.value node ) of
        ( Rule.OnEnter, Declaration.AliasDeclaration { name, generics, typeAnnotation } ) ->
            -- TODO check that generics is empty
            if Node.value name == "RouteParams" then
                ( routeParamsMatchesNameOrError node typeAnnotation context.moduleName
                , context
                )

            else
                ( [], context )

        _ ->
            ( [], context )


exposedNames : List (Node Exposing.TopLevelExpose) -> Set String
exposedNames exposedValues =
    exposedValues
        |> List.filterMap (Node.value >> getExposedName)
        |> Set.fromList


getExposedName : Exposing.TopLevelExpose -> Maybe String
getExposedName exposedValue =
    case exposedValue of
        Exposing.FunctionExpose name ->
            Just name

        Exposing.InfixExpose string ->
            Nothing

        Exposing.TypeOrAliasExpose name ->
            Just name

        Exposing.TypeExpose exposedType ->
            Just exposedType.name
