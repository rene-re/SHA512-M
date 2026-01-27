# CLAUDE.md — AI Assistant Guide for SHA512-M

## Project Summary

SHA512-M is a **pure M (Power Query)** library implementing SHA-512 and HMAC-SHA-512 cryptographic hash functions. It has zero external dependencies and runs natively in all Power Query environments: Excel, Power BI Desktop, Power BI Service, and Fabric Dataflows.

- **Author:** René Reineke (rene@o9.digital)
- **License:** MIT
- **Repository:** https://github.com/rene-re/SHA512-M
- **Standards:** RFC 6234 (SHA-512), RFC 4231 (HMAC-SHA-512), RFC 2104 (HMAC)

## Repository Structure

```
SHA512-M/
├── SHA512_M.pq     # Complete implementation (single source file, ~323 lines)
├── README.md       # User-facing documentation
├── AGENTS.md       # Development guide with architecture details
├── CLAUDE.md       # This file — AI assistant guide
└── .gitignore      # Ignores Power BI autosave, VS Code, OS files
```

This is a single-file project. All logic lives in `SHA512_M.pq`.

## Language and Environment

- **Language:** M (Power Query) — a functional, expression-based, lazily-evaluated language
- **Runtime:** Microsoft Power Query engine (no standalone compiler/interpreter)
- **No build system:** M is interpreted; there is no compilation step, no `npm`, no `Makefile`
- **No formatting tools:** Code is manually formatted; target 100–120 character lines

## Architecture of SHA512_M.pq

The file is structured as a single `let ... in` expression with clearly delimited sections:

| Section | Lines   | Contents |
|---------|---------|----------|
| 1 — 32-bit helpers | 20–41 | `UInt32`, `Add32`, `Xor32`, `And32`, `Or32`, `Not32`, `Lsr32`, `Ror32` |
| 2 — 64-bit helpers | 46–108 | `Add64`, `Ror64`, `ShR64`, `Xor64`, sigma/Sigma functions |
| 3 — SHA-512 constants | 113–134 | `K` array (80 × 64-bit round constants) |
| 4 — SHA-512 core | 139–228 | `SHA512` function (padding, initial hash, 80-round compressor), `ToHex` |
| 5 — HMAC-SHA-512 | 234–249 | `HMAC512` function (RFC 2104 key derivation and double-hash) |
| 6 — Helper for self-tests | 255–256 | `BytesToText` |
| 7 — Self-tests | 261–317 | `SelfTest` function with RFC test vectors |
| Exports | 320–324 | Record returning `HMAC512`, `SHA512`, `SelfTest` |

### Key Design Decisions

- **64-bit integers as 2-element lists:** M natively handles only 32-bit integers. All 64-bit values are represented as `{hi32, lo32}` pairs with manual carry propagation.
- **Binary string rotation:** `Ror64` converts to a 64-character binary string, performs text rotation, and converts back — a workaround for M's limited bitwise operations.
- **Pure functional style:** Every function is a pure expression with no side effects or mutable state. Iteration uses `List.Accumulate`.

## Exported API

| Function | Signature | Returns |
|----------|-----------|---------|
| `SHA512` | `(bin as binary) → binary` | Raw 64-byte hash |
| `HMAC512` | `(secret as text, msg as text) → text` | Lowercase hex digest |
| `SelfTest` | `() → record` | Test results with `AllPass` boolean field |

## Testing

There is no external test framework. Testing is built into the library via `SelfTest()`.

### How to validate

Call `SelfTest()` in a Power Query environment. It runs 5 test cases:

1. **SHA512_Empty** — SHA-512 of empty input vs RFC 6234
2. **SHA512_abc** — SHA-512 of `"abc"` vs RFC 6234
3. **HMAC_RFC4231_1** — HMAC-SHA-512 test vector 1 from RFC 4231
4. **HMAC_RFC4231_2** — HMAC-SHA-512 test vector 2 from RFC 4231
5. **HMAC11** — HMAC-SHA-512 with key=`"1"`, msg=`"1"`

The returned record includes an `AllPass` boolean field. All tests must return `AllPass = true`.

### There is no CLI test command

Since M runs inside Power Query, there is no `make test` or `npm test` equivalent. Verification requires pasting the code into a Power Query editor and invoking `SelfTest()`.

## Code Conventions

### Naming
- **Public functions:** UPPERCASE — `SHA512`, `HMAC512`, `SelfTest`
- **Internal helpers:** CamelCase — `UInt32`, `Add64`, `Ror64`, `ToHex`, `BytesToText`
- **Constants:** UPPERCASE — `K` (round constants), `H0` (initial hash vector)

### Formatting
- Section boundaries marked with `//--` comment lines
- Inline comments use `/* */` block style
- Target line length: 100–120 characters
- No trailing whitespace; UTF-8 encoding throughout

### Patterns
- All iteration via `List.Accumulate` (no loops)
- Binary ↔ text conversion via `Text.ToBinary()` / `Binary.ToText()` with explicit encoding
- Hex output via the `ToHex` helper (`Text.Lower(Binary.ToText(bin, BinaryEncoding.Hex))`)
- Type annotations on function parameters (`as number`, `as list`, `as binary`, `as text`)

## Rules for Modifications

1. **Preserve section order.** The numbered sections (1–7 + exports) must stay in their current order. Power Query evaluates the `let` block sequentially; reordering may break forward references.

2. **Keep exports stable.** The final `in [HMAC512 = ..., SHA512 = ..., SelfTest = ...]` record is the public API. Do not rename or remove exports without clear intent.

3. **Update AGENTS.md line ranges.** If edits shift line numbers, update the line-range references in `AGENTS.md` to match.

4. **Maintain RFC compliance.** All changes to hashing or HMAC logic must continue to pass `SelfTest()` against the published RFC vectors. Do not alter test expected values.

5. **No external dependencies.** The library must remain 100% pure M with no JavaScript bridges, R/Python scripts, or external DLLs.

6. **No side effects.** All functions must remain pure expressions. Do not introduce mutable state, file I/O, or network calls.

7. **Test after changes.** After any code modification, verify by confirming `SelfTest()[AllPass] = true` in a Power Query environment.

## Common Tasks

### Adding a new hash variant
1. Add helper functions in the appropriate section (before the main function)
2. Implement the core function following the existing pattern (padding → schedule → rounds → finalize)
3. Add test vectors from the relevant RFC to `SelfTest()`
4. Export the new function in the final `in` record

### Adding a new test vector
1. Add the expected value as a text constant in section 7
2. Compute the result using the relevant function
3. Add a new field to the `tests` record with `[Expected = ..., Got = ..., Ok = ...]`
4. The `allOk` check automatically picks up new fields via `Record.FieldValues`

### Fixing a bug in the hash logic
1. Identify the failing test vector (run `SelfTest()`)
2. Trace through the relevant section (32-bit helpers → 64-bit helpers → core)
3. Fix the issue while preserving the function signature
4. Confirm all tests still pass

## Files Not to Create

- No `package.json`, `Makefile`, `CMakeLists.txt`, or build files — this is not a compiled project
- No `.github/workflows/` — there is no CI/CD; testing is manual in Power Query
- No `LICENSE` file exists yet (MIT is referenced in the source header)
- No separate test files — tests are embedded in the source

## Git Workflow

- Main branch: `main`
- Commit messages follow conventional style: `type: description` (e.g., `docs:`, `fix:`, `feat:`)
- Keep commits focused — separate documentation changes from code changes
