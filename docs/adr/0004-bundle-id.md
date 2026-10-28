# ADR-0004: Bundle identifiers and Team.xcconfig

Status: accepted (2026-10-28)

## Decision

- App: `com.mm2231.frostbar`
- Helper: `com.mm2231.frostbar.helper`
- Team id, both bundle identifiers, versions and the Sparkle feed live in
  `Team.xcconfig`. Fork owners edit one file.
- `scripts/set_bundle_id.sh` rewrites `Team.xcconfig`, the launchd plist label
  and its file name together, because launchd does not expand build settings.

## Consequences

- The helper label must equal the helper bundle identifier, otherwise the
  code-signing requirement and the XPC mach service name diverge.
- Hardcoding an identifier anywhere outside `Team.xcconfig`, `Config/` and the
  launchd plist is a review error.
