cask "gamemode-bar" do
  version "0.2.3"
  sha256 "cf70743d88932d5767a8949e4a44e92a2e9d2af1a0dfe0d5c8d950c57e8f6cca"

  url "https://github.com/KyTiXo/gamemode-bar/releases/download/v#{version}/Game-Mode-Bar-v#{version}.zip"
  name "Game Mode Bar"
  desc "Menu-bar Game Mode for play, emulators, and AirPlay"
  homepage "https://github.com/KyTiXo/gamemode-bar"

  depends_on arch: :arm64
  depends_on formula: "bun"
  depends_on macos: :sonoma

  app "Game Mode Bar.app"

  zap trash: "~/Library/Preferences/dev.kytix.gamemode-bar.plist"

  caveats <<~EOS
    Full Xcode at /Applications/Xcode.app is required for macOS Game Mode (gamepolicyctl).

    After install, open Settings → Check Permissions… for No AirDrop sudoers setup.

    This beta is ad-hoc signed; Gatekeeper may prompt on first launch.
  EOS
end
