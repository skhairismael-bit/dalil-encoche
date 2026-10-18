#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dalil-enveloppes.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc \
    NotchBuddy/Sources/CoucouKit/DalilEnveloppes.swift \
    tests/DalilEnveloppesTests.swift -o "$TEST_DIR/dalil-enveloppes-tests"
"$TEST_DIR/dalil-enveloppes-tests"
swiftc \
    NotchBuddy/Sources/CoucouKit/DalilEnveloppes.swift \
    NotchBuddy/Sources/App/DalilEnveloppesStore.swift \
    tests/DalilEnveloppesStoreTests.swift -o "$TEST_DIR/dalil-enveloppes-store-tests"
"$TEST_DIR/dalil-enveloppes-store-tests"
