"""Summarize an .xcresult bundle for scripts/test.sh.

Console output from xcodebuild mixes XCTest and Swift Testing formats, so we
read the result bundle instead -- it is the authoritative record of what ran.
Usage: _xcresult.py <path.xcresult>   Exit 0 if tests passed and at least one ran.
"""
import json
import subprocess
import sys


def run(*args):
    out = subprocess.run(
        ["xcrun", "xcresulttool", *args], capture_output=True, text=True
    )
    return json.loads(out.stdout) if out.returncode == 0 and out.stdout else None


def failures(node, test=None, found=None):
    found = [] if found is None else found
    if node.get("nodeType") == "Test Case":
        test = node.get("nodeIdentifier") or node.get("name")
    if node.get("nodeType") == "Failure Message":
        found.append((test, node.get("name")))
    for child in node.get("children", []):
        failures(child, test, found)
    return found


def main(path):
    summary = run("get", "test-results", "summary", "--path", path)
    if summary is None:
        print("could not read test results from", path)
        return 2

    total = summary.get("totalTestCount", 0)
    passed = summary.get("passedTests", 0)
    failed = summary.get("failedTests", 0)
    skipped = summary.get("skippedTests", 0)

    if failed:
        details = run("get", "test-results", "tests", "--path", path) or {}
        for node in details.get("testNodes", []):
            for test, message in failures(node):
                print("  %s: %s" % (test, message))

    if total == 0:
        print("NO TESTS RAN -- check the scheme's test targets and any -only-testing filter")
        return 1

    tail = ", %d skipped" % skipped if skipped else ""
    if failed:
        print("FAILED (%d of %d tests failed%s)" % (failed, total, tail))
        return 1
    print("OK (%d tests passed%s)" % (passed, tail))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
