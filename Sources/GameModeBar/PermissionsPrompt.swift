import AppKit
import GameModeCore

enum PermissionsPrompt {
	static let xcodeAppStoreURL = URL(
		string: "macappstore://apps.apple.com/app/xcode/id497799835"
	)!

	static func presentCheckPermissions(
		prerequisites: Prerequisites,
		onAuthorizeAwdl: @escaping () -> Void
	) {
		let xcodeOk = prerequisites.xcode.ok
		let awdlOk = prerequisites.awdlAuth.ok

		let alert = NSAlert()
		alert.alertStyle = .informational
		NSApp.activate(ignoringOtherApps: true)

		if xcodeOk && awdlOk {
			alert.messageText = "Permissions look good"
			alert.informativeText = """
			Game Mode: full Xcode and gamepolicyctl are available.
			No AirDrop: passwordless ifconfig awdl0 up/down is authorized.
			"""
			alert.addButton(withTitle: "OK")
			alert.runModal()
			return
		}

		var lines: [String] = []
		if xcodeOk {
			lines.append("Game Mode: ready.")
		} else {
			lines.append("Game Mode: \(prerequisites.xcode.reason)")
		}
		if awdlOk {
			lines.append("No AirDrop: ready.")
		} else {
			lines.append(
				"No AirDrop: one-time sudoers authorization required for ifconfig awdl0 up/down."
			)
		}
		alert.messageText = "Permissions incomplete"
		alert.informativeText = lines.joined(separator: "\n")

		if !awdlOk {
			alert.addButton(withTitle: "Authorize No AirDrop")
		}
		if !xcodeOk {
			alert.addButton(withTitle: "Open App Store for Xcode")
		}
		alert.addButton(withTitle: "Cancel")

		let choice = alert.runModal()
		if !awdlOk, choice == .alertFirstButtonReturn {
			guard confirmAwdlAuthorization() else { return }
			onAuthorizeAwdl()
			return
		}
		if !xcodeOk {
			let xcodeButton: NSApplication.ModalResponse =
				awdlOk ? .alertFirstButtonReturn : .alertSecondButtonReturn
			if choice == xcodeButton {
				NSWorkspace.shared.open(xcodeAppStoreURL)
			}
		}
	}

	static func confirmAwdlAuthorization() -> Bool {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = "One-time AWDL authorization"
		alert.informativeText =
			"Game Mode Bar installs one exact root:wheel 0440 sudoers rule, validated by visudo, that only permits awdl0 up/down. Password entry is handled by macOS and is never read or stored by this app."
		alert.addButton(withTitle: "Authorize")
		alert.addButton(withTitle: "Cancel")
		NSApp.activate(ignoringOtherApps: true)
		return alert.runModal() == .alertFirstButtonReturn
	}
}
