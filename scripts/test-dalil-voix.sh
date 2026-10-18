#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dalil-voix.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
${SWIFTC:-swiftc} -swift-version 6 -parse-as-library \
    NotchBuddy/Sources/App/ClaudeCLI.swift \
    NotchBuddy/Sources/App/Dalil/DalilPontFlux.swift \
    NotchBuddy/Sources/App/Dalil/DalilPont.swift \
    NotchBuddy/Sources/App/Dalil/DalilVoixTexte.swift \
    tests/DalilVoixTexteTests.swift -o "$TEST_DIR/dalil-voix-tests"
"$TEST_DIR/dalil-voix-tests"
