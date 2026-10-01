cask "gamemode-bar" do
  version "0.3.0"
  sha256 "fb11ece3d04d840c521390c7d013261a042a5c4104b3b45c071dcda5a44c9fc4"

  url "https://github.com/KyTiXo/gamemode-bar/releases/download/v#{version}/Game-Mode-Bar-v#{version}.zip"
  name "Game Mode Bar"
  desc "Menu-bar Game Mode for play, emulators, and AirPlay"
  homepage "https://github.com/KyTiXo/gamemode-bar"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Game Mode Bar.app"

  zap trash: "~/Library/Preferences/dev.kytix.gamemode-bar.plist"

  caveats <<~EOS
    Full Xcode at /Applications/Xcode.app is required for macOS Game Mode (gamepolicyctl).

    After install, open Settings → Check Permissions… for No AirDrop sudoers setup.

    This beta is ad-hoc signed; Gatekeeper may prompt on first launch.
  EOS
end
