# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning: [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- M0 scaffold: SPM core (`FrostBarCore`, `FrostBarModes`, `FrostBarProfiles`, `FrostBarSMC`).
- Xcode targets `FrostBar` (app) and `FrostBarHelper` (privileged tool).
- GPL-3.0-or-later licensing, SPDX headers, NOTICE for MIT dependencies.
- Architecture Decision Records 0001-0007.
- Vendored, patched SMCKit transport layer.
- Touch Bar UI (`NSTouchBar`), menu bar panel, control panel with live curve graph,
  settings window, onboarding and safety documentation.
- Privileged helper: XPC service, client code-signature check, write journal,
  10 s heartbeat watchdog and SMC write primitives.
- Deterministic Xcode project generator, notarization and Sparkle appcast scripts,
  GitHub Actions CI and release workflows.

### Safety
- Hardware guardrails are compiled-in constants (see ADR-0003).
- `forceZero` is rejected in v1 by validator, evaluator and helper policy.
