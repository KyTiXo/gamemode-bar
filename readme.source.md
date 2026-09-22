![Game Mode Bar, menu-bar Game Mode for play, emulators, and AirPlay](./.github/assets/readme-banner.png)

Native macOS menu-bar app. No Electron. **Toggle → ON/OFF** is the master switch. Individual rows tune **macOS Game Mode** and **No AirDrop** (AWDL down). Open **Settings…** and use **Check Permissions…** for Xcode and sudoers setup.

## Why use it

Apple’s automatic Game Mode is hit-or-miss. It often skips emulators, streamers, and full-screen apps that still need the policy boost. Game Mode Bar forces the same path macOS uses when it _does_ engage Game Mode, from a persistent menu-bar control.

It can help reduce stutter and frame pacing issues when:

- **AirPlaying** video or games to a TV (AWDL traffic fighting the same Wi‑Fi)
- **Emulators and PC/console streaming** (shadPS4, Moonlight, other full-screen play)
- **Apps macOS doesn’t treat as games**, even when you’re on a controller

Results vary by Mac, network, and workload. This is a policy toggle, not a magic FPS patch.

## Requirements

The app checks these for you. Use **Settings → Check Permissions…** to fix gaps.

```aura width=860 height=140
<div style={{
  width: '100%', height: '100%', background: '#141416',
  display: 'flex', flexDirection: 'column', justifyContent: 'center',
  padding: '0 32px', borderRadius: 14, border: '1px solid rgba(255,255,255,0.07)',
  fontFamily: 'Inter', gap: 8
}}>
  <div style={{ display: 'flex', fontSize: 13, fontWeight: 700, color: '#f5f5f7', letterSpacing: '0.3px' }}>Before you toggle</div>
  <div style={{ display: 'flex', fontSize: 13, color: 'rgba(235,235,245,0.78)', lineHeight: 1.5 }}>
    Full Xcode at /Applications/Xcode.app (not CLT alone). Provides gamepolicyctl.
  </div>
  <div style={{ display: 'flex', fontSize: 13, color: 'rgba(235,235,245,0.78)', lineHeight: 1.5 }}>
    One-time sudoers for passwordless ifconfig awdl0 up/down (No AirDrop).
  </div>
</div>
```

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

- Conventional Commits on `main`. Maintainers tag `v0.x.y` when a beta binary is ready.
- CI builds an unsigned ad-hoc `.app` zip attached to GitHub **prereleases**.
- Not at 1.0 yet.

## Install

Homebrew (beta, in-repo tap):

```sh
brew tap KyTiXo/gamemode-bar https://github.com/KyTiXo/gamemode-bar.git
brew install --cask gamemode-bar
```

Requires [Bun](https://bun.sh) (pulled in by the cask). Full Xcode and one-time sudoers setup still apply — use **Settings → Check Permissions…** after install.

Or download the latest prerelease zip from [GitHub Releases](https://github.com/KyTiXo/gamemode-bar/releases).

MIT. See [LICENSE](LICENSE).
