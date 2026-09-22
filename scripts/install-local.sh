#!/usr/bin/env sh
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Game Mode Bar.app"
BUNDLE_ID="dev.kytix.gamemode-bar"

"$ROOT/scripts/build-app.sh"

osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null || true
pkill -x GameModeBar 2>/dev/null || true
sleep 0.4

open -a "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true

echo "Installed and launched $APP"
