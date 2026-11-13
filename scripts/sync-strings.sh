#!/usr/bin/env bash
# Build, then bring every String Catalog (Localizable.xcstrings) up to date with
# the strings the compiler extracted from its target's source, and check every
# InfoPlist.xcstrings against the build settings it translates.
# Usage: scripts/sync-strings.sh   (CONFIG override via env)
#
# Xcode's own build syncs catalogs as it goes; a command-line build never
# writes to them, so after editing user-visible text from the command line run
# this. Each catalog sits in its target's synchronized folder, and the folder's
# name is the target's. Strings no longer in the source are marked stale, or
# dropped if they were never translated. Extracted data from a deleted source
# file can linger in DerivedData and keep its strings alive; scripts/clean.sh
# clears it.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${CONFIG:-Debug}"
# The package shows no text and has no catalog; every catalog is in an example
# target, in the examples project.
PROJECT=Examples/Examples.xcodeproj

scripts/build.sh

TEMP=$(xcodebuild -project "$PROJECT" -scheme FENblixEvaluatorExample -configuration "$CONFIG" -showBuildSettings 2>/dev/null \
       | awk -F' = ' '/^ +PROJECT_TEMP_DIR = /{print $2; exit}')

find Examples -name Localizable.xcstrings | sort | while read -r catalog; do
  target=$(basename "$(dirname "$catalog")")
  dir="$TEMP/$CONFIG/$target.build"
  if [ ! -d "$dir" ]; then
    echo "no build of target $target for $catalog" >&2
    exit 1
  fi
  data=()
  while IFS= read -r file; do data+=("$file"); done < <(find "$dir" -name '*.stringsdata')
  if [ ${#data[@]} -eq 0 ]; then
    echo "no extracted strings for $target; is SWIFT_EMIT_LOC_STRINGS on?" >&2
    exit 1
  fi
  xcrun xcstringstool sync "$catalog" --stringsdata "${data[@]}"
  echo "$catalog: $(xcrun xcstringstool print "$catalog" | grep -c .) strings"
done

# InfoPlist.xcstrings catalogs: a command-line build extracts nothing into
# them. Xcode's own build adds every localizable Info.plist key it generates
# (CFBundleName, NSHumanReadableCopyright, CFBundleDisplayName) with a generic
# comment, and keeps a comment already written. Their English is never
# compiled, since the Info.plist itself holds it, so check each entry's English
# value against the build setting it comes from: INFOPLIST_KEY_<key>, or
# PRODUCT_NAME for CFBundleName.
SETTINGS=$(xcodebuild -project "$PROJECT" -showBuildSettings -alltargets -configuration "$CONFIG" 2>/dev/null)

# Prints the value of build setting $2 for target $1, or nothing and fails if
# the target has no such setting or it is empty.
setting() {
  awk -v t="$1" -v k="$2" '
    /^Build settings for action build and target / { current = $NF; sub(":", "", current) }
    current == t && $1 == k && $2 == "=" { print substr($0, index($0, "= ") + 2); found = 1; exit }
    END { exit !found }
  ' <<<"$SETTINGS"
}

status=0
while read -r catalog; do
  target=$(basename "$(dirname "$catalog")")
  matches=yes
  while IFS=$'\t' read -r key value; do
    if ! expected=$(setting "$target" "INFOPLIST_KEY_$key"); then
      # -showBuildSettings leaves out a setting whose value is empty.
      if [ "$key" = CFBundleName ]; then
        expected=$(setting "$target" PRODUCT_NAME)
      else
        expected=""
      fi
    fi
    if [ "$expected" != "$value" ]; then
      echo "$catalog: $key is \"$value\" but target $target sets \"$expected\"" >&2
      status=1
      matches=no
    fi
  done < <(python3 -I -c '
import json, sys
for key, entry in json.load(open(sys.argv[1]))["strings"].items():
    print(key, entry["localizations"]["en"]["stringUnit"]["value"], sep="\t")
' "$catalog")
  if [ "$matches" = yes ]; then echo "$catalog: matches target $target"; fi
done < <(find Examples -name InfoPlist.xcstrings | sort)
exit $status
