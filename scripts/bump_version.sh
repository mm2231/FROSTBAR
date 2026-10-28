#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 mm2231 and FrostBar contributors
#
# Usage: scripts/bump_version.sh <marketing-version> [build-number]
#   scripts/bump_version.sh 0.2.0        # build number is incremented
#   scripts/bump_version.sh 1.0.0 42
#
# Updates Team.xcconfig, which is the single source for both targets, and
# inserts a dated heading in CHANGELOG.md.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

usage() {
    echo "usage: $0 <marketing-version> [build-number]" >&2
    echo "example: $0 0.2.0 12" >&2
    exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage

VERSION="$1"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    echo "error: '$VERSION' is not a semantic version (MAJOR.MINOR.PATCH[-prerelease])" >&2
    exit 2
fi

read_config() {
    awk -F'=' -v key="$1" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
        value = $2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
    }' Team.xcconfig
}

CURRENT_VERSION="$(read_config MARKETING_VERSION)"
CURRENT_BUILD="$(read_config CURRENT_PROJECT_VERSION)"

if [[ -n "${2:-}" ]]; then
    BUILD="$2"
    [[ "$BUILD" =~ ^[0-9]+$ ]] || { echo "error: build number must be an integer" >&2; exit 2; }
    if [[ -n "$CURRENT_BUILD" ]] && (( BUILD <= CURRENT_BUILD )); then
        echo "error: build $BUILD is not greater than the current build $CURRENT_BUILD" >&2
        echo "hint: Sparkle compares CFBundleVersion, so it must always increase." >&2
        exit 2
    fi
else
    BUILD=$(( ${CURRENT_BUILD:-0} + 1 ))
fi

echo "FrostBar $CURRENT_VERSION ($CURRENT_BUILD) -> $VERSION ($BUILD)"

/usr/bin/sed -i '' -E "s|^MARKETING_VERSION[[:space:]]*=.*|MARKETING_VERSION        = ${VERSION}|" Team.xcconfig
/usr/bin/sed -i '' -E "s|^CURRENT_PROJECT_VERSION[[:space:]]*=.*|CURRENT_PROJECT_VERSION  = ${BUILD}|" Team.xcconfig

# Keep a Changelog: a dated section under Unreleased, without disturbing notes
# that are already being written there.
TODAY="$(date +%Y-%m-%d)"
if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
    /usr/bin/awk -v heading="## [$VERSION] - $TODAY" '
        { print }
        /^## \[Unreleased\]/ && !inserted {
            print ""
            print heading
            inserted = 1
        }
    ' CHANGELOG.md > CHANGELOG.md.new
    mv CHANGELOG.md.new CHANGELOG.md
fi

echo
echo "Next:"
echo "  1. python3 scripts/gen_xcodeproj.py --check"
echo "  2. git commit -am \"Release $VERSION\""
echo "  3. scripts/notarize.sh"
echo "  4. scripts/generate_appcast.sh"
