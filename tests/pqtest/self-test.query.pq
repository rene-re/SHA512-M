let
    Result = SHA512_M[SelfTest](),
    TestNames = List.RemoveItems(Record.FieldNames(Result), {"AllPass"}),
    FailedNames = List.Select(
        TestNames,
        (name) =>
            let
                Test = Record.Field(Result, name)
            in
                not Test[Ok]
    ),
    Failures = List.Transform(
        FailedNames,
        (name) =>
            let
                Test = Record.Field(Result, name)
            in
                [
                    Name = name,
                    Expected = Test[Expected],
                    Actual = Test[Got]
                ]
    ),
    Passed =
        Value.Is(Result, type record)
            and Value.Is(Result[AllPass], type logical)
            and Result[AllPass]
            and List.IsEmpty(Failures)
in
    if Passed then
        true
    else
        let
            FirstFailure =
                if List.IsEmpty(Failures) then
                    [Name = "AllPass", Expected = true, Actual = Result[AllPass]]
                else
                    Failures{0}
        in
            error Error.Record(
                "AssertionFailed",
                "One or more built-in SHA512-M self-tests failed.",
                [
                    FailedCase = FirstFailure[Name],
                    Expected = FirstFailure[Expected],
                    Actual = FirstFailure[Actual],
                    Failures = Failures
                ]
            )
