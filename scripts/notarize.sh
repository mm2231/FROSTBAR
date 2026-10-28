#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 mm2231 and FrostBar contributors
#
# Archive, export with Developer ID, notarize and staple FrostBar.
#
# Credentials, one of:
#   xcrun notarytool store-credentials FrostBar \
#       --apple-id you@example.com --team-id ABCDE12345 --password app-specific-password
#   NOTARY_PROFILE=FrostBar scripts/notarize.sh
#
#   or NOTARY_APPLE_ID / NOTARY_PASSWORD / NOTARY_TEAM_ID in the environment.
#
# Environment:
#   NOTARY_PROFILE    keychain profile name (default: FrostBar)
#   SKIP_NOTARIZATION 1 to stop after export (signed, but not notarized)
#   ARTIFACT_DIR      output directory (default: build/artifacts)

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

read_config() {
    awk -F'=' -v key="$1" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
        value = $2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
    }' Team.xcconfig
}

TEAM_ID="$(read_config TEAM_ID)"
VERSION="$(read_config MARKETING_VERSION)"
BUILD="$(read_config CURRENT_PROJECT_VERSION)"
ARTIFACT_DIR="${ARTIFACT_DIR:-build/artifacts}"

[[ -n "$TEAM_ID" && "$TEAM_ID" != "YOURTEAMID" ]] || fail "set TEAM_ID in Team.xcconfig (see ADR-0004)"
[[ -n "$VERSION" && -n "$BUILD" ]] || fail "MARKETING_VERSION / CURRENT_PROJECT_VERSION missing from Team.xcconfig"

command -v xcodebuild >/dev/null || fail "xcodebuild not found; install Xcode 15 or later"

if [[ "${SKIP_NOTARIZATION:-0}" != "1" ]]; then
    if [[ -n "${NOTARY_APPLE_ID:-}" ]]; then
        : "${NOTARY_PASSWORD:?NOTARY_PASSWORD is required with NOTARY_APPLE_ID}"
        NOTARY_ARGS=(--apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "${NOTARY_TEAM_ID:-$TEAM_ID}")
    else
        NOTARY_ARGS=(--keychain-profile "${NOTARY_PROFILE:-FrostBar}")
    fi
fi

# The generated project must match the tree before anything is archived.
info "Checking that FrostBar.xcodeproj is current"
python3 scripts/gen_xcodeproj.py --check

ARCHIVE="build/FrostBar.xcarchive"
EXPORT_DIR="build/export"
APP="$EXPORT_DIR/FrostBar.app"
ZIP="$ARTIFACT_DIR/FrostBar-$VERSION.zip"

rm -rf "$ARCHIVE" "$EXPORT_DIR" "$ZIP"
mkdir -p "$ARTIFACT_DIR" build

info "Archiving FrostBar $VERSION ($BUILD)"
xcodebuild \
    -project FrostBar.xcodeproj \
    -scheme FrostBar \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    archive

info "Exporting with Developer ID"
sed "s/__TEAM_ID__/$TEAM_ID/g" scripts/ExportOptions.plist > build/ExportOptions.plist
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist build/ExportOptions.plist \
    -allowProvisioningUpdates

[[ -d "$APP" ]] || fail "export did not produce FrostBar.app"

info "Verifying signatures and bundle layout"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign --verify --strict --verbose=2 "$APP/Contents/MacOS/FrostBarHelper"
test -x "$APP/Contents/MacOS/FrostBarHelper" || fail "FrostBarHelper is missing from Contents/MacOS"
ls "$APP/Contents/Library/LaunchDaemons/"*.plist >/dev/null 2>&1 || fail "launch daemon plist is missing"

# `SMAppService` refuses a daemon whose identifier does not match its plist.
PLIST_ID="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$APP"/Contents/Library/LaunchDaemons/*.plist)"
HELPER_ID="$(/usr/libexec/PlistBuddy -c 'Print :FrostBarHelperBundleIdentifier' "$APP/Contents/Info.plist")"
if [[ "$PLIST_ID" != "$HELPER_ID" ]]; then
    fail "launch daemon Label ($PLIST_ID) does not match the helper bundle id ($HELPER_ID)"
fi

APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
EXPECTED_APP_ID="$(read_config APP_BUNDLE_ID)"
if [[ "$APP_ID" != "$EXPECTED_APP_ID" ]]; then
    fail "exported CFBundleIdentifier ($APP_ID) does not match APP_BUNDLE_ID ($EXPECTED_APP_ID)"
fi

if [[ "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist")" == REPLACE_WITH* ]]; then
    fail "SUPublicEDKey is still the placeholder; updates would be rejected by Sparkle"
fi

if [[ "${SKIP_NOTARIZATION:-0}" == "1" ]]; then
    ditto -c -k --keepParent "$APP" "$ZIP"
    info "Skipped notarization (SKIP_NOTARIZATION=1)"
    echo "$ZIP"
    exit 0
fi

info "Submitting to the notary service (this normally takes a few minutes)"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" "${NOTARY_ARGS[@]}" --wait

info "Stapling the ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

info "Assessing with Gatekeeper"
spctl --assess --type execute --verbose=2 "$APP"

# The distributed zip must contain the stapled app, so it is rebuilt after
# stapling rather than reused from the submission step.
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

info "Release artifact"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
echo "$ZIP"
