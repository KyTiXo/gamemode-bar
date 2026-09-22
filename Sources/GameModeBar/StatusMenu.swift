import AppKit
import GameModeCore

enum StatusIconMode {
	case off
	case on
	case error
}

enum StatusMenu {
	static let featureStatusTabLocation: CGFloat = 196

	static func statusSymbolName(mode: StatusIconMode) -> String {
		switch mode {
		case .off: "gamecontroller"
		case .on: "gamecontroller.fill"
		case .error: "exclamationmark.triangle.fill"
		}
	}

	static func statusImage(mode: StatusIconMode) -> NSImage? {
		let image = NSImage(
			systemSymbolName: statusSymbolName(mode: mode),
			accessibilityDescription: "Game Mode Bar"
		)
		image?.isTemplate = true
		return image
	}

	static func menuSymbol(_ name: String) -> NSImage? {
		let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
		image?.isTemplate = true
		return image
	}

	static func featureRowAttributedTitle(label: String, on: Bool) -> NSAttributedString {
		let status = on ? "On" : "Off"
		let string = "\(label)\t\(status)"
		let paragraph = NSMutableParagraphStyle()
		paragraph.tabStops = [
			NSTextTab(textAlignment: .right, location: featureStatusTabLocation, options: [:]),
		]
		let font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
		let labelColor = on ? NSColor.labelColor : NSColor.secondaryLabelColor
		let statusColor = on ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
		let attributed = NSMutableAttributedString(
			string: string,
			attributes: [
				.font: font,
				.paragraphStyle: paragraph,
				.foregroundColor: labelColor,
			]
		)
		let statusRange = (string as NSString).range(of: status)
		attributed.addAttribute(.foregroundColor, value: statusColor, range: statusRange)
		return attributed
	}

	static func applyFeatureRow(_ item: NSMenuItem, label: String, on: Bool) {
		let status = on ? "On" : "Off"
		item.title = "\(label), \(status)"
		item.attributedTitle = featureRowAttributedTitle(label: label, on: on)
	}

	static func updateFeatureRows(
		gameItem: NSMenuItem,
		airDropItem: NSMenuItem,
		state: SystemState?
	) {
		guard let state else {
			applyFeatureRow(gameItem, label: "Game Mode", on: false)
			applyFeatureRow(airDropItem, label: "No AirDrop (AWDL)", on: false)
			return
		}
		applyFeatureRow(gameItem, label: "Game Mode", on: state.gameModeChecked)
		applyFeatureRow(airDropItem, label: "No AirDrop (AWDL)", on: state.noAirDropChecked)
	}

	static func masterToggleTitle(for state: SystemState?) -> String {
		guard let state else { return "Enable Game Mode+" }
		let anyOn = state.gameModeChecked || state.noAirDropChecked
		return anyOn ? "Disable Game Mode+" : "Enable Game Mode+"
	}

	static func iconMode(for state: SystemState?) -> StatusIconMode {
		guard let state else { return .error }
		let anyOn = state.gameModeChecked || state.noAirDropChecked
		return anyOn ? .on : .off
	}
}
