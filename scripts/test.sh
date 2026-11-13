#!/usr/bin/env bash
# Run the package's tests and the example evaluator's, printing only what
# failed (with file:line assertion detail). None of them needs an extension
# turned on.
#   scripts/test.sh                              every test
#   scripts/test.sh --filter 'Suite/test()'      one package test (Swift Testing needs the parentheses)
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

pkill -f "Build/Products/.*/FENblixEvaluatorExample.app/Contents/MacOS/" 2>/dev/null || true

# Each line: a name for the run, the directory to run in, then the xcodebuild
# arguments naming what to test.
RUNS=(
  "package|.|-scheme FENblixExtensionKit"
  "examples|Examples|-project Examples.xcodeproj -scheme FENblixEvaluatorExample"
)
if [ "${1:-}" = --filter ]; then
  RUNS=("package|.|-scheme FENblixExtensionKit -only-testing:FENblixExtensionKitTests/$2")
  shift 2
fi

overall=0
for run in "${RUNS[@]}"; do
  name="${run%%|*}"; rest="${run#*|}"
  dir="${rest%%|*}"
  read -r -a what <<<"${rest#*|}"
  LOG="${TMPDIR:-/tmp}/fenblixkit-test-$name.log"

  (cd "$dir" && xcodebuild test "${what[@]}" -destination 'platform=macOS' "$@") >"$LOG" 2>&1
  status=$?
  echo "$name:"

  diagnostics=$(awk -f "$ROOT/scripts/_diagnostics.awk" "$LOG" | sort -u)
  [ -n "$diagnostics" ] && echo "$diagnostics"

  # A failed build still leaves a result bundle, with no tests in it. Say the
  # build failed rather than letting the bundle report that no tests ran.
  if [ $status -ne 0 ] && grep -q -E 'Testing cancelled because the build failed|^\*\* BUILD FAILED \*\*' "$LOG"; then
    echo "BUILD FAILED"
    [ -z "$diagnostics" ] && echo "(no diagnostics matched; see $LOG)"
    overall=1
    continue
  fi

  XCR=$(grep -o '/Users/[^ ]*\.xcresult' "$LOG" | tail -1)
  if [ -n "$XCR" ] && [ -d "$XCR" ]; then
    python3 "$ROOT/scripts/_xcresult.py" "$XCR" || overall=1
    continue
  fi

  echo "--- test run did not produce results (exit $status); reason from $LOG ---"
  grep -A2 -E '^Testing failed:|^xcodebuild: error:|error:' "$LOG" | head -12
  echo "(if this looks unrelated to your code, try: scripts/clean.sh)"
  overall=1
done
exit $overall
