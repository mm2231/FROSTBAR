#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 mm2231 and FrostBar contributors
#
# Fails if a first-party source file is missing the GPL SPDX header. Vendored
# code keeps its upstream license headers and is excluded (see NOTICE and
# ADR-0002). Shell and Python tooling is included because those scripts run with
# the same privileges as the build.
#
# Files whose interpreter directive must stay on line 1 (none currently) would
# need the header on line 2; the check looks at the first five lines.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

missing=0
checked=0

while IFS= read -r -d '' file; do
    checked=$((checked + 1))
    if ! head -n 5 "$file" | grep -q "SPDX-License-Identifier: GPL-3.0-or-later"; then
        echo "missing SPDX-License-Identifier: GPL-3.0-or-later -> $file" >&2
        missing=1
    fi
done < <(find App Helper Shared Sources Tests Tools scripts \
    \( -name '*.swift' -o -name '*.sh' -o -name '*.py' \) \
    -not -path '*/.*' -print0 2>/dev/null)

# Package.swift must keep `// swift-tools-version` on line 1, so the header is
# checked separately rather than with the loop above.
if ! head -n 5 Package.swift | grep -q "SPDX-License-Identifier: GPL-3.0-or-later"; then
    echo "missing SPDX-License-Identifier: GPL-3.0-or-later -> Package.swift" >&2
    missing=1
fi
checked=$((checked + 1))

if [[ "$missing" -ne 0 ]]; then
    echo "SPDX check failed." >&2
    exit 1
fi

echo "SPDX check passed ($checked files)."
