module TestUtil exposing (LintResult, errorWithoutRange, expectErrors, expectErrorsWithoutRange, location, ruleTester)

import Elm.Syntax.Range exposing (Range)
import Expect
import Lint exposing (Severity(..), lintSource)
import Lint.Error as Error exposing (Error)
import Lint.Rule exposing (Rule)


{-| Result of a lint rule being applied on a string containing Elm code.
-}
type alias LintResult =
    Result (List String) (List Error)


ruleTester : Rule -> String -> Result (List String) (List Error)
ruleTester rule str =
    lintSource [ ( Critical, rule ) ] str
        |> Result.map (List.map (\( severity, { message, range } ) -> Error.create message range))


expectErrors : List Error -> LintResult -> Expect.Expectation
expectErrors expectedErrors result =
    case result of
        Err errors ->
            Expect.fail <| String.join "\n" errors

        Ok errors ->
            Expect.equal expectedErrors errors


expectErrorsWithoutRange : List Error -> LintResult -> Expect.Expectation
expectErrorsWithoutRange expectedErrors result =
    case result of
        Err errors ->
            Expect.fail <| String.join "\n" errors

        Ok errors ->
            Expect.equal
                (errorMessages expectedErrors)
                (errorMessages errors)


errorMessages : List Error -> List String
errorMessages errors =
    List.map Error.message errors


errorWithoutRange : String -> Error
errorWithoutRange message =
    Error.create message (location ( 0, 0 ) ( 0, 0 ))


location : ( Int, Int ) -> ( Int, Int ) -> Range
location ( rowStart, columnStart ) ( rowEnd, columnEnd ) =
    { start = { row = rowStart, column = columnStart }
    , end = { row = rowEnd, column = columnEnd }
    }
