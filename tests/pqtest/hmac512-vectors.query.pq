let
    // RFC cases 1 and 2 are directly representable by the public text API.
    // Other fixed values were independently cross-checked with Python hmac
    // and System.Security.Cryptography.HMACSHA512 using UTF-8 inputs.
    ControlKey = Text.FromBinary(
        Binary.FromList(List.Repeat({0x0b}, 20)),
        TextEncoding.Utf8
    ),
    Cases = {
        [
            Name = "rfc4231_1",
            Secret = ControlKey,
            Message = "Hi There",
            Expected =
                "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec278" &
                "7ad0b30545e17cdedaa833b7d6b8a702038b274eaea3f4e4" &
                "be9d914eeb61f1702e696c203a126854"
        ],
        [
            Name = "rfc4231_2",
            Secret = "Jefe",
            Message = "what do ya want for nothing?",
            Expected =
                "164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd6" &
                "10270cd7ea2505549758bf75c05a994a6d034f65f8f0e6fd" &
                "caeab1a34d4a6b4b636e070a38bce737"
        ],
        [
            Name = "empty_secret_and_message",
            Secret = "",
            Message = "",
            Expected =
                "b936cee86c9f87aa5d3c6f2e84cb5a4239a5fe50480a6ec6" &
                "6b70ab5b1f4ac6730c6c515421b327ec1d69402e53dfb49a" &
                "d7381eb067b338fd7b0cb22247225d47"
        ],
        [
            Name = "empty_secret",
            Secret = "",
            Message = "message",
            Expected =
                "08fce52f6395d59c2a3fb8abb281d74ad6f112b9a9c787bc" &
                "ea290d94dadbc82b2ca3e5e12bf2277c7fedbb0154d5493e" &
                "41bb7459f63c8e39554ea3651b812492"
        ],
        [
            Name = "empty_message",
            Secret = "secret",
            Message = "",
            Expected =
                "b0e9650c5faf9cd8ae02276671545424104589b3656731ec" &
                "193b25d01b07561c27637c2d4d68389d6cf5007a8632c26e" &
                "c89ba80a01c77a6cdd389ec28db43901"
        ],
        [
            Name = "unicode_utf8",
            Secret = "Grüße🔐",
            Message = "秘密のメッセージ🌍",
            Expected =
                "3f369ae6c494fd5241dd4cfd087a21b9973a2ff7a269cad1" &
                "3a84e7c0b4f5b4a82f0d358e0edae376ad34a064c19302b4" &
                "efe080865e44892b465daec24a2ae341"
        ],
        [
            Name = "ascii_key_127",
            Secret = Text.Repeat("k", 127),
            Message = "block-boundary-message",
            Expected =
                "b9d6dc81222d3ab76e66ee1483e049364004f8edcbe9df25" &
                "93a5ffaca7238b703504c8d8534d0109f60625006380183c" &
                "f9712238dc8b6a9421587c2423f2eaba"
        ],
        [
            Name = "ascii_key_128",
            Secret = Text.Repeat("k", 128),
            Message = "block-boundary-message",
            Expected =
                "2338d119c2e1fde78d5923d2bde47530058f5886b0b0bd3f" &
                "4d39458e947f499959a3b395b44f8173332b20b743eafce3" &
                "4c0e22ab7c95f94f792cf9d7b0f1fe44"
        ],
        [
            Name = "ascii_key_129",
            Secret = Text.Repeat("k", 129),
            Message = "block-boundary-message",
            Expected =
                "5e6da931ceacc13c3b12529284a08d7242e3f79ff85babe5" &
                "9bafa63c6e20553c8a9c009673a598c8a413066e17cc2c88" &
                "7e716f0d7e227104319daba229801106"
        ],
        [
            Name = "multi_block_message",
            Secret = "long-message-key",
            Message = Text.Repeat("0123456789abcdef", 20),
            Expected =
                "5697af2f935992ff7073d1b3dd68fa08525b6a2fbf1d0574" &
                "2ac01b7364e9c559991af9cfb2d7c229158d24456487aa7e" &
                "e8ed4766eded5de88df41452702a3274"
        ]
    },
    HexCharacters = Text.ToList("0123456789abcdef"),
    Results = List.Transform(
        Cases,
        (Test) =>
            let
                Actual = SHA512_M[HMAC512](Test[Secret], Test[Message]),
                FormatOk =
                    Value.Is(Actual, type text)
                        and Text.Length(Actual) = 128
                        and Text.Lower(Actual) = Actual
                        and Text.Length(Text.Remove(Actual, HexCharacters)) = 0
            in
                [
                    Name = Test[Name],
                    Expected = Test[Expected],
                    Actual = Actual,
                    FormatOk = FormatOk,
                    Ok = FormatOk and Actual = Test[Expected]
                ]
    ),
    Failures = List.Select(Results, each not _[Ok])
in
    if List.IsEmpty(Failures) then
        true
    else
        let
            FirstFailure = Failures{0}
        in
            error Error.Record(
                "AssertionFailed",
                "One or more HMAC-SHA-512 known-answer tests failed.",
                [
                    FailedCase = FirstFailure[Name],
                    Expected = FirstFailure[Expected],
                    Actual = FirstFailure[Actual],
                    Failures = Failures
                ]
            )
