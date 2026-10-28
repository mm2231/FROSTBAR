# ADR-0007: Bundle identifiers are immutable; appcast location is not

Status: accepted (2026-10-28)

## Context

A proposal was to use `io.github.<username>.frostbar` if the Sparkle appcast is
published through GitHub Pages. Bundle identifiers are not tied to a domain and
changing them after release has real costs: the launchd registration, the login
item approval, TCC identity and update identity all key off the identifier.

## Decision

- Keep `com.mm2231.frostbar` / `com.mm2231.frostbar.helper` permanently.
- Host the appcast on GitHub Pages (`https://mm2231.github.io/FROSTBAR/appcast.xml`)
  or as a release asset (`.../releases/latest/download/appcast.xml`). Either is
  an HTTPS URL in `SUFeedURL`; neither affects the bundle identifier.
- If the identifiers ever must change, it is a major-version migration with an
  explicit uninstall/reinstall path, not an in-place update.

## Consequences

- Forks may change identifiers, but must run `scripts/set_bundle_id.sh` and
  accept that it is a different application for macOS.
- The Sparkle feed URL stays in `Team.xcconfig` and can change freely between
  releases.
