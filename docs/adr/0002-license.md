# ADR-0002: GPL-3.0-or-later

Status: accepted (2026-10-28)

## Decision

FrostBar is licensed under GPL-3.0-or-later. Every `.swift` file starts with:

```swift
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors
```

`Vendored/` keeps the upstream MIT headers and is excluded from the SPDX check.
`NOTICE` lists SMCKit (MIT) and Sparkle (MIT) with links and the modifications
made to vendored code. CI runs `scripts/check_spdx.sh`.

## Consequences

- Mac App Store distribution is impossible (already excluded by the sandbox and
  AppleSMC requirements).
- MIT dependencies are GPL-compatible; their notices must ship with binaries.
- Forks that redistribute binaries must publish their source.
