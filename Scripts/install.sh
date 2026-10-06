#!/bin/bash
# Instalator / aktualizator Kafelka.
# Użycie:  curl -fsSL https://github.com/amadeo987/kafelek/releases/latest/download/install.sh | bash
set -euo pipefail

REPO="amadeo987/kafelek"
URL="https://github.com/${REPO}/releases/latest/download/Kafelek.zip"
DEST="/Applications/Kafelek.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "⬇️  Pobieram najnowszy Kafelek…"
curl -fL --progress-bar "$URL" -o "$TMP/Kafelek.zip"

echo "📦 Rozpakowuję…"
ditto -x -k "$TMP/Kafelek.zip" "$TMP"

if pgrep -x Kafelek >/dev/null 2>&1; then
  echo "⏹  Zamykam działający Kafelek…"
  pkill -x Kafelek || true
  sleep 1
fi

echo "📁 Kopiuję do /Applications…"
if [ -w /Applications ]; then
  rm -rf "$DEST"
  mv "$TMP/Kafelek.app" "$DEST"
else
  sudo rm -rf "$DEST"
  sudo mv "$TMP/Kafelek.app" "$DEST"
fi

# Pobrane przez curl nie ma kwarantanny, ale na wszelki wypadek:
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# Zarejestruj rozszerzenie widżetu w systemie.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" >/dev/null 2>&1 || true

echo "🚀 Uruchamiam…"
open "$DEST"
echo "✅ Gotowe! Ikonka Kafelka jest na pasku menu (▦)."
echo "   Widżety: prawy klik na tapecie → Edytuj widżety → wyszukaj „Kafelek”."
