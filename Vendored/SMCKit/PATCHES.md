# Vendored SMCKit — changes from upstream

Upstream: https://github.com/beltex/SMCKit (MIT, Copyright (c) 2014-2017 beltex)
Base: `master` as of 2026-10-28.

FrostBar vendors the transport layer only. The original MIT license text is
kept in this directory and the copyright header is preserved in `SMC.swift`.

## Why vendor instead of depending on the package

- Upstream ships only `SMCKit.xcodeproj`; there is no `Package.swift`, which
  breaks the "`swift test` without Xcode" requirement.
- Upstream targets Swift 4 and does not compile with a modern toolchain.
- Upstream has no API for writing `F0Tg` (target RPM) or `F0Md` (auto/manual)
  and rejects `0` for the minimum speed, which blocks the future `forceZero`
  feature.
- `sp78` decoding in upstream ignores the fractional byte and the sign.

## Changes

1. Trimmed to the transport primitives: `open`, `close`, `keyInfo`,
   `readBytes`, `writeBytes`, `SMCParamStruct`, `SMCKeyInfo`, `SMCBytes`.
   Removed battery, optical drive, fan-name and "all keys" helpers; those
   belong to FrostBarSMC and are added only when needed.
2. `SMCParamStruct` rebuilt to match the reference C layout
   (`SMCKeyData_t` from the devnull AppleSMC tool, 80 bytes):
   - `keyInfo.dataSize` is `UInt32`, not `IOByteCount`;
   - removed the extra `padding: UInt16` field;
   - `SMCBytes` is an inline struct with 32 `UInt8` fields instead of a 32-tuple;
   - `SMCKit.open()` asserts `MemoryLayout<SMCParamStruct>.stride == 80`.
3. Swift 5 compatibility: no `String.characters`, no free `==` overload that
   collides with `Equatable`, `kIOMainPortDefault` instead of the deprecated
   `kIOMasterPortDefault`.
4. Errors are a top-level `SMCError` enum with `Equatable` conformance, so
   `FrostBarSMC` can map `kIOReturnNotPrivileged` to a domain error.
5. `writeBytes` validates the payload size against the key's reported data size
   instead of trusting the caller.

## Upstream sync policy

Re-check upstream before touching this file. Any deviation must be appended to
this document in the same commit.
