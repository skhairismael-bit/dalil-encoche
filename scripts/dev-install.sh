#!/usr/bin/env bash
# Builds Coucou the way it runs every day (DebugCloud: signed with the Apple Development
# certificate, iPhone link on) and makes it the only Coucou: installed in /Applications,
# the copies left by earlier builds removed.
#
# Why: macOS gives its permissions (Accessibility, Screen Recording, microphone...) to one
# app signed one way. An unsigned Debug build looks like a new app after every build, and
# each copy of Coucou.app is one more entry to allow. One signed app at one place keeps
# its permissions from one build to the next.
#
#   ./scripts/dev-install.sh
#
# Use it instead of xcodebuild by hand or ▶ in Xcode (which leave copies in DerivedData).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="fr.louisraille.NotchBuddy"
DERIVED="${HOME}/Library/Developer/Xcode/DerivedData/CoucouDev"
BUILT="${DERIVED}/Build/Products/DebugCloud/Dalil.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

# The App Store Coucou (fr.louisraille.Coucou) has the same file name: never overwrite it.
TARGET="/Applications/Dalil.app"
if [ -d "${TARGET}" ]; then
  EXISTING=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${TARGET}/Contents/Info.plist" 2>/dev/null || echo "")
  if [ "${EXISTING}" != "${BUNDLE_ID}" ]; then
    mkdir -p "${HOME}/Applications"
    TARGET="${HOME}/Applications/Dalil.app"
    echo "/Applications/Dalil.app is another Dalil (${EXISTING}): installing in ~/Applications instead."
  fi
fi

# Without an "Apple Development" identity (no Apple developer account on this Mac), the
# DebugCloud build cannot be signed: fall back to the unsigned Debug build. Permissions
# then have to be granted again after each build, but there is still one Dalil only.
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development"; then
  SCHEME="NotchBuddyCloud"; CONFIG="DebugCloud"; SIGN_FLAGS="-allowProvisioningUpdates"
else
  SCHEME="NotchBuddy"; CONFIG="Debug"; SIGN_FLAGS=""
  echo "No Apple Development identity: building unsigned (Debug)."
fi
BUILT="${DERIVED}/Build/Products/${CONFIG}/Dalil.app"

echo "Building (${CONFIG})..."
cd "${REPO_ROOT}/NotchBuddy"
xcodegen >/dev/null
# shellcheck disable=SC2086
xcodebuild -scheme "${SCHEME}" -configuration "${CONFIG}" ${SIGN_FLAGS} \
  -derivedDataPath "${DERIVED}" -quiet build

echo "Quitting Dalil..."
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5; do pgrep -x Dalil >/dev/null || break; sleep 1; done
pkill -x Dalil 2>/dev/null || true

echo "Installing in ${TARGET}..."
rm -rf "${TARGET}"
ditto "${BUILT}" "${TARGET}"

# The build stays in DerivedData for the next (incremental) build, but macOS must not
# count it as another Coucou. Copies from Xcode's own builds (▶, xcodebuild by hand) go.
"${LSREGISTER}" -u "${BUILT}" >/dev/null 2>&1 || true
for old in "${HOME}"/Library/Developer/Xcode/DerivedData/NotchBuddy-*/Build/Products/*/Dalil.app; do
  [ -d "$old" ] || continue
  "${LSREGISTER}" -u "$old" >/dev/null 2>&1 || true
  rm -rf "$old"
  echo "Removed an old build: $old"
done
"${LSREGISTER}" -f "${TARGET}" >/dev/null 2>&1 || true

open "${TARGET}"
echo "Dalil is running from ${TARGET}."
