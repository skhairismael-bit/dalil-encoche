#!/bin/bash
# render-dalil.sh — compile and run the Dalil look bench (choice of the character)
# NOT in CI. Run manually: bash scripts/render-dalil.sh [output dir]
set -e
cd "$(dirname "$0")/.."
OUT="${1:-/tmp/dalil-looks}"
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -parse-as-library -sdk "$SDK" -target arm64-apple-macosx15.0 \
  NotchBuddy/Sources/CoucouKit/IslandScreenGeometry.swift \
  NotchBuddy/Sources/CoucouKit/IslandTypes.swift \
  NotchBuddy/Sources/CoucouKit/MochiWardrobe.swift \
  NotchBuddy/Sources/CoucouKit/MochiMood.swift \
  NotchBuddy/Sources/CoucouKit/DalilLook.swift \
  NotchBuddy/Sources/CoucouKit/BotEngine.swift \
  NotchBuddy/Sources/CoucouKit/MochiOutfitDrawing.swift \
  scripts/RenderDalil.swift \
  -framework AppKit -framework SwiftUI -o /tmp/dalil-render
/tmp/dalil-render "$OUT"
