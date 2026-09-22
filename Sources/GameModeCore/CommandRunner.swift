import Foundation

public protocol CommandRunner: Sendable {
	func run(_ command: [String], extraEnvironment: [String: String]?) async throws -> CommandResult
}

public extension CommandRunner {
	func run(_ command: [String]) async throws -> CommandResult {
		try await run(command, extraEnvironment: nil)
	}
}

public struct ProcessCommandRunner: CommandRunner {
	public init() {}

	public func run(
		_ command: [String],
		extraEnvironment: [String: String]? = nil
	) async throws -> CommandResult {
		try await Task.detached {
			let process = Process()
			let output = Pipe()
			let errors = Pipe()
			process.executableURL = URL(fileURLWithPath: command[0])
			process.arguments = Array(command.dropFirst())
			if let extraEnvironment {
				var env = ProcessInfo.processInfo.environment
				for (key, value) in extraEnvironment {
					env[key] = value
				}
				process.environment = env
			}
			process.standardOutput = output
			process.standardError = errors
			try process.run()
			process.waitUntilExit()
			let stdoutData = output.fileHandleForReading.readDataToEndOfFile()
			let stderrData = errors.fileHandleForReading.readDataToEndOfFile()
			let stdout = String(data: stdoutData, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			let stderr = String(data: stderrData, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			return CommandResult(
				exitCode: process.terminationStatus,
				stderr: stderr,
				stdout: stdout
			)
		}.value
	}
}

public struct EnvironmentCommandRunner: CommandRunner {
	private let base: CommandRunner
	private let environment: [String: String]

	public init(base: CommandRunner, environment: [String: String]) {
		self.base = base
		self.environment = environment
	}

	public func run(
		_ command: [String],
		extraEnvironment: [String: String]? = nil
	) async throws -> CommandResult {
		var merged = environment
		if let extraEnvironment {
			for (key, value) in extraEnvironment {
				merged[key] = value
			}
		}
		return try await base.run(command, extraEnvironment: merged)
	}
}
