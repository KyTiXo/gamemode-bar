#!/bin/sh
set -eu

if [ "$(uname -m)" != "arm64" ]; then
	echo "Game Mode Bar requires Apple Silicon (arm64)."
	exit 1
fi

REPO="KyTiXo/gamemode-bar"
API="https://api.github.com/repos/${REPO}/releases"

RELEASE_JSON="$(curl -fsSL "$API")"
TAG="$(printf '%s' "$RELEASE_JSON" | python3 -c '
import json, sys
releases = json.load(sys.stdin)
for r in releases:
    for a in r.get("assets", []):
        if a.get("name", "").startswith("Game-Mode-Bar-v") and a["name"].endswith(".zip"):
            print(r["tag_name"])
            raise SystemExit(0)
sys.exit(1)
')"

ZIP_NAME="Game-Mode-Bar-${TAG}.zip"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${ZIP_NAME}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

curl -fsSL "$DOWNLOAD_URL" -o "$WORKDIR/Game-Mode-Bar.zip"
ditto -x -k "$WORKDIR/Game-Mode-Bar.zip" "$WORKDIR"

if [ -w /Applications ]; then
	DEST="/Applications"
else
	DEST="$HOME/Applications"
	mkdir -p "$DEST"
fi

rm -rf "$DEST/Game Mode Bar.app"
ditto "$WORKDIR/Game Mode Bar.app" "$DEST/Game Mode Bar.app"

echo "Installed Game Mode Bar to $DEST/Game Mode Bar.app"

if test -x /Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl; then
	echo "Xcode (gamepolicyctl): installed"
else
	echo "Xcode (gamepolicyctl): missing"
fi

if test -f /etc/sudoers.d/gamemode-bar-awdl; then
	echo "No AirDrop sudoers: installed"
else
	echo "No AirDrop sudoers: missing"
	echo "Open Game Mode Bar and use Settings → Check Permissions… to authorize No AirDrop."
fi

echo ""
echo "This beta is ad-hoc signed, not notarized. On first open, right-click the app and choose Open."
