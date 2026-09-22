![Game Mode Bar, menu-bar Game Mode for play, emulators, and AirPlay](./.github/assets/readme-banner.png)

Native macOS menu-bar app. No Electron. **Toggle → ON/OFF** is the master switch. Individual rows tune **macOS Game Mode** and **No AirDrop** (AWDL down). Open **Settings…** for **Run at startup**, **Activate on launch**, and **Check Permissions…** (Xcode and sudoers setup).

## Quick start

```sh
# Quick install
curl -fsSL https://kytixo.github.io/gamemode-bar/install.sh | sh

# Homebrew
brew tap KyTiXo/gamemode-bar https://github.com/KyTiXo/gamemode-bar.git
brew install --cask gamemode-bar
```

Full Xcode and one-time sudoers setup still apply — use **Settings → Check Permissions…** after install.

## Why use it

Apple’s automatic Game Mode is hit-or-miss. It often skips emulators, streamers, and full-screen apps that still need the policy boost. Game Mode Bar forces the same path macOS uses when it _does_ engage Game Mode, from a persistent menu-bar control.

It can help reduce stutter and frame pacing issues when:

- **AirPlaying** video or games to a TV (AWDL traffic fighting the same Wi‑Fi)
- **Emulators and PC/console streaming** (shadPS4, Moonlight, other full-screen play)
- **Apps macOS doesn’t treat as games**, even when you’re on a controller

Results vary by Mac, network, and workload. This is a policy toggle, not a magic FPS patch.

## Requirements

Full Xcode (not Command Line Tools alone) provides `gamepolicyctl`. One-time sudoers covers passwordless `ifconfig awdl0` up/down. Use **Settings → Check Permissions…** to fix gaps.

## Develop

```sh
swift test
scripts/check.sh
swift build --product GameModeBar
.build/debug/GameModeBar
scripts/build-app.sh   # Game Mode Bar.app
```

Override tool paths with `GAME_MODE_BAR_*` env vars (see `Sources/GameModeCore/Types.swift`).

## Releases (beta)

- Conventional Commits on `main`. Maintainers bump `CFBundleShortVersionString` and `CFBundleVersion` in `Packaging/Info.plist`, tag `v0.x.y`, and push the tag when a beta binary is ready.
- CI builds an ad-hoc signed, not notarized `.app` zip attached to GitHub **prereleases**.
- Not at 1.0 yet.

MIT. See [LICENSE](LICENSE). [Contributing](CONTRIBUTING.md) · [Security](.github/SECURITY.md) · [Agents](AGENTS.md)
