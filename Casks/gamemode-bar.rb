cask "gamemode-bar" do
  version "0.2.2"
  sha256 "cc3a45907c79e0ce1467562ac49ed9641faaf6821fea05c1b52fd8008b0d0893"

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
