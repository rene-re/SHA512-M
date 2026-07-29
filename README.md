# SHA-512 and HMAC-SHA-512 for Power Query M

Generate SHA-512 hashes and HMAC-SHA-512 signatures directly in Power Query
M—without Python, JavaScript, external DLLs, or a custom connector.

SHA512-M is designed for Excel, Power BI, and Microsoft Fabric scenarios where
a regular Power Query needs to hash data or sign an API request using
HMAC-SHA-512.

## Why this project?

Regular Power Query queries do not have a documented general-purpose HMAC
helper in the public
[M binary-function reference](https://learn.microsoft.com/en-us/powerquery-m/binary-functions).
That becomes a practical problem when an API expects a request signature but
the query must remain portable and self-contained.

SHA512-M provides:

- a pure M implementation with no external runtime dependencies;
- SHA-512 for arbitrary Power Query `binary` values;
- HMAC-SHA-512 for UTF-8 text secrets and messages;
- built-in checks against RFC 6234 and RFC 4231 values; and
- one source file that can be copied between Power Query projects.

## Quick start

### 1. Install the library query

1. In Power Query, create a blank query.
2. Open **Advanced Editor**.
3. Paste the complete contents of [`SHA512_M.pq`](./SHA512_M.pq).
4. Name the query `SHA512_M`.
5. Optionally disable load for the library query.

The query evaluates to a record containing the three exported functions.

### 2. Call it from another query

```powerquery
let
    Crypto = SHA512_M,

    Digest = Crypto[SHA512](
        Text.ToBinary("abc", TextEncoding.Utf8)
    ),
    DigestHex = Text.Lower(
        Binary.ToText(Digest, BinaryEncoding.Hex)
    ),

    HmacHex = Crypto[HMAC512](
        "secret",
        "message"
    ),

    Checks = Crypto[SelfTest]()
in
    [
        SHA512 = DigestHex,
        HMACSHA512 = HmacHex,
        SelfTestsPass = Checks[AllPass]
    ]
```

The SHA-512 value for `abc` starts with `ddaf35a193617aba`. `HMAC512` returns a
lowercase hexadecimal string.

## API

| Export | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `SHA512` | `(bin as binary) as binary` | 64-byte binary digest | Convert to hexadecimal with `Binary.ToText`. |
| `HMAC512` | `(secret as text, msg as text) as text` | 128-character lowercase hex digest | Both inputs are encoded as UTF-8. |
| `SelfTest` | `() as record` | Test details and `AllPass` | Runs the built-in known-answer checks. |

Because the library query returns a record, call exports as
`SHA512_M[SHA512](...)`, `SHA512_M[HMAC512](...)`, and
`SHA512_M[SelfTest]()`.

## Common uses

- Sign requests for APIs that use HMAC-SHA-512 authentication.
- Produce stable SHA-512 identifiers from text or binary data.
- Compare a non-secret file or payload digest with a value from another system.
- Keep a query portable when Python, R, JavaScript, and native extensions are
  unavailable.

For API authentication, build the exact canonical message required by the API
before passing it to `HMAC512`. Whitespace, casing, timestamps, separators, and
text encoding all affect the signature.

## Correctness

The implementation follows:

- [RFC 6234: US Secure Hash Algorithms](https://www.rfc-editor.org/info/rfc6234/)
- [RFC 4231: HMAC-SHA test vectors](https://www.rfc-editor.org/info/rfc4231/)

`SelfTest()` currently checks:

- SHA-512 of an empty message;
- SHA-512 of `abc`;
- RFC 4231 HMAC-SHA-512 test cases 1 and 2; and
- an additional HMAC-SHA-512 value for key `1` and message `1`.

Run `SHA512_M[SelfTest]()` after copying the source into a new host to confirm
that the built-in checks pass.

## Compatibility

The library is written entirely in standard Power Query M for use in:

- Excel Power Query;
- Power BI Desktop;
- Power BI Service; and
- Microsoft Fabric Dataflows.

If you use SHA512-M in another Power Query host, please report the host version
and the result of `SHA512_M[SelfTest]()`.

## Limitations and security notes

- `HMAC512` accepts text, not arbitrary binary keys or messages. Text is
  encoded as UTF-8.
- The implementation is correctness-first pure M and is best suited to short
  payloads such as API-signing strings. Large values may be slow and consume
  substantial memory.
- Input is processed as a complete Power Query binary; this is not a streaming
  hash API.
- The implementation encodes message lengths below `2^64` bits. This is far
  beyond practical Power Query workloads but narrower than SHA-512's formal
  maximum.
- The library generates a MAC but does not provide a constant-time MAC
  verification function.
- Do not hardcode production secrets in a workbook, PBIX file, or shared query.
  Use an appropriate credential or parameter mechanism for your environment.

## Contributing

Bug reports, host-compatibility results, performance measurements, and focused
pull requests are welcome. See [`CONTRIBUTING.md`](./CONTRIBUTING.md) before
submitting a change.

For potential security issues, follow [`SECURITY.md`](./SECURITY.md) instead of
opening a public issue.

## License

SHA512-M is available under the [MIT License](./LICENSE).
