# SHA‑512 & HMAC‑SHA‑512 for Power Query

This library is entirely written in M and works in all Power Query environments, including: Excel, Power BI Desktop/Service and Fabric Dataflows.

## Features

| Function | Type | Description |
| -------- | ---- | ----------- |
| `SHA512(binary)` | → `binary` | Raw 64‑byte hash |
| `HMAC512(secret as text, msg as text)` | → `text` | Lower‑case hex RFC 2104 digest |
| `SelfTest()` | → `record` | RFC 6234 / RFC 4231 vectors (returns `AllPass = true`) |

No external dependencies, no R/Python, no JavaScript.

## Specs
Adheres to [RFC 6234](https://datatracker.ietf.org/doc/html/rfc6234) and [RFC 4231](https://datatracker.ietf.org/doc/html/rfc4231).

## Quick start

```powerquery
let
    digest = SHA512(Text.ToBinary("abc", TextEncoding.Utf8)),
    hex    = Binary.ToText(digest, BinaryEncoding.Hex)
in
    hex
```

## Install
1. Open Power Query and create a blank query.
2. Paste the full contents of `SHA512_M.pq`.
3. Name the query `SHA512_M` (or any name you prefer).

## Usage
```powerquery
let
    digest = SHA512(Text.ToBinary("abc", TextEncoding.Utf8)),
    hex    = Binary.ToText(digest, BinaryEncoding.Hex),
    hmac   = HMAC512("key", "The quick brown fox"),
    tests  = SelfTest()
in
    [Hex = hex, Hmac = hmac, Tests = tests]
```

## Notes
- `SHA512` returns a `binary`; use `Binary.ToText(..., BinaryEncoding.Hex)` for hex.
- `HMAC512` returns a lowercase hex string.
- `SelfTest()` returns a record where `AllPass = true` when vectors pass.
