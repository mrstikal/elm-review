module Lint.Rule.DefaultPatternPosition exposing (rule, Configuration, PatternPosition(..))

{-|

@docs rule, Configuration, PatternPosition


# Fail

    rules =
        [ DefaultPatternPosition.rule { position = Lint.Rules.DefaultPatternPosition.Last }
        ]

    case value of
      -- LintError, this pattern should appear last
      _ -> result
      Foo -> bar

    -- --------------------

    rules =
        [ DefaultPatternPosition.rule { position = Lint.Rules.DefaultPatternPosition.First }
        ]

    case value of
      Foo -> bar
      -- LintError, this pattern should appear first
      _ -> result


# Success

    rules =
        [ DefaultPatternPosition.rule { position = Lint.Rules.DefaultPatternPosition.Last }
        ]

    case value of
      Foo -> bar
      _ -> result

    case value of
      -- No default pattern
      Foo -> bar
      Bar -> foo

    -- --------------------

    rules =
        [ DefaultPatternPosition.rule { position = Lint.Rules.DefaultPatternPosition.First }
        ]

    case value of
      _ -> result
      Foo -> bar

-}

import Elm.Syntax.Expression exposing (Expression(..))
import Elm.Syntax.Node as Node exposing (Node)
import Elm.Syntax.Pattern exposing (Pattern(..))
import Lint.Error as Error exposing (Error)
import Lint.Rule as Rule exposing (Rule)
import List.Extra exposing (findIndex)
import Regex


{-| Configures whether the default pattern should appear first or last.
-}
type PatternPosition
    = First
    | Last


{-| Configuration for the rule.
-}
type alias Configuration =
    { position : PatternPosition
    }


{-| Enforce the default pattern to always appear first or last.
-}
rule : Configuration -> Rule
rule config =
    Rule.newRuleSchema "DefaultPatternPosition"
        |> Rule.withSimpleExpressionVisitor (expressionVisitor config)
        |> Rule.fromSchema


error : Node a -> String -> Error
error node message =
    Error.create message (Node.range node)



{- TODO Share isVariable this in a util file, already defined in NoUselessPatternMatching -}


isVariable : String -> Bool
isVariable =
    Regex.fromString "^[_a-z][\\w\\d]*$"
        |> Maybe.withDefault Regex.never
        |> Regex.contains


isDefaultPattern : Pattern -> Bool
isDefaultPattern pattern =
    case pattern of
        AllPattern ->
            True

        _ ->
            False


findDefaultPattern : List ( Node Pattern, Node Expression ) -> Maybe Int
findDefaultPattern patterns =
    patterns
        |> List.map (Tuple.first >> Node.value)
        |> findIndex isDefaultPattern


expressionVisitor : Configuration -> Node Expression -> List Error
expressionVisitor config node =
    case Node.value node of
        CaseExpression { cases } ->
            case findDefaultPattern cases of
                Nothing ->
                    []

                Just index ->
                    case config.position of
                        First ->
                            if index /= 0 then
                                [ error node "Expected default pattern to appear first in the list of patterns" ]

                            else
                                []

                        Last ->
                            if index /= List.length cases - 1 then
                                [ error node "Expected default pattern to appear last in the list of patterns" ]

                            else
                                []

        _ ->
            []
