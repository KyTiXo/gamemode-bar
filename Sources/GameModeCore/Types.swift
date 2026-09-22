import Foundation

public struct CommandResult: Sendable, Equatable {
	public let exitCode: Int32
	public let stderr: String
	public let stdout: String
}

public struct Paths: Sendable, Equatable {
	public var chmod: String
	public var cmp: String
	public var gamepolicy: String
	public var ifconfig: String
	public var install: String
	public var mktemp: String
	public var osascript: String
	public var rm: String
	public var sudo: String
	public var sudoers: String
	public var test: String
	public var visudo: String

	public init(
		chmod: String,
		cmp: String,
		gamepolicy: String,
		ifconfig: String,
		install: String,
		mktemp: String,
		osascript: String,
		rm: String,
		sudo: String,
		sudoers: String,
		test: String,
		visudo: String
	) {
		self.chmod = chmod
		self.cmp = cmp
		self.gamepolicy = gamepolicy
		self.ifconfig = ifconfig
		self.install = install
		self.mktemp = mktemp
		self.osascript = osascript
		self.rm = rm
		self.sudo = sudo
		self.sudoers = sudoers
		self.test = test
		self.visudo = visudo
	}

	public static func fromEnv() -> Paths {
		func pathEnv(key: String, fallback: String) -> String {
			ProcessInfo.processInfo.environment["GAME_MODE_BAR_\(key)"] ?? fallback
		}
		return Paths(
			chmod: pathEnv(key: "CHMOD", fallback: "/bin/chmod"),
			cmp: pathEnv(key: "CMP", fallback: "/usr/bin/cmp"),
			gamepolicy: pathEnv(
				key: "GAMEPOLICYCTL",
				fallback: "/Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl"
			),
			ifconfig: pathEnv(key: "IFCONFIG", fallback: "/sbin/ifconfig"),
			install: pathEnv(key: "INSTALL", fallback: "/usr/bin/install"),
			mktemp: pathEnv(key: "MKTEMP", fallback: "/usr/bin/mktemp"),
			osascript: pathEnv(key: "OSASCRIPT", fallback: "/usr/bin/osascript"),
			rm: pathEnv(key: "RM", fallback: "/bin/rm"),
			sudo: pathEnv(key: "SUDO", fallback: "/usr/bin/sudo"),
			sudoers: pathEnv(key: "SUDOERS", fallback: "/etc/sudoers.d/gamemode-bar-awdl"),
			test: pathEnv(key: "TEST", fallback: "/bin/test"),
			visudo: pathEnv(key: "VISUDO", fallback: "/usr/sbin/visudo")
		)
	}
}

public struct XcodeProbe: Sendable, Equatable {
	public var available: Bool
	public var reason: String
	public var statusOutput: String

	public init(available: Bool, reason: String, statusOutput: String) {
		self.available = available
		self.reason = reason
		self.statusOutput = statusOutput
	}
}

public enum AwdlState: String, Sendable, Equatable {
	case down
	case up
}

public enum GameMode: String, Sendable, Equatable {
	case off
	case on
}

public enum GamePolicy: String, Sendable, Equatable {
	case auto
	case on
	case unknown
}

public struct SystemState: Sendable, Equatable {
	public var awdl: AwdlState
	public var detail: String
	public var gameMode: GameMode
	public var gameModeChecked: Bool
	public var gamePolicy: GamePolicy
	public var noAirDropChecked: Bool
	public var xcode: XcodeProbe

	public init(
		awdl: AwdlState,
		detail: String,
		gameMode: GameMode,
		gameModeChecked: Bool,
		gamePolicy: GamePolicy,
		noAirDropChecked: Bool,
		xcode: XcodeProbe
	) {
		self.awdl = awdl
		self.detail = detail
		self.gameMode = gameMode
		self.gameModeChecked = gameModeChecked
		self.gamePolicy = gamePolicy
		self.noAirDropChecked = noAirDropChecked
		self.xcode = xcode
	}
}

public struct TransitionError: Error, Sendable {
	public let message: String
	public let detail: String
	public let state: SystemState?
	public let command: String?

	public init(
		message: String,
		detail: String,
		state: SystemState? = nil,
		command: String? = nil
	) {
		self.message = message
		self.detail = detail
		self.state = state
		self.command = command
	}
}

public struct AwdlAuthPrerequisite: Sendable, Equatable {
	public var action: String?
	public var ok: Bool
}

public struct XcodePrerequisite: Sendable, Equatable {
	public var action: String?
	public var ok: Bool
	public var reason: String
}

public struct Prerequisites: Sendable, Equatable {
	public var awdlAuth: AwdlAuthPrerequisite
	public var xcode: XcodePrerequisite
}

public struct ToggleResult: Sendable {
	public var state: SystemState
	public var warnings: [String]
}

public struct StatusSnapshot: Sendable {
	public var state: SystemState
	public var authorization: Bool
	public var needsAuthorization: Bool
	public var prerequisites: Prerequisites
}

public struct ActionResult: Sendable {
	public var ok: Bool
	public var state: SystemState?
	public var authorization: Bool?
	public var needsAuthorization: Bool?
	public var message: String?
	public var detail: String?
	public var warnings: [String]?
	public var prerequisites: Prerequisites?

	public static func success(
		state: SystemState,
		authorization: Bool? = nil,
		warnings: [String]? = nil,
		prerequisites: Prerequisites? = nil
	) -> ActionResult {
		ActionResult(
			ok: true,
			state: state,
			authorization: authorization,
			needsAuthorization: authorization == false ? true : nil,
			message: nil,
			detail: nil,
			warnings: warnings,
			prerequisites: prerequisites
		)
	}

	public static func failure(
		message: String,
		detail: String,
		state: SystemState? = nil
	) -> ActionResult {
		ActionResult(
			ok: false,
			state: state,
			authorization: nil,
			needsAuthorization: nil,
			message: message,
			detail: detail,
			warnings: nil,
			prerequisites: nil
		)
	}

	public static func needsAuth(state: SystemState) -> ActionResult {
		ActionResult(
			ok: false,
			state: state,
			authorization: false,
			needsAuthorization: true,
			message: "One-time authorization is required for No AirDrop.",
			detail: nil,
			warnings: nil,
			prerequisites: nil
		)
	}
}
