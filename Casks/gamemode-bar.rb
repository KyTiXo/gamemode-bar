cask "gamemode-bar" do
  version "0.2.4"
  sha256 "30df84083fcb66505b1e1f4b51a84e0665432ba75a3f3496750ec8f9e46a229d"

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
