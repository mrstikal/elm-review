module Lint exposing
    ( LintError, lintSource
    , errorModuleName, errorRuleName, errorMessage, errorDetails, errorRange, fixes
    )

{-| Module to configure your linting configuration and run it on a source file.


# Linting

@docs LintError, lintSource


# Errors

@docs errorModuleName, errorRuleName, errorMessage, errorDetails, errorRange, fixes

-}

import Elm.Parser as Parser
import Elm.Processing exposing (init, process)
import Elm.Syntax.File exposing (File)
import Elm.Syntax.Module exposing (Module(..))
import Elm.Syntax.Node as Node exposing (Node)
import Elm.Syntax.Range exposing (Range)
import Lint.Fix exposing (Fix)
import Lint.Rule as Rule exposing (Rule)
import Lint.Util as Util


{-| Represents an error in a file found by a rule.

Note: This should not be confused with `Error` from the `Lint.Rule` module.
`Lint.LintError` is created from `Lint.Rule.Error` but contains additional information
like the name of the rule that emitted it and the file name.

-}
type LintError
    = LintError
        { moduleName : Maybe String
        , ruleName : String
        , message : String
        , details : List String
        , range : Range
        , fixes : Maybe (List Fix)
        }



-- LINTING


{-| Lints a file and gives back the errors raised by the given rules.

    config : List Rule
    config =
        [ Lint.Rule.NoDebug.rule
        , Lint.Rule.NoUnusedVariables.rule
        ]

    errors : List LintError
    errors =
        lintSource config sourceCode

-}
lintSource : List Rule -> { path : String, source : String } -> List LintError
lintSource config { path, source } =
    case parseSource source of
        Ok file ->
            config
                |> List.concatMap (lintSourceWithRule path file source)
                |> List.sortWith compareErrorPositions

        Err _ ->
            [ LintError
                { moduleName = Nothing
                , ruleName = "ParsingError"
                , message = path ++ " is not a correct Elm file"
                , details =
                    [ "I could not understand the contents of this file, and this prevents me from analyzing it. It's highly likely that the contents of the file is not correct Elm code."
                    , "Hint: Try running `elm make`. The compiler should give you better hints on how to resolve the problem."
                    ]
                , range = { start = { row = 0, column = 0 }, end = { row = 0, column = 0 } }
                , fixes = Nothing
                }
            ]


lintSourceWithRule : String -> File -> String -> Rule -> List LintError
lintSourceWithRule path file source rule =
    Rule.analyzer rule file
        |> List.map (ruleErrorToLintError source (moduleName file) rule)


moduleName : File -> String
moduleName file =
    let
        moduleNameNode : Node (List String)
        moduleNameNode =
            case Node.value file.moduleDefinition of
                NormalModule data ->
                    data.moduleName

                PortModule data ->
                    data.moduleName

                EffectModule data ->
                    data.moduleName
    in
    Util.moduleName moduleNameNode


compareErrorPositions : LintError -> LintError -> Order
compareErrorPositions (LintError a) (LintError b) =
    compareRange a.range b.range


compareRange : Range -> Range -> Order
compareRange a b =
    if a.start.row < b.start.row then
        LT

    else if a.start.row > b.start.row then
        GT

    else
    -- Start row is the same from here on
    if
        a.start.column < b.start.column
    then
        LT

    else if a.start.column > b.start.column then
        GT

    else
    -- Start row and column are the same from here on
    if
        a.end.row < b.end.row
    then
        LT

    else if a.end.row > b.end.row then
        GT

    else
    -- Start row and column, and end row are the same from here on
    if
        a.end.column < b.end.column
    then
        LT

    else if a.end.column > b.end.column then
        GT

    else
        EQ


ruleErrorToLintError : String -> String -> Rule -> Rule.Error -> LintError
ruleErrorToLintError source moduleName_ rule error =
    -- TODO Remove source here?
    LintError
        { moduleName = Just moduleName_
        , ruleName = Rule.name rule
        , message = Rule.errorMessage error
        , details = Rule.errorDetails error
        , range = Rule.errorRange error
        , fixes = Rule.errorFixes error
        }


{-| Parse source code into a AST
-}
parseSource : String -> Result String File
parseSource source =
    source
        |> Parser.parse
        |> Result.mapError (\error -> "Parsing error")
        |> Result.map (process init)



-- ERRORS


{-| Get the name of the module for which the error occurred.
-}
errorModuleName : LintError -> Maybe String
errorModuleName (LintError error) =
    error.moduleName


{-| Get the name of the rule of an error.
-}
errorRuleName : LintError -> String
errorRuleName (LintError error) =
    error.ruleName


{-| Get the message of an error.
-}
errorMessage : LintError -> String
errorMessage (LintError error) =
    error.message


{-| Get the details of an error.
-}
errorDetails : LintError -> List String
errorDetails (LintError error) =
    error.details


{-| Get the range of an error.
-}
errorRange : LintError -> Range
errorRange (LintError error) =
    error.range


{-| Get the fixes for an error.
-}
fixes : LintError -> Maybe (List Fix)
fixes (LintError error) =
    error.fixes
