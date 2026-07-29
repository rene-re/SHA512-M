# Changelog

Notable changes to SHA512-M will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The project intends to use [Semantic Versioning](https://semver.org/) once
tagged releases begin.

## [Unreleased]

### Added

- Automated PQTest validation for pull requests and pushes to `main`.
- A shared Windows/PowerShell 7 runner for local and CI execution.
- Known-answer coverage for SHA-512 boundaries, UTF-8 HMAC inputs, public API
  contracts, and invalid input types.
- Clear installation, API, compatibility, security, and limitation guidance.
- MIT license.
- Contribution and vulnerability-reporting guidance.
- Project changelog.

### Fixed

- README examples now call functions through the exported `SHA512_M` record.
- Source header now uses the canonical ASCII GitHub repository URL.
- PQTest failure artifacts no longer include the extracted SDK toolchain.
