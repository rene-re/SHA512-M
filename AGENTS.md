# AGENTS.md – SHA512-M Development Guide

## Project Overview
SHA512-M is a pure M (Power Query) library implementing SHA-512 and HMAC-SHA-512 according to RFC 6234 and RFC 4231. No external dependencies—works in Excel, Power BI, and Fabric Dataflows.

## Build/Test Commands
- **Run self-tests**: Call `SelfTest()` in Power Query. Returns a record with `AllPass = true` if all RFC vectors pass.
- **Validate specific hash**: Test `SHA512(binary)` against expected 64-byte outputs; test `HMAC512(secret, msg)` against hex strings.

## Architecture
**Single file structure** (SHA512_M.pq):
1. **32-bit helpers** (lines 20–41): UInt32 wrapper, Add32, Xor/And/Or/Not, Lsr32, Ror32
2. **64-bit helpers** (lines 46–108): Add64, Ror64, ShR64, Xor64, sigma/Sigma functions
3. **SHA-512 constants** (lines 113–134): 80 × 64-bit K array
4. **SHA-512 core** (lines 139–226): Padding, initial hash H0, 80-round compressor
5. **HMAC-SHA-512** (lines 234–249): RFC 2104 implementation
6. **Helper for self-tests** (lines 255–256): BytesToText
7. **Self-tests** (lines 261–317): RFC 6234/4231 test vectors

Exports: `HMAC512(secret, msg)`, `SHA512(bin)`, `SelfTest()` (lines 320–324)

## Code Style
- **Format**: Pure M; all functions are pure expressions (no side effects)
- **Naming**: Uppercase for functions (`SHA512`, `HMAC512`), helpers use CamelCase
- **64-bit representation**: As 2-element lists `{hi, lo}` (32-bit each)
- **Comments**: Delimit sections with `//--` lines; inline notes use `/* */`
- **No formatting tool**: Manual formatting; maintain readable 100–120 char lines
- **Binary/text**: Use `Text.ToBinary()` with `TextEncoding.Utf8`, output hex via `ToHex()`
- **Edits**: Keep section order and exports stable; update line ranges if they change
