import AppKit
import Foundation

private struct XcodeProbe: Decodable {
    let available: Bool
    let reason: String
}

private struct ModeState: Decodable {
    let awdl: String
    let detail: String
    let gameModeChecked: Bool
    let noAirDropChecked: Bool
    let xcode: XcodeProbe
}

private struct XcodePrerequisite: Decodable {
    let action: String?
    let ok: Bool
    let reason: String
}

private struct AwdlPrerequisite: Decodable {
    let action: String?
    let ok: Bool
}

private struct Prerequisites: Decodable {
    let awdlAuth: AwdlPrerequisite
    let xcode: XcodePrerequisite
}

private struct ControllerResponse: Decodable {
    let authorization: Bool?
    let detail: String?
    let message: String?
    let needsAuthorization: Bool?
    let ok: Bool
    let prerequisites: Prerequisites?
    let state: ModeState?
    let warnings: [String]?
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let xcodeAppStoreURL = URL(string: "macappstore://apps.apple.com/app/xcode/id497799835")!

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let settingsMenu = NSMenu()
    private let versionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let permissionsItem = NSMenuItem(title: "Check Permissions…", action: #selector(checkPermissions), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Toggle → ON", action: #selector(toggleAll), keyEquivalent: "")
    private let gameItem = NSMenuItem(title: "Game Mode", action: #selector(toggleGame), keyEquivalent: "")
    private let airDropItem = NSMenuItem(title: "No AirDrop (AWDL)", action: #selector(toggleAirDrop), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit Game Mode Bar", action: #selector(terminate), keyEquivalent: "q")
    private var busy = false
    private var timer: Timer?
    private var lastState: ModeState?
    private var lastPrerequisites: Prerequisites?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if #available(macOS 13.0, *) {
            statusItem.isVisible = true
        }
        applyStatusIcon(mode: .off)
        statusItem.button?.toolTip = "Game Mode Bar"
        permissionsItem.target = self
        toggleItem.target = self
        gameItem.target = self
        airDropItem.target = self
        quitItem.target = self

        versionItem.isEnabled = false
        versionItem.title = "Version \(Self.appVersion)"

        settingsMenu.addItem(versionItem)
        settingsMenu.addItem(.separator())
        settingsMenu.addItem(permissionsItem)

        settingsItem.submenu = settingsMenu
        settingsItem.image = Self.menuSymbol("gearshape")
        quitItem.image = Self.menuSymbol("minus.square")

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
        refresh(reportErrors: false)
    }

    @objc private func terminate() {
        NSApp.terminate(nil)
    }

    @objc private func checkPermissions() {
        guard let prereq = lastPrerequisites else { return }
        let xcodeOk = prereq.xcode.ok
        let awdlOk = prereq.awdlAuth.ok

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
            lines.append("Game Mode: \(prereq.xcode.reason)")
        }
        if awdlOk {
            lines.append("No AirDrop: ready.")
        } else {
            lines.append("No AirDrop: one-time sudoers authorization required for ifconfig awdl0 up/down.")
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
            let authAlert = NSAlert()
            authAlert.alertStyle = .informational
            authAlert.messageText = "One-time AWDL authorization"
            authAlert.informativeText = "Game Mode Bar installs one exact root:wheel 0440 sudoers rule, validated by visudo, that only permits awdl0 up/down. Password entry is handled by macOS and is never read or stored by this app."
            authAlert.addButton(withTitle: "Authorize")
            authAlert.addButton(withTitle: "Cancel")
            guard authAlert.runModal() == .alertFirstButtonReturn else { return }
            execute("setup") { [weak self] response in
                self?.finish(response, reportErrors: true)
            }
            return
        }
        if !xcodeOk {
            let xcodeButton: NSApplication.ModalResponse =
                awdlOk ? .alertFirstButtonReturn : .alertSecondButtonReturn
            if choice == xcodeButton {
                NSWorkspace.shared.open(Self.xcodeAppStoreURL)
            }
        }
    }

    @objc private func toggleAll() {
        runCommand("toggle", needsAuth: true)
    }

    @objc private func toggleGame() {
        guard let state = lastState, state.xcode.available else { return }
        let next = state.gameModeChecked ? "auto" : "on"
        runCommand("set-game \(next)", needsAuth: false)
    }

    @objc private func toggleAirDrop() {
        guard let state = lastState else { return }
        let next = state.noAirDropChecked ? "up" : "down"
        runCommand("set-awdl \(next)", needsAuth: true)
    }

    private func runCommand(_ command: String, needsAuth: Bool) {
        guard !busy else { return }
        execute(command) { [weak self] response in
            guard let self else { return }
            if response.needsAuthorization == true, needsAuth {
                authorizeThen(command: command)
            } else {
                finish(response, reportErrors: true)
            }
        }
    }

    private func authorizeThen(command: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "One-time AWDL authorization"
        alert.informativeText = "Game Mode Bar installs one exact root:wheel 0440 sudoers rule, validated by visudo, that only permits awdl0 up/down. Password entry is handled by macOS and is never read or stored by this app."
        alert.addButton(withTitle: "Authorize")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            setBusy(false)
            return
        }
        execute("setup") { [weak self] response in
            guard let self else { return }
            guard response.ok else {
                finish(response, reportErrors: true)
                return
            }
            execute(command) { [weak self] result in
                self?.finish(result, reportErrors: true)
            }
        }
    }

    private func refresh(reportErrors: Bool) {
        guard !busy else { return }
        execute("status") { [weak self] response in
            self?.finish(response, reportErrors: reportErrors)
        }
    }

    private func setBusy(_ value: Bool) {
        busy = value
        permissionsItem.isEnabled = !value
        toggleItem.isEnabled = !value
        gameItem.isEnabled = !value && (lastState?.xcode.available ?? false)
        airDropItem.isEnabled = !value
        settingsItem.isEnabled = !value
        quitItem.isEnabled = !value
    }

    private func execute(_ command: String, completion: @escaping (ControllerResponse) -> Void) {
        setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let response = Self.runController(command)
            DispatchQueue.main.async {
                completion(response)
            }
        }
    }

    private static func runController(_ command: String) -> ControllerResponse {
        let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
        let verb = parts[0]
        let argument = parts.count > 1 ? parts[1] : nil
        let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        let directory = executable.deletingLastPathComponent()
        let bundledController = directory.deletingLastPathComponent().appendingPathComponent("Resources/controller.js")
        let controller = FileManager.default.fileExists(atPath: bundledController.path)
            ? bundledController
            : directory.appendingPathComponent("controller.js")
        let environmentBun = ProcessInfo.processInfo.environment["GAME_MODE_BAR_BUN"].map(URL.init(fileURLWithPath:))
        let bun = [
            environmentBun,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".bun/bin/bun"),
            URL(fileURLWithPath: "/opt/homebrew/bin/bun"),
            URL(fileURLWithPath: "/usr/local/bin/bun")
        ]
        .compactMap { $0 }
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }
        var arguments = [controller.path, verb]
        if let argument {
            for piece in argument.split(separator: " ") {
                arguments.append(String(piece))
            }
        }
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        if let bun {
            process.executableURL = bun
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["bun"] + arguments
        }
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
            process.waitUntilExit()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return try JSONDecoder().decode(ControllerResponse.self, from: data)
        } catch {
            let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return ControllerResponse(
                authorization: nil,
                detail: [error.localizedDescription, stderr].filter { !$0.isEmpty }.joined(separator: " "),
                message: "Game Mode Bar controller failed.",
                needsAuthorization: nil,
                ok: false,
                prerequisites: nil,
                state: nil,
                warnings: nil
            )
        }
    }

    private enum IconMode {
        case off
        case on
        case error
    }

    private static func statusSymbolName(mode: IconMode) -> String {
        switch mode {
        case .off:
            return "gamecontroller"
        case .on:
            return "gamecontroller.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private static func statusImage(mode: IconMode) -> NSImage? {
        let image = NSImage(
            systemSymbolName: statusSymbolName(mode: mode),
            accessibilityDescription: "Game Mode Bar"
        )
        image?.isTemplate = true
        return image
    }

    private static func menuSymbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Shared tab stop so **On** / **Off** line up on the trailing edge of the menu.
    private static let featureStatusTabLocation: CGFloat = 196

    private static func featureRowAttributedTitle(label: String, on: Bool) -> NSAttributedString {
        let status = on ? "On" : "Off"
        let string = "\(label)\t\(status)"
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [
            NSTextTab(textAlignment: .right, location: featureStatusTabLocation, options: [:]),
        ]
        let font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
        let attributed = NSMutableAttributedString(
            string: string,
            attributes: [
                .font: font,
                .paragraphStyle: paragraph,
                .foregroundColor: NSColor.labelColor,
            ]
        )
        let statusRange = (string as NSString).range(of: status)
        attributed.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: statusRange)
        return attributed
    }

    private func applyFeatureRow(_ item: NSMenuItem, label: String, on: Bool) {
        let status = on ? "On" : "Off"
        item.title = "\(label), \(status)"
        item.attributedTitle = Self.featureRowAttributedTitle(label: label, on: on)
    }

    private func updateFeatureRows(from state: ModeState?) {
        guard let state else {
            applyFeatureRow(gameItem, label: "Game Mode", on: false)
            applyFeatureRow(airDropItem, label: "No AirDrop (AWDL)", on: false)
            return
        }
        applyFeatureRow(gameItem, label: "Game Mode", on: state.gameModeChecked)
        applyFeatureRow(airDropItem, label: "No AirDrop (AWDL)", on: state.noAirDropChecked)
    }

    private func updateToggleTitle(from state: ModeState?) {
        guard let state else {
            toggleItem.title = "Toggle Mode"
            return
        }
        let anyOn = state.gameModeChecked || state.noAirDropChecked
        toggleItem.title = anyOn ? "Toggle → OFF" : "Toggle → ON"
    }

    private func applyStatusIcon(mode: IconMode) {
        let image = Self.statusImage(mode: mode)
        statusItem.button?.image = image
        statusItem.button?.image?.isTemplate = true
        // Fallback if SF Symbols fail to load (blank menu bar otherwise).
        statusItem.button?.title = image == nil ? "GM" : ""
    }

    private func finish(_ response: ControllerResponse, reportErrors: Bool) {
        if let prereq = response.prerequisites {
            lastPrerequisites = prereq
        }
        if let state = response.state {
            lastState = state
            updateFeatureRows(from: state)
            gameItem.isEnabled = !busy && state.xcode.available
            gameItem.toolTip = state.xcode.available ? state.detail : state.xcode.reason
            airDropItem.toolTip = state.detail
            let anyOn = state.gameModeChecked || state.noAirDropChecked
            updateToggleTitle(from: state)
            applyStatusIcon(mode: anyOn ? .on : .off)
            statusItem.button?.toolTip = state.detail
        } else {
            lastState = nil
            updateFeatureRows(from: nil)
            gameItem.isEnabled = false
            updateToggleTitle(from: nil)
            applyStatusIcon(mode: .error)
            statusItem.button?.toolTip = "Game Mode Bar state unavailable"
        }
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
                alert.informativeText = response.detail ?? response.state?.detail ?? "The current state was re-read."
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
