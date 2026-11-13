# Created on 2026-10-21
# Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.
#
# Prints the compiler and linker diagnostics in an xcodebuild log, one per line.
# Used by build.sh and test.sh:  awk -f scripts/_diagnostics.awk LOG | sort -u
#
# A diagnostic raised inside a macro expansion (#expect, #require, @Observable…)
# is reported against the macro rather than a file, with the file on the next line:
#
#   macro expansion #expect:2:3: error: call can throw, but it is not marked with 'try'
#   `- /path/Test.swift:25:59: note: expanded code originates here
#
# so it is printed at that file location instead, naming the macro:
#
#   /path/Test.swift:25:59: error: call can throw, … (in #expect)

function flush_macro() {
    if (macro != "") print macro
    macro = ""
}

# The line after a macro diagnostic says where the expansion came from.
macro != "" && /^`- \/.+:[0-9]+:[0-9]+: note: expanded code originates here/ {
    location = $0
    sub(/^`- /, "", location)
    sub(/: note: expanded code originates here.*$/, "", location)

    name = macro
    sub(/^macro expansion /, "", name)
    message = name
    sub(/:.*$/, "", name)
    sub(/^[^:]+:[0-9]+:[0-9]+: /, "", message)

    print location ": " message " (in " name ")"
    macro = ""
    next
}

{ flush_macro() }

/^macro expansion [^:]+:[0-9]+:[0-9]+: (error|warning): / {
    macro = $0
    next
}

/^\/.+:[0-9]+:[0-9]+: (error|warning): / ||
/^(xcodebuild: error: |clang: error: |ld: (error|warning): |Undefined symbols)/ {
    print
}

END { flush_macro() }
