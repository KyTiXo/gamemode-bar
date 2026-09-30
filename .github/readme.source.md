![Game Mode Bar, menu-bar Game Mode for play, emulators, and AirPlay](./.github/assets/readme-banner.png)

<p align="center"><b><a href="https://kytixo.github.io/gamemode-bar/">Website</a></b> · <a href="https://kytixo.github.io/gamemode-bar/#install">Install</a> · <a href="https://github.com/KyTiXo/gamemode-bar/releases">Releases</a></p>

A native macOS menu-bar toggle that **forces macOS Game Mode on apps it doesn't recognize as games** (emulators, streaming clients, anything full-screen) and **keeps AirDrop's radio (AWDL) off** while you play. One click, **Enable Game Mode+**, turns on both. Click it again to put everything back.

## Quick start

```sh
# Quick install
curl -fsSL https://kytixo.github.io/gamemode-bar/install.sh | sh

# Homebrew
brew tap KyTiXo/gamemode-bar https://github.com/KyTiXo/gamemode-bar.git
brew install --cask gamemode-bar
```

Then **Settings… → Check Permissions…** for the one-time setup below.

## Why use it

macOS only turns on Game Mode for apps tagged as games. shadPS4, Moonlight, and most emulators aren't, so they miss out even when they're full-screen on a controller. Game Mode Bar turns it on for any app, from the menu bar.

**No AirDrop** takes down `awdl0`, the peer-to-peer link behind AirDrop and AirPlay. It hops Wi‑Fi channels in the background, which causes periodic stutter and latency spikes when you're streaming or AirPlaying. macOS brings it back up on its own, so Game Mode Bar puts it back down for as long as No AirDrop is on.

It helps most with:

- **Emulators** like shadPS4 (Bloodborne, anyone?)
- **Game streaming** with Moonlight, GeForce NOW, Parsec, Steam Link
- **AirPlaying** games or video to a TV

Results vary by Mac, network, and workload. This is a policy toggle, not an FPS patch.

### Why not just `sudo ifconfig awdl0 down`?

You can. macOS turns it back on within minutes, and you have to remember to turn it back on for AirDrop. Game Mode Bar keeps it down while you play and restores it when you're done, with no password prompt each time.

## Requirements

- **Apple Silicon, macOS 14+.**
- **Full Xcode** for the Game Mode row. Apple only ships `gamepolicyctl` with Xcode, not the Command Line Tools. Without Xcode, the Game Mode row is disabled, but **No AirDrop works without it.**
- **One sudoers rule** so AWDL can be toggled without a password prompt. **Check Permissions…** installs it after macOS asks for your admin password once, validated by `visudo`. This is the whole rule:

  ```
  <you> ALL=(root) NOPASSWD: /sbin/ifconfig awdl0 down, /sbin/ifconfig awdl0 up
  ```

  Nothing else runs as root. Delete `/etc/sudoers.d/gamemode-bar-awdl` to remove it.

Beta builds are ad-hoc signed, not notarized. On first launch, right-click the app and choose **Open**.

## Develop

```sh
scripts/check.sh              # swift test
scripts/build-app.sh          # build/Game Mode Bar.app
scripts/install-local.sh      # rebuild, quit, relaunch
```

Override tool paths with `GAME_MODE_BAR_*` env vars (see `Sources/GameModeCore/Types.swift`).

Releases: bump `CFBundleShortVersionString` and `CFBundleVersion` in `Packaging/Info.plist`, tag `v0.x.y`, push the tag. CI builds the `.app` zip as a GitHub prerelease and bumps the Homebrew cask.

MIT. See [LICENSE](LICENSE). [Contributing](CONTRIBUTING.md) · [Security](.github/SECURITY.md) · [Agents](AGENTS.md)
