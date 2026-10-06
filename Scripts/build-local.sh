#!/bin/bash
# Opcjonalnie: zbuduj Kafelek u siebie (potrzebny Xcode + Homebrew). Normalnie nie trzeba – GitHub buduje sam.
# Użycie:  ./Scripts/build-local.sh            (podpis lokalny – działa zawsze, nic nie wygasa)
#          TEAM=ABCDE12345 ./Scripts/build-local.sh   (podpis Twoim Apple ID z Xcode – też nie wygasa na macOS)
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate

SIGN=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
if [ -n "${TEAM:-}" ]; then
  SIGN=(CODE_SIGN_IDENTITY="Apple Development" CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM" -allowProvisioningUpdates)
fi

xcodebuild -project Kafelek.xcodeproj -scheme Kafelek -configuration Release \
  -derivedDataPath build -destination 'generic/platform=macOS' \
  "${SIGN[@]}" -quiet build

pkill -x Kafelek 2>/dev/null || true
sleep 1
rm -rf /Applications/Kafelek.app
cp -R build/Build/Products/Release/Kafelek.app /Applications/
open /Applications/Kafelek.app
echo "✅ Zainstalowano /Applications/Kafelek.app"
