#!/usr/bin/env bash
# Build the FENblixExtensionKit package and both example apps, printing only
# compiler diagnostics and the result.
# Usage: scripts/build.sh [extra xcodebuild args]   (CONFIG override via env)
set -uo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-Debug}"
LOG="${TMPDIR:-/tmp}/fenblixkit-build.log"

# A leftover example app holds its binary and makes CodeSign fail on the next
# build. Kill only processes launched from this project's build products.
pkill -f "Build/Products/.*/FENblixThemeExample.app/Contents/MacOS/" 2>/dev/null || true
pkill -f "Build/Products/.*/FENblixEvaluatorExample.app/Contents/MacOS/" 2>/dev/null || true

# Each line: the directory to build in, then the xcodebuild arguments naming
# what to build. The package builds from its own directory, where xcodebuild
# finds Package.swift.
BUILDS=(
  ".|-scheme FENblixExtensionKit"
  "Examples|-project Examples.xcodeproj -scheme FENblixThemeExample"
  "Examples|-project Examples.xcodeproj -scheme FENblixEvaluatorExample"
)

: >"$LOG"
status=0
for build in "${BUILDS[@]}"; do
  dir="${build%%|*}"
  read -r -a what <<<"${build#*|}"
  (cd "$dir" && xcodebuild build "${what[@]}" \
    -configuration "$CONFIG" \
    -destination 'platform=macOS' \
    -quiet \
    "$@") >>"$LOG" 2>&1 || { status=$?; break; }
done

found=$(awk -f scripts/_diagnostics.awk "$LOG" | sort -u)
[ -n "$found" ] && echo "$found"

if [ $status -eq 0 ]; then
  echo "OK"
  exit 0
fi

if [ -z "$found" ]; then
  echo "--- build failed (exit $status), no diagnostics matched; see $LOG ---"
  grep -E '^(\*\* |Command .* failed|Testing failed:)' "$LOG" | sort -u | head -10
  echo "(if this looks unrelated to your code, try: scripts/clean.sh)"
fi
exit $status
