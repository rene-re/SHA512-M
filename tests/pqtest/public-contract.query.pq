let
    ExportNames = Text.Combine(List.Sort(Record.FieldNames(SHA512_M)), ","),
    ExpectedExportNames = "HMAC512,SHA512,SelfTest",
    ShaResult = SHA512_M[SHA512](Text.ToBinary("abc", TextEncoding.Utf8)),
    HmacResult = SHA512_M[HMAC512]("secret", "message"),
    SelfTestResult = SHA512_M[SelfTest](),
    SelfTestNames = List.RemoveItems(Record.FieldNames(SelfTestResult), {"AllPass"}),
    SelfTestDetailsOk = List.AllTrue(
        List.Transform(
            SelfTestNames,
            (name) =>
                let
                    Detail = Record.Field(SelfTestResult, name)
                in
                    Value.Is(Detail, type record)
                        and Record.HasFields(Detail, {"Expected", "Got", "Ok"})
                        and Value.Is(Detail[Ok], type logical)
        )
    ),
    WrongShaType = try SHA512_M[SHA512]("abc"),
    NullSha = try SHA512_M[SHA512](null),
    WrongHmacSecretType = try SHA512_M[HMAC512](#binary({0x01}), "message"),
    NullHmacMessage = try SHA512_M[HMAC512]("secret", null),
    Checks = {
        [
            Name = "documented exports",
            Expected = ExpectedExportNames,
            Actual = ExportNames,
            Ok = ExportNames = ExpectedExportNames
        ],
        [
            Name = "SHA512 is a function",
            Expected = true,
            Actual = Value.Is(SHA512_M[SHA512], type function),
            Ok = Value.Is(SHA512_M[SHA512], type function)
        ],
        [
            Name = "HMAC512 is a function",
            Expected = true,
            Actual = Value.Is(SHA512_M[HMAC512], type function),
            Ok = Value.Is(SHA512_M[HMAC512], type function)
        ],
        [
            Name = "SelfTest is a function",
            Expected = true,
            Actual = Value.Is(SHA512_M[SelfTest], type function),
            Ok = Value.Is(SHA512_M[SelfTest], type function)
        ],
        [
            Name = "SHA512 return contract",
            Expected = "64-byte binary",
            Actual =
                if Value.Is(ShaResult, type binary) then
                    Text.From(Binary.Length(ShaResult)) & "-byte binary"
                else
                    "non-binary",
            Ok = Value.Is(ShaResult, type binary) and Binary.Length(ShaResult) = 64
        ],
        [
            Name = "HMAC512 return contract",
            Expected = "128-character text",
            Actual =
                if Value.Is(HmacResult, type text) then
                    Text.From(Text.Length(HmacResult)) & "-character text"
                else
                    "non-text",
            Ok = Value.Is(HmacResult, type text) and Text.Length(HmacResult) = 128
        ],
        [
            Name = "SelfTest return contract",
            Expected = true,
            Actual =
                Value.Is(SelfTestResult, type record)
                    and Record.HasFields(SelfTestResult, "AllPass")
                    and Value.Is(SelfTestResult[AllPass], type logical)
                    and SelfTestDetailsOk,
            Ok =
                Value.Is(SelfTestResult, type record)
                    and Record.HasFields(SelfTestResult, "AllPass")
                    and Value.Is(SelfTestResult[AllPass], type logical)
                    and SelfTestDetailsOk
        ],
        [
            Name = "SHA512 rejects text",
            Expected = true,
            Actual = WrongShaType[HasError],
            Ok = WrongShaType[HasError]
        ],
        [
            Name = "SHA512 rejects null",
            Expected = true,
            Actual = NullSha[HasError],
            Ok = NullSha[HasError]
        ],
        [
            Name = "HMAC512 rejects binary secret",
            Expected = true,
            Actual = WrongHmacSecretType[HasError],
            Ok = WrongHmacSecretType[HasError]
        ],
        [
            Name = "HMAC512 rejects null message",
            Expected = true,
            Actual = NullHmacMessage[HasError],
            Ok = NullHmacMessage[HasError]
        ]
    },
    Failures = List.Select(Checks, each not _[Ok])
in
    if List.IsEmpty(Failures) then
        true
    else
        let
            FirstFailure = Failures{0}
        in
            error Error.Record(
                "AssertionFailed",
                "The public SHA512-M contract changed.",
                [
                    FailedCase = FirstFailure[Name],
                    Expected = Text.From(FirstFailure[Expected]),
                    Actual = Text.From(FirstFailure[Actual]),
                    Failures = Failures
                ]
            )
