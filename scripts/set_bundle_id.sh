#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 mm2231 and FrostBar contributors
#
# Usage: scripts/set_bundle_id.sh <app-bundle-id> [team-id]
#
# Bundle identifiers appear in four places that launchd cannot reconcile
# automatically: Team.xcconfig, HelperConstants.swift, the launchd plist label
# and its file name. This script rewrites all of them together. See ADR-0004.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

usage() {
    echo "usage: $0 <app-bundle-id> [team-id]" >&2
    echo "example: $0 com.example.frostbar ABCDE12345" >&2
    exit 2
}

[[ $# -ge 1 ]] || usage

APP_ID="$1"
TEAM="${2:-}"

if [[ ! "$APP_ID" =~ ^[A-Za-z0-9][A-Za-z0-9.-]+$ ]]; then
    echo "error: '$APP_ID' is not a valid bundle identifier" >&2
    exit 2
fi

HELPER_ID="${APP_ID}.helper"

read_config_value() {
    awk -F'=' -v key="$1" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
        value = $2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
    }' Team.xcconfig
}

OLD_APP_ID="$(read_config_value APP_BUNDLE_ID)"
OLD_HELPER_ID="$(read_config_value HELPER_BUNDLE_ID)"

if [[ -z "$OLD_APP_ID" || -z "$OLD_HELPER_ID" ]]; then
    echo "error: could not read APP_BUNDLE_ID / HELPER_BUNDLE_ID from Team.xcconfig" >&2
    exit 1
fi

if [[ "$OLD_APP_ID" == "$APP_ID" && -z "$TEAM" ]]; then
    echo "Nothing to do: $APP_ID is already configured."
    exit 0
fi

# Team.xcconfig -------------------------------------------------------------
/usr/bin/sed -i '' -E "s|^APP_BUNDLE_ID[[:space:]]*=.*|APP_BUNDLE_ID            = ${APP_ID}|" Team.xcconfig
/usr/bin/sed -i '' -E "s|^HELPER_BUNDLE_ID[[:space:]]*=.*|HELPER_BUNDLE_ID         = \$(APP_BUNDLE_ID).helper|" Team.xcconfig
if [[ -n "$TEAM" ]]; then
    /usr/bin/sed -i '' -E "s|^TEAM_ID[[:space:]]*=.*|TEAM_ID                  = ${TEAM}|" Team.xcconfig
fi

# Shared helper constants ---------------------------------------------------
CONSTANTS="Shared/HelperProtocol/HelperConstants.swift"
if [[ -f "$CONSTANTS" ]]; then
    OLD_HELPER_ID="$OLD_HELPER_ID" NEW_HELPER_ID="$HELPER_ID" perl -pi -e \
        's/\Q$ENV{OLD_HELPER_ID}\E/$ENV{NEW_HELPER_ID}/g' "$CONSTANTS"
fi

# launchd plist: file name, Label, MachServices, associated app --------------
OLD_PLIST="Helper/LaunchDaemon/${OLD_HELPER_ID}.plist"
NEW_PLIST="Helper/LaunchDaemon/${HELPER_ID}.plist"

if [[ -f "$OLD_PLIST" ]]; then
    if [[ "$OLD_PLIST" != "$NEW_PLIST" ]]; then
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "$OLD_PLIST" >/dev/null 2>&1; then
            git mv "$OLD_PLIST" "$NEW_PLIST"
        else
            mv "$OLD_PLIST" "$NEW_PLIST"
        fi
    fi
else
    echo "warning: $OLD_PLIST not found; check Helper/LaunchDaemon manually" >&2
fi

if [[ -f "$NEW_PLIST" ]]; then
    OLD_APP_ID="$OLD_APP_ID" NEW_APP_ID="$APP_ID" \
    OLD_HELPER_ID="$OLD_HELPER_ID" NEW_HELPER_ID="$HELPER_ID" perl -pi -e \
        's/\Q$ENV{OLD_HELPER_ID}\E/$ENV{NEW_HELPER_ID}/g; s/\Q$ENV{OLD_APP_ID}\E/$ENV{NEW_APP_ID}/g' "$NEW_PLIST"
fi

# The generated project does not contain bundle identifiers, but it embeds the
# plist by path, so regenerate it when the file was renamed.
if [[ "$OLD_PLIST" != "$NEW_PLIST" && -f scripts/gen_xcodeproj.py ]]; then
    echo "Regenerating FrostBar.xcodeproj for the renamed launch daemon..."
    python3 scripts/gen_xcodeproj.py
fi

echo "App:    $APP_ID"
echo "Helper: $HELPER_ID"
if [[ -n "$TEAM" ]]; then
    echo "Team:   $TEAM"
fi
echo
echo "Next: set SPARKLE_PUBLIC_ED_KEY in Team.xcconfig, then build with Xcode."
echo "Identifiers in an already released build cannot be changed in place; see ADR-0007."
