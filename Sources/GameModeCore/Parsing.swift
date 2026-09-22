import Foundation

private let ansiPattern = try! NSRegularExpression(
	pattern: "\u{001B}\\[[0-9;]*m",
	options: []
)

private func stripAnsi(_ value: String) -> String {
	let range = NSRange(value.startIndex..., in: value)
	return ansiPattern.stringByReplacingMatches(
		in: value,
		options: [],
		range: range,
		withTemplate: ""
	)
}

public func awdlFromOutput(_ awdlOutput: String) -> AwdlState {
	let firstLine = awdlOutput.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
	if firstLine.range(of: "<[^>]*\\bUP(?:,|>)", options: .regularExpression) != nil {
		return .up
	}
	return .down
}

public func parseGameOutput(_ gameOutput: String) throws -> (gameMode: GameMode, gamePolicy: GamePolicy) {
	let cleanGame = stripAnsi(gameOutput)
	let regex = try NSRegularExpression(pattern: "Game mode is (on|off)\\.", options: .caseInsensitive)
	let nsRange = NSRange(cleanGame.startIndex..., in: cleanGame)
	guard let match = regex.firstMatch(in: cleanGame, options: [], range: nsRange),
		let capture = Range(match.range(at: 1), in: cleanGame)
	else {
		throw NSError(
			domain: "GameModeCore",
			code: 1,
			userInfo: [NSLocalizedDescriptionKey: "gamepolicyctl returned an unknown state."]
		)
	}
	let gameMode: GameMode = String(cleanGame[capture]).lowercased() == "on" ? .on : .off
	let gamePolicy: GamePolicy
	if cleanGame.range(of: "forced always on", options: .caseInsensitive) != nil {
		gamePolicy = .on
	} else if cleanGame.range(
		of: #"enablement policy is currently enabled|automatic|\bauto\b"#,
		options: [.regularExpression, .caseInsensitive]
	) != nil {
		gamePolicy = .auto
	} else {
		gamePolicy = .unknown
	}
	return (gameMode, gamePolicy)
}

public func buildSystemState(
	awdl: AwdlState,
	gameMode: GameMode,
	gamePolicy: GamePolicy,
	xcode: XcodeProbe
) -> SystemState {
	let gameModeChecked = gameMode == .on
	let noAirDropChecked = awdl == .down
	let policyLabel = gamePolicy == .unknown ? "unknown policy" : "\(gamePolicy.rawValue) policy"
	return SystemState(
		awdl: awdl,
		detail: "AWDL \(awdl.rawValue) • Game Mode \(gameMode.rawValue) (\(policyLabel))",
		gameMode: gameMode,
		gameModeChecked: gameModeChecked,
		gamePolicy: gamePolicy,
		noAirDropChecked: noAirDropChecked,
		xcode: xcode
	)
}

public func parseState(
	awdlOutput: String,
	gameOutput: String,
	xcode: XcodeProbe? = nil
) throws -> SystemState {
	let awdl = awdlFromOutput(awdlOutput)
	let parsed = try parseGameOutput(gameOutput)
	let probe = xcode ?? XcodeProbe(available: true, reason: "", statusOutput: gameOutput)
	return buildSystemState(
		awdl: awdl,
		gameMode: parsed.gameMode,
		gamePolicy: parsed.gamePolicy,
		xcode: probe
	)
}
