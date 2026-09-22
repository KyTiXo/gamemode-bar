![Game Mode Bar, menu-bar Game Mode for play, emulators, and AirPlay](./.github/assets/readme-banner.png)

Native macOS menu-bar app. No Electron. **Toggle → ON/OFF** is the master switch. Individual rows tune **macOS Game Mode** and **No AirDrop** (AWDL down). Open **Settings…** for **Run at startup**, **Activate on launch**, and **Check Permissions…** (Xcode and sudoers setup).

## Quick start

Check prerequisites:

```sh
printf '%s\0%s\0' \
	Bun 'command -v bun' \
	'Xcode (gamepolicyctl)' 'test -x /Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl' \
	'No AirDrop sudoers' 'test -f /etc/sudoers.d/gamemode-bar-awdl' |
	xargs -0 -n2 sh -c 'sh -c "$2" >/dev/null 2>&1 && echo "$1: installed" || echo "$1: missing"' _
```

Homebrew (beta, in-repo tap):

```sh
brew tap KyTiXo/gamemode-bar https://github.com/KyTiXo/gamemode-bar.git
brew install --cask gamemode-bar
```

Requires [Bun](https://bun.sh) (pulled in by the cask). Full Xcode and one-time sudoers setup still apply — use **Settings → Check Permissions…** after install.

Or download the latest prerelease zip from [GitHub Releases](https://github.com/KyTiXo/gamemode-bar/releases). The app is ad-hoc signed, not notarized — on first open, right-click the app in the zip and choose **Open** (or use Homebrew above for a smoother install).

## Why use it

Apple’s automatic Game Mode is hit-or-miss. It often skips emulators, streamers, and full-screen apps that still need the policy boost. Game Mode Bar forces the same path macOS uses when it *does* engage Game Mode, from a persistent menu-bar control.

It can help reduce stutter and frame pacing issues when:

* **AirPlaying** video or games to a TV (AWDL traffic fighting the same Wi‑Fi)
* **Emulators and PC/console streaming** (shadPS4, Moonlight, other full-screen play)
* **Apps macOS doesn’t treat as games**, even when you’re on a controller

Results vary by Mac, network, and workload. This is a policy toggle, not a magic FPS patch.

## Requirements

Full Xcode (not Command Line Tools alone) provides `gamepolicyctl`. One-time sudoers covers passwordless `ifconfig awdl0` up/down. Use **Settings → Check Permissions…** to fix gaps.

## Develop

```sh
bun install
bun run check
bun run build:debug
./build/debug/GameModeBar
bun run build   # Game Mode Bar.app
```

Bun resolves from `GAME_MODE_BAR_BUN`, `~/.bun/bin`, Homebrew, or `PATH`. Override tool paths with `GAME_MODE_BAR_*` env vars (see `src/core.ts`).

## Releases (beta)

* Conventional Commits on `main`. Maintainers tag `v0.x.y` when a beta binary is ready.
* CI builds an ad-hoc signed, not notarized `.app` zip attached to GitHub **prereleases**.
* Not at 1.0 yet.

MIT. See [LICENSE](LICENSE). [Contributing](CONTRIBUTING.md) · [Security](.github/SECURITY.md) · [Agents](AGENTS.md)
