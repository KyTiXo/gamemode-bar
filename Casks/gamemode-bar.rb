cask "gamemode-bar" do
  version "0.2.2"
  sha256 "6444ea753f9ecb254a63748626420189a60adb9f59287a921b3b4486cd46b789"

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
