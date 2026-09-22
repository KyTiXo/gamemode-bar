#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
swift test
swift build --product GameModeBar
