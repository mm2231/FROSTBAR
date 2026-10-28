# FrostBar

Fan control for Intel MacBook Pro with Touch Bar (2016–2019), with a Touch Bar
first UI and a menu bar fallback. Apple Silicon Macs are supported in
**monitor-only** mode.

> **Warning:** FrostBar writes to the System Management Controller. Incorrect
> values can cause overheating, excessive noise or unexpected shutdowns. The
> project is provided without warranty; read [SECURITY.md](SECURITY.md) before
> installing.

## Status

M0 — architecture scaffold, complete. All four SPM modules, both Xcode targets,
the Touch Bar UI, the menu bar fallback, the settings window, the privileged
helper and the release tooling are implemented. Domain logic is covered by
`swift test`; hardware validation on each supported MacBookPro model is still
outstanding, so this is not ready for daily fan control.

## Architecture

```
FrostBarCore      value types, configuration model, protocols (no AppKit/IOKit)
FrostBarModes     evaluation engine: curves, rules, hysteresis, safety, control loop
FrostBarProfiles  JSON persistence, migrations, import/export, profile resolution
FrostBarSMC       read-only SMC access for the app, write primitives for the helper
SMCKit            vendored MIT transport layer (patched, see Vendored/SMCKit/PATCHES.md)

FrostBar.app       SwiftUI + AppKit UI, XPC client, Sparkle, composition root
FrostBarHelper     root launchd daemon: the only process that writes to the SMC
```

Dependency rule: `FrostBarCore` imports nothing but Foundation. `AppKit`,
`IOKit`, `ServiceManagement` and `Sparkle` never appear in the core modules, so
`swift test` works without Xcode and without code signing.

Every SMC write is funnelled through `FrostBarHelper`. The helper validates the
request (`FanWritePolicy`), clamps it, enforces a TTL and restores Apple's
automatic mode if the app stops sending heartbeats.

## Requirements

- macOS 13 Ventura or later
- Swift 5.8+ toolchain for the packages
- Xcode 15+ for the app and helper targets

## Build and test

```sh
swift build
swift test                 # no Xcode, no signing, no hardware required

# app + helper (needs Xcode and a team id in Team.xcconfig)
python3 scripts/gen_xcodeproj.py    # regenerate after adding or moving sources
open FrostBar.xcodeproj
```

`FrostBar.xcodeproj` is generated from the tree, `Package.swift` and the
xcconfigs. Edit those and regenerate; do not hand-edit the project file. CI runs
`python3 scripts/gen_xcodeproj.py --check` so the committed project cannot drift.

For a local build without a Developer ID certificate, set
`CODE_SIGN_IDENTITY = -` and `CODE_SIGN_STYLE = Automatic` in your local copy of
`Team.xcconfig` (never commit that change). `launchd` will still refuse to
register the helper until the app is signed with a real team identifier.

Hardware-dependent SMC tests are skipped unless explicitly enabled:

```sh
FROSTBAR_SMC_INTEGRATION=1 swift test --filter FrostBarSMCTests
swift run FrostBarProbe            # JSON sensor/fan report for the current Mac
```

## Releasing

Prerequisites: a Developer ID Application certificate, an Apple ID with an
app-specific password, and the Sparkle EdDSA key pair
(`generate_keys` from Sparkle). `TEAM_ID` and `SPARKLE_PUBLIC_ED_KEY` live in
[Team.xcconfig](Team.xcconfig).

```sh
xcrun notarytool store-credentials FrostBar \
    --apple-id you@example.com --team-id ABCDE12345 --password app-specific-password

scripts/bump_version.sh 0.2.0        # updates Team.xcconfig and CHANGELOG.md
scripts/notarize.sh                 # archive, export, notarize, staple, zip
scripts/generate_appcast.sh         # signs build/artifacts/appcast.xml
gh release upload v0.2.0 build/artifacts/appcast.xml --clobber
```

`SUFeedURL` points at the `latest` release asset, so users always read the most
recent `appcast.xml`. `.github/workflows/release.yml` performs the same steps
from a `v*` tag using repository secrets; see the workflow for the expected
names. Bundles and daemon identifiers must not change after the first release
(ADR-0007).

## Scripts

| Script | Purpose |
|---|---|
| `scripts/gen_xcodeproj.py` | Generate `FrostBar.xcodeproj` (deterministic IDs, `--check` mode) |
| `scripts/set_bundle_id.sh` | Rewrite bundle identifiers across xcconfig, helper constants and launchd plist |
| `scripts/check_spdx.sh` | Fail if a first-party source file lacks the GPL SPDX header |
| `scripts/bump_version.sh` | Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` and date the changelog |
| `scripts/notarize.sh` | Archive, Developer ID export, notarize, staple and zip |
| `scripts/generate_appcast.sh` | Sign the Sparkle appcast for the current release |

## Safety model

| Guardrail | Value | Enforced by |
|---|---|---|
| Emergency handoff to Apple auto | 95 °C | evaluator + helper |
| `forceZero` forbidden at or above | 50 °C | evaluator + helper |
| `forceZero` forced back to auto at or above | 70 °C | evaluator + helper |
| Max slew | 800 rpm/s | evaluator + helper |
| Watchdog without heartbeat | 10 s | helper |

Guardrails are compile-time constants in `HardwareGuardrails`. They are not
`Codable`, have no settings switch, and are covered by tests that assert a
configuration cannot weaken them. See [docs/adr/0003-fan-stop.md](docs/adr/0003-fan-stop.md).

## Layout

```
Sources/        SPM modules and their tests
App/            FrostBar.app sources (UI, adapters, composition root)
Helper/         FrostBarHelper sources and launchd plist
Vendored/       third-party code with preserved licenses
Config/         xcconfig, entitlements, Info.plist
docs/adr/       architecture decision records
scripts/        release, notarization, project generation helpers
```

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
