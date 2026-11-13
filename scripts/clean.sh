#!/usr/bin/env bash
# Wipe this repo's DerivedData: the package's and the examples project's. Use
# when builds fail for reasons that don't match the source (CodeSign failures,
# test-runner bootstrap crashes).
set -euo pipefail
cd "$(dirname "$0")/.."
pkill -f "Build/Products/.*/FENblix(Theme|Evaluator)Example.app/Contents/MacOS/" 2>/dev/null || true

# Prints the DerivedData folder of the build that the arguments name.
derived_data() {
  xcodebuild "$@" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^ +BUILD_DIR = /{print $2; exit}' | sed 's|/Build/Products||'
}

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

for dd in "$(derived_data -scheme FENblixExtensionKit)" \
          "$(cd Examples && derived_data -project Examples.xcodeproj -scheme FENblixThemeExample)"; do
  if [ -n "$dd" ] && [ -d "$dd" ]; then
    # Unregister the example apps first, or the system goes on listing their
    # extensions until it notices the bundles are gone.
    find "$dd/Build/Products" -maxdepth 2 -name '*.app' -exec "$LSREGISTER" -u {} \; 2>/dev/null || true
    rm -rf "$dd" && echo "removed $dd"
  fi
done
