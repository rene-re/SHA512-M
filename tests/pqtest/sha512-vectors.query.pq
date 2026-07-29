let
    // The empty, abc, and 112-byte values come from FIPS 180-4 examples.
    // The other fixed values were independently cross-checked with Python
    // hashlib and System.Security.Cryptography.SHA512.
    ToHex = (value as binary) as text =>
        Text.Lower(Binary.ToText(value, BinaryEncoding.Hex)),
    Sequence = (length as number) as binary =>
        Binary.FromList(List.Transform({0..length - 1}, each Number.Mod(_, 256))),
    Cases = {
        [
            Name = "empty",
            Input = #binary({}),
            Expected =
                "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc" &
                "83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f" &
                "63b931bd47417a81a538327af927da3e"
        ],
        [
            Name = "abc",
            Input = Text.ToBinary("abc", TextEncoding.Utf8),
            Expected =
                "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea2" &
                "0a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd" &
                "454d4423643ce80e2a9ac94fa54ca49f"
        ],
        [
            Name = "fips_112_byte",
            Input = Text.ToBinary(
                "abcdefghbcdefghicdefghijdefghijkefghijklfghijklm" &
                "ghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrs" &
                "mnopqrstnopqrstu",
                TextEncoding.Utf8
            ),
            Expected =
                "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa1" &
                "7299aeadb6889018501d289e4900f7e4331b99dec4b5433a" &
                "c7d329eeb6dd26545e96e55b874be909"
        ],
        [
            Name = "special_binary",
            Input = #binary({0x00, 0x80, 0xff, 0x01, 0x7f}),
            Expected =
                "5c2189158da9caa8cfbc4703e04719ad31997114be45e5f7" &
                "961407adb7585e11f9c52138bf9a291fa9191b5d46b01012" &
                "66d3c7cf4b22e8c8d30ce6d76499a821"
        ],
        [
            Name = "sequence_111",
            Input = Sequence(111),
            Expected =
                "a1a111449b198d9b1f538bad7f3fc1022b3a5b1a5e90a0bc" &
                "860de8512746cbc31599e6c834de3a3235327af0b51ff57b" &
                "f7acf1974a73014d9c3953812edc7c8d"
        ],
        [
            Name = "sequence_112",
            Input = Sequence(112),
            Expected =
                "c5fbd731d19d2ae1180f001be72c2c1aaba1d7b094b37488" &
                "80e24593b8e117a750e11c1bd867cc2f96dace8c8b74abd2" &
                "d5c4f236be444e77d30d1916174070b9"
        ],
        [
            Name = "sequence_127",
            Input = Sequence(127),
            Expected =
                "eab89674feaa34e27aebeeff3c0a4d70070bb872d5e9f186" &
                "cf1dbbdee517b6e35724d629ff025a5b07185e911ada7e3c" &
                "8acf830aa0e4f71777bd2d44f504f7f0"
        ],
        [
            Name = "sequence_128",
            Input = Sequence(128),
            Expected =
                "1dffd5e3adb71d45d2245939665521ae001a317a03720a45" &
                "732ba1900ca3b8351fc5c9b4ca513eba6f80bc7b1d1fdad4" &
                "abd13491cb824d61b08d8c0e1561b3f7"
        ],
        [
            Name = "sequence_129",
            Input = Sequence(129),
            Expected =
                "1d9da57fbbdab09afb3506ab2d223d06109d65c1c8ad197f" &
                "50138f714bc4c3f2fe5787922639c680acad1c651f955990" &
                "425954ce2cba0c5cc83f2667d878eb0f"
        ]
    },
    Results = List.Transform(
        Cases,
        (Test) =>
            let
                Digest = SHA512_M[SHA512](Test[Input]),
                Actual = ToHex(Digest)
            in
                [
                    Name = Test[Name],
                    Expected = Test[Expected],
                    Actual = Actual,
                    IsBinary = Value.Is(Digest, type binary),
                    Length = Binary.Length(Digest),
                    Ok =
                        Value.Is(Digest, type binary)
                            and Binary.Length(Digest) = 64
                            and Actual = Test[Expected]
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
                "One or more SHA-512 known-answer tests failed.",
                [
                    FailedCase = FirstFailure[Name],
                    Expected = FirstFailure[Expected],
                    Actual = FirstFailure[Actual],
                    Failures = Failures
                ]
            )
