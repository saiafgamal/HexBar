#!/bin/zsh
# Builds HexBar.app into /Applications. Build products stay out of the source folder.
set -euo pipefail
cd "$(dirname "$0")/.."
SCRATCH="$HOME/Library/Caches/HexBar-build"
APP="/Applications/HexBar.app"
# Command Line Tools lack the SwiftUI macro plugin; use full Xcode.
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  for x in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    [[ -d "$x" ]] && export DEVELOPER_DIR="$x/Contents/Developer" && break
  done
fi

swift build -c release --scratch-path "$SCRATCH"

pkill -x HexBar 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SCRATCH/release/HexBar" "$APP/Contents/MacOS/HexBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/ReadexPro.ttf Resources/ReadexPro-OFL.txt Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
open "$APP"
echo "Installed $APP"
