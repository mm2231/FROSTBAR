# ADR-0005: Vendored SMCKit

Status: accepted (2026-10-28)

## Context

`beltex/SMCKit` is MIT licensed and is the reference Swift implementation of the
AppleSMC user client, but upstream:

- ships only an `.xcodeproj`, no `Package.swift`, so it cannot be consumed by
  `swift test`;
- is written for Swift 4 (`String.characters`, a free `==` that collides with
  `Equatable`);
- has no way to write `F0Tg` (target RPM) or `F0Md` (auto/manual), only
  `F0Mn`;
- decodes `sp78` incorrectly (ignores the fractional byte and the sign).

## Decision

Vendor the transport layer into `Vendored/SMCKit` as a local SwiftPM target:

- preserve the MIT header, license and attribution;
- keep only the pieces FrostBar needs (open/close, key info, read/write bytes);
- correct `SMCParamStruct` to match the reference 80-byte C layout
  (`SMCKeyData_t` from the devnull SMC tool), with a runtime size guard;
- move fan/temperature semantics (`F0Tg`, `F0Md`, FPE2/SP78) into
  `FrostBarSMC`, where they are unit tested without hardware.

All deviations are listed in `Vendored/SMCKit/PATCHES.md`.

## Consequences

- No network dependency and no build-time code generation.
- Upstream improvements must be merged manually; the patch list keeps this
  cheap.
- `FrostBarSMC` is the only place that touches IOKit, and it contains no XPC
  code.
