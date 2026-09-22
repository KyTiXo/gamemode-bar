import AppKit
import GameModeCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
	private static let activateOnLaunchKey = "activateOnLaunch"

	private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
	private let menu = NSMenu()
	private let settingsMenu = NSMenu()
	private let versionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
	private let runAtStartupItem = NSMenuItem(
		title: "Run at startup",
		action: #selector(toggleRunAtStartup),
		keyEquivalent: ""
	)
	private let activateOnLaunchItem = NSMenuItem(
		title: "Activate on launch",
		action: #selector(toggleActivateOnLaunch),
		keyEquivalent: ""
	)
	private let permissionsItem = NSMenuItem(
		title: "Check Permissions…",
		action: #selector(checkPermissions),
		keyEquivalent: ""
	)
	private let settingsItem = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: "")
	private let toggleItem = NSMenuItem(
		title: "Enable Game Mode+",
		action: #selector(toggleAll),
		keyEquivalent: ""
	)
	private let gameItem = NSMenuItem(title: "Game Mode", action: #selector(toggleGame), keyEquivalent: "")
	private let airDropItem = NSMenuItem(
		title: "No AirDrop (AWDL)",
		action: #selector(toggleAirDrop),
		keyEquivalent: ""
	)
	private let quitItem = NSMenuItem(
		title: "Quit Game Mode Bar",
		action: #selector(terminate),
		keyEquivalent: "q"
	)

	private let session = PolicySession()
	private var busy = false
	private var timer: Timer?
	private var lastState: SystemState?
	private var lastPrerequisites: Prerequisites?
	private var pendingLaunchActivation = true

	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.accessory)
		if #available(macOS 13.0, *) {
			statusItem.isVisible = true
		}
		applyStatusIcon(mode: .off)
		statusItem.button?.toolTip = "Game Mode Bar"
		permissionsItem.target = self
		runAtStartupItem.target = self
		activateOnLaunchItem.target = self
		toggleItem.target = self
		gameItem.target = self
		airDropItem.target = self
		quitItem.target = self

		versionItem.isEnabled = false
		versionItem.title = "Version \(Self.appVersion)"

		settingsMenu.addItem(versionItem)
		settingsMenu.addItem(.separator())
		settingsMenu.addItem(runAtStartupItem)
		settingsMenu.addItem(activateOnLaunchItem)
		settingsMenu.addItem(.separator())
		settingsMenu.addItem(permissionsItem)
		refreshSettingsCheckmarks()

		settingsItem.submenu = settingsMenu
		settingsItem.image = StatusMenu.menuSymbol("gearshape")
		quitItem.image = StatusMenu.menuSymbol("minus.square")

		menu.delegate = self
		menu.addItem(toggleItem)
		menu.addItem(.separator())
		menu.addItem(gameItem)
		menu.addItem(airDropItem)
		menu.addItem(.separator())
		menu.addItem(settingsItem)
		menu.addItem(.separator())
		menu.addItem(quitItem)
		statusItem.menu = menu
		refresh(reportErrors: true)
		timer = .scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
			self?.refresh(reportErrors: false)
		}
	}

	func menuWillOpen(_ menu: NSMenu) {
		refreshSettingsCheckmarks()
		refresh(reportErrors: false)
	}

	@objc private func toggleRunAtStartup() {
		let service = SMAppService.mainApp
		do {
			if service.status == .enabled {
				try service.unregister()
			} else if service.status != .requiresApproval {
				try service.register()
			}
		} catch {
			let alert = NSAlert()
			alert.alertStyle = .warning
			alert.messageText = "Could not update login item"
			alert.informativeText = error.localizedDescription
			NSApp.activate(ignoringOtherApps: true)
			alert.runModal()
		}
		refreshSettingsCheckmarks()
		if SMAppService.mainApp.status == .requiresApproval {
			let alert = NSAlert()
			alert.alertStyle = .informational
			alert.messageText = "Login item needs approval"
			alert.informativeText =
				"macOS must allow Game Mode Bar under Login Items before it can start at login."
			alert.addButton(withTitle: "Open Login Items Settings")
			alert.addButton(withTitle: "Not Now")
			NSApp.activate(ignoringOtherApps: true)
			if alert.runModal() == .alertFirstButtonReturn {
				SMAppService.openSystemSettingsLoginItems()
			}
		}
	}

	@objc private func toggleActivateOnLaunch() {
		let next = !UserDefaults.standard.bool(forKey: Self.activateOnLaunchKey)
		UserDefaults.standard.set(next, forKey: Self.activateOnLaunchKey)
		refreshSettingsCheckmarks()
	}

	private func refreshSettingsCheckmarks() {
		runAtStartupItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
		activateOnLaunchItem.state =
			UserDefaults.standard.bool(forKey: Self.activateOnLaunchKey) ? .on : .off
	}

	@objc private func terminate() {
		NSApp.terminate(nil)
	}

	@objc private func checkPermissions() {
		guard let prereq = lastPrerequisites else { return }
		PermissionsPrompt.presentCheckPermissions(prerequisites: prereq) { [weak self] in
			self?.runSetup(reportErrors: true)
		}
	}

	@objc private func toggleAll() {
		runToggle(requireAuth: true)
	}

	@objc private func toggleGame() {
		guard let state = lastState, state.xcode.available else { return }
		let next: GamePolicy = state.gameModeChecked ? .auto : .on
		runSetGame(next)
	}

	@objc private func toggleAirDrop() {
		guard let state = lastState else { return }
		let next: AwdlState = state.noAirDropChecked ? .up : .down
		runSetAwdl(next, requireAuth: true)
	}

	private func runToggle(requireAuth: Bool) {
		guard !busy else { return }
		setBusy(true)
		Task {
			let response = await session.toggle(requireAuthorization: requireAuth)
			await MainActor.run {
				if response.needsAuthorization == true, requireAuth {
					authorizeThenToggle()
				} else {
					finish(response, reportErrors: true)
				}
			}
		}
	}

	private func runSetGame(_ mode: GamePolicy) {
		guard !busy else { return }
		setBusy(true)
		Task {
			let response = await session.setGame(mode)
			await MainActor.run {
				finish(response, reportErrors: true)
			}
		}
	}

	private func runSetAwdl(_ mode: AwdlState, requireAuth: Bool) {
		guard !busy else { return }
		setBusy(true)
		Task {
			let response = await session.setAwdl(mode, requireAuthorization: requireAuth)
			await MainActor.run {
				if response.needsAuthorization == true, requireAuth {
					authorizeThenSetAwdl(mode)
				} else {
					finish(response, reportErrors: true)
				}
			}
		}
	}

	private func runSetup(reportErrors: Bool) {
		guard !busy else { return }
		setBusy(true)
		Task {
			let response = await session.setup()
			await MainActor.run {
				finish(response, reportErrors: reportErrors)
			}
		}
	}

	private func authorizeThenToggle() {
		guard PermissionsPrompt.confirmAwdlAuthorization() else {
			setBusy(false)
			return
		}
		Task {
			let setup = await session.setup()
			guard setup.ok else {
				await MainActor.run { finish(setup, reportErrors: true) }
				return
			}
			let result = await session.toggle(requireAuthorization: false)
			await MainActor.run { finish(result, reportErrors: true) }
		}
	}

	private func authorizeThenSetAwdl(_ mode: AwdlState) {
		guard PermissionsPrompt.confirmAwdlAuthorization() else {
			setBusy(false)
			return
		}
		Task {
			let setup = await session.setup()
			guard setup.ok else {
				await MainActor.run { finish(setup, reportErrors: true) }
				return
			}
			let result = await session.setAwdl(mode, requireAuthorization: false)
			await MainActor.run { finish(result, reportErrors: true) }
		}
	}

	private func refresh(reportErrors: Bool) {
		guard !busy else { return }
		setBusy(true)
		Task {
			let response = await session.status()
			await MainActor.run {
				finish(response, reportErrors: reportErrors)
			}
		}
	}

	private func setBusy(_ value: Bool) {
		busy = value
		permissionsItem.isEnabled = !value
		toggleItem.isEnabled = !value
		gameItem.isEnabled = !value && (lastState?.xcode.available ?? false)
		airDropItem.isEnabled = !value
		// Quit stays enabled so a stuck subprocess cannot trap the user.
	}

	private static var appVersion: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
	}

	private func applyStatusIcon(mode: StatusIconMode) {
		let image = StatusMenu.statusImage(mode: mode)
		statusItem.button?.image = image
		statusItem.button?.image?.isTemplate = true
		statusItem.button?.title = image == nil ? "GM" : ""
	}

	private func applyResponseState(_ response: ActionResult) {
		if let prereq = response.prerequisites {
			lastPrerequisites = prereq
		}
		if let state = response.state {
			lastState = state
			StatusMenu.updateFeatureRows(
				gameItem: gameItem,
				airDropItem: airDropItem,
				state: state
			)
			gameItem.isEnabled = !busy && state.xcode.available
			gameItem.toolTip = state.xcode.available ? state.detail : state.xcode.reason
			airDropItem.toolTip = state.detail
			toggleItem.title = StatusMenu.masterToggleTitle(for: state)
			applyStatusIcon(mode: StatusMenu.iconMode(for: state))
			statusItem.button?.toolTip = state.detail
		} else {
			lastState = nil
			StatusMenu.updateFeatureRows(gameItem: gameItem, airDropItem: airDropItem, state: nil)
			gameItem.isEnabled = false
			toggleItem.title = StatusMenu.masterToggleTitle(for: nil)
			applyStatusIcon(mode: .error)
			statusItem.button?.toolTip = "Game Mode Bar state unavailable"
		}
	}

	private func activateGameModePlusIfNeeded(from state: SystemState) {
		if !state.gameModeChecked && state.xcode.available {
			setBusy(true)
			Task {
				let response = await session.setGame(.on)
				await MainActor.run {
					finish(response, reportErrors: false)
					activateAwdlIfNeeded()
				}
			}
			return
		}
		activateAwdlIfNeeded()
	}

	private func activateAwdlIfNeeded() {
		guard let state = lastState, !state.noAirDropChecked else { return }
		guard lastPrerequisites?.awdlAuth.ok == true else { return }
		setBusy(true)
		Task {
			let response = await session.setAwdl(.down, requireAuthorization: false)
			await MainActor.run {
				finish(response, reportErrors: false)
			}
		}
	}

	private func finish(_ response: ActionResult, reportErrors: Bool) {
		applyResponseState(response)
		setBusy(false)
		if reportErrors {
			if let warnings = response.warnings, !warnings.isEmpty {
				let alert = NSAlert()
				alert.alertStyle = .informational
				alert.messageText = "Game Mode Bar finished with a warning"
				alert.informativeText = warnings.joined(separator: "\n")
				NSApp.activate(ignoringOtherApps: true)
				alert.runModal()
			} else if !response.ok {
				let alert = NSAlert()
				alert.alertStyle = .warning
				alert.messageText = response.message ?? "Game Mode Bar failed."
				alert.informativeText =
					response.detail ?? response.state?.detail ?? "The current state was re-read."
				NSApp.activate(ignoringOtherApps: true)
				alert.runModal()
			}
		}
		guard pendingLaunchActivation else { return }
		pendingLaunchActivation = false
		guard response.ok,
			let state = lastState,
			UserDefaults.standard.bool(forKey: Self.activateOnLaunchKey)
		else { return }
		activateGameModePlusIfNeeded(from: state)
	}
}
