# Security Policy

SHA512-M is an early-stage cryptographic implementation written in Power Query
M. Security reports are welcome and will be handled separately from ordinary
bug reports.

## Supported versions

Until tagged releases are available, security fixes target the latest revision
of the `main` branch. Older revisions are not guaranteed to receive fixes.

## Reporting a vulnerability

Please do not open a public GitHub issue for a suspected vulnerability.

If GitHub offers the **Report a vulnerability** action for this repository, use
it to create a private security advisory. Otherwise, email
[`rene@o9.digital`](mailto:rene@o9.digital) with:

- a concise description of the issue;
- the affected revision and Power Query host;
- the input and preconditions needed to reproduce it;
- the expected security impact;
- a minimal proof of concept, when safe; and
- any suggested remediation.

Do not send real credentials, production secrets, private datasets, or
sensitive PBIX files.

## Scope

Security-relevant reports include:

- incorrect SHA-512 or HMAC-SHA-512 results for supported inputs;
- practical HMAC forgery or secret-recovery behavior;
- cross-host arithmetic differences that break cryptographic correctness;
- attacker-triggerable resource exhaustion in a realistic embedding; and
- unsafe handling or disclosure of caller-supplied secrets by this library.

General performance improvements, feature requests, documentation issues, and
incorrect integration-specific canonicalization normally belong in a public
issue unless they expose confidential information.

## Disclosure

Please allow reasonable time to investigate and prepare a fix before publishing
details. Confirmed issues may be documented through a GitHub security advisory
and release notes.
