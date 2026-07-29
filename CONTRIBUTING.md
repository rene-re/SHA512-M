# Contributing to SHA512-M

Thanks for helping improve SHA512-M. Small, focused changes are easiest to
review.

## Before opening an issue

- Check that the behavior occurs with the latest `main` branch.
- Run `SHA512_M[SelfTest]()` in Power Query.
- Record the host and version, such as Excel, Power BI Desktop, Power BI
  Service, or Microsoft Fabric Dataflows.
- For incorrect digests, include the input encoding, expected value, actual
  value, and the independent implementation used as an oracle.

Do not include production secrets, signed credentials, private datasets, PBIX
files containing sensitive data, or confidential API requests.

## Proposing a change

1. Keep the public exports `SHA512`, `HMAC512`, and `SelfTest` stable unless the
   change explicitly introduces a documented compatibility plan.
2. Preserve the section order in `SHA512_M.pq`.
3. Keep arithmetic helpers pure and intermediates inside the intended 32-bit
   word range.
4. Add or update a known-answer check when changing cryptographic behavior.
5. On Windows with PowerShell 7, run the automated suite:

   ```powershell
   pwsh ./scripts/Invoke-PQTest.ps1
   ```

6. Run `SHA512_M[SelfTest]()` in at least one intended Power Query host and
   report the host and result in the pull request.
7. Update the README and changelog when behavior or the public API changes.

The automated runner uses Microsoft Power Query SDK Tools `2.145.5`, verifies
the pinned package checksum, and writes generated files only below
`.artifacts/pqtest/`. PQTest exercises its bundled Mashup Engine; host-specific
Excel, Power BI, and Fabric behavior still benefits from manual validation.
SDK upgrades are deliberate because newer MakePQX releases are affected by
[an upstream assembly-loading issue](https://github.com/microsoft/vscode-powerquery-sdk/issues/408).
Before changing the version or checksum, repeat the cold-cache build and all
negative-path checks.

## Code style

- Use clear Power Query M expressions and explicit parameter/return types.
- Keep lines readable, normally within 100–120 characters.
- Use section comments for major components and short inline comments for
  non-obvious word arithmetic.
- Preserve `{hi, lo}` as the 64-bit word representation unless a change
  deliberately migrates the full implementation.
- Avoid external runtimes or host-specific functions in the core library.

## Pull requests

Describe:

- the problem being solved;
- why the change is correct;
- the vectors or oracle used for validation;
- the result of `pwsh ./scripts/Invoke-PQTest.ps1`;
- the hosts used for manual execution; and
- any compatibility or performance effect.

Cryptographic changes may require additional review before they are merged.

## Security reports

Do not disclose suspected vulnerabilities in a public issue. Follow
[`SECURITY.md`](./SECURITY.md).
