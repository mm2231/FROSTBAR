#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 mm2231 and FrostBar contributors
#
# Build/refresh appcast.xml from notarized zips with Sparkle's generate_appcast.
#
#   scripts/generate_appcast.sh build/artifacts
#
# The archives directory must contain one zip per release, named
# FrostBar-<version>.zip. Older archives are kept so Sparkle can offer deltas.
#
# Environment:
#   GENERATE_APPCAST    path to Sparkle's tool (otherwise discovered in
#                       DerivedData or PATH)
#   SPARKLE_ED_KEY_FILE private EdDSA key file; defaults to the login keychain
#   GITHUB_REPOSITORY   owner/name used for download URLs (default mm2231/FROSTBAR)
#   RELEASE_TAG         tag the archives belong to (default v<MARKETING_VERSION>)

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

ARCHIVES_DIR="${1:-build/artifacts}"
REPO="${GITHUB_REPOSITORY:-mm2231/FROSTBAR}"
VERSION="$(read_config MARKETING_VERSION)"
TAG="${RELEASE_TAG:-v$VERSION}"

[[ -d "$ARCHIVES_DIR" ]] || fail "no archives directory at $ARCHIVES_DIR"
ls "$ARCHIVES_DIR"/FrostBar-*.zip >/dev/null 2>&1 || fail "no FrostBar-*.zip in $ARCHIVES_DIR"

if [[ -z "${GENERATE_APPCAST:-}" ]]; then
    if command -v generate_appcast >/dev/null 2>&1; then
        GENERATE_APPCAST="$(command -v generate_appcast)"
    else
        GENERATE_APPCAST="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
            -path '*artifacts/sparkle/Sparkle/bin/generate_appcast' -type f 2>/dev/null | head -n 1 || true)"
    fi
fi

if [[ -z "$GENERATE_APPCAST" || ! -x "$GENERATE_APPCAST" ]]; then
    cat >&2 <<'EOF'
error: generate_appcast was not found.

Build the project once in Xcode (Sparkle is a package dependency), or download
the Sparkle release and point at its tool:

    GENERATE_APPCAST=/path/to/Sparkle-2.x/bin/generate_appcast scripts/generate_appcast.sh
EOF
    exit 1
fi

# SUFeedURL points at the "latest" release asset, so each release only needs
# absolute download URLs for its own assets.
URL_PREFIX="https://github.com/$REPO/releases/download/$TAG/"

ARGS=(--download-url-prefix "$URL_PREFIX" --embed-release-notes)
if [[ -n "${SPARKLE_ED_KEY_FILE:-}" ]]; then
    ARGS+=(--ed-key-file "$SPARKLE_ED_KEY_FILE")
fi

info "Signing appcast for $TAG with $(basename "$GENERATE_APPCAST")"
(cd "$ARCHIVES_DIR" && "$GENERATE_APPCAST" "${ARGS[@]}" .)

APPCAST="$ARCHIVES_DIR/appcast.xml"
[[ -f "$APPCAST" ]] || fail "generate_appcast did not produce appcast.xml"

grep -q "sparkle:edSignature" "$APPCAST" || fail "appcast.xml has no EdDSA signature; check the Sparkle key setup"
grep -q "$URL_PREFIX" "$APPCAST" || fail "appcast.xml does not use $URL_PREFIX"

info "Appcast written to $APPCAST"
echo
echo "Upload with:"
echo "  gh release upload $TAG $ARCHIVES_DIR/appcast.xml --clobber"
