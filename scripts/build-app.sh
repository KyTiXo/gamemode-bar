#!/usr/bin/env sh
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --arch arm64 --product GameModeBar

BUILD_DIR="$ROOT/.build/arm64-apple-macosx/release"
if [ ! -f "$BUILD_DIR/GameModeBar" ]; then
	BUILD_DIR="$ROOT/.build/release"
fi

APP="$ROOT/build/Game Mode Bar.app"
DEBUG_ICONSET="$ROOT/build/debug/AppIcon.iconset"
ICON_SRC="$ROOT/Packaging/icon.png"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
cp "$BUILD_DIR/GameModeBar" "$APP/Contents/MacOS/GameModeBar"

mkdir -p "$DEBUG_ICONSET"
SIPS=/usr/bin/sips
$SIPS -z 16 16 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_16x16.png"
$SIPS -z 32 32 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_16x16@2x.png"
$SIPS -z 32 32 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_32x32.png"
$SIPS -z 64 64 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_32x32@2x.png"
$SIPS -z 128 128 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_128x128.png"
$SIPS -z 256 256 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_128x128@2x.png"
$SIPS -z 256 256 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_256x256.png"
$SIPS -z 512 512 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_256x256@2x.png"
$SIPS -z 512 512 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_512x512.png"
$SIPS -z 1024 1024 "$ICON_SRC" --out "$DEBUG_ICONSET/icon_512x512@2x.png"

iconutil -c icns "$DEBUG_ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

/usr/bin/codesign --force --sign - "$APP"
echo "Built $APP"
