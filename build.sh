#!/bin/bash
# Builds build/BongoWaifu.app (release) and ad-hoc signs it.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/BongoWaifu.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/BongoWaifu "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

# Set SIGN_IDENTITY to a real certificate so macOS keeps the Accessibility grant across rebuilds.
codesign --force --sign "${SIGN_IDENTITY:--}" --identifier dev.bongowaifu.app "$APP"
echo "Built $APP"
