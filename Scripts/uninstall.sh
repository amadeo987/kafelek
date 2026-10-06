#!/bin/bash
# Odinstalowanie Kafelka.
#   curl -fsSL https://github.com/amadeo987/kafelek/releases/latest/download/uninstall.sh | bash          (zostawia Twoje widżety)
#   curl -fsSL https://github.com/amadeo987/kafelek/releases/latest/download/uninstall.sh | bash -s -- --all   (kasuje też widżety i zdjęcia)
set -u
pkill -x Kafelek 2>/dev/null || true
sleep 1
rm -rf /Applications/Kafelek.app 2>/dev/null || sudo rm -rf /Applications/Kafelek.app
rm -rf "$HOME/Library/Containers/pl.amadeo.kafelek.widget" 2>/dev/null || true
if [ "${1:-}" = "--all" ]; then
  rm -rf "$HOME/Library/Application Support/Kafelek"
  echo "🗑  Usunięto aplikację i wszystkie widżety."
else
  echo "🗑  Usunięto aplikację. Twoje widżety zostały w ~/Library/Application Support/Kafelek (wrócą po ponownej instalacji)."
fi
