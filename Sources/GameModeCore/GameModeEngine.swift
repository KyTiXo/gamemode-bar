import Foundation

private func formatCommand(_ command: [String]) -> String {
	command.map { part in
		part.contains(where: \.isWhitespace) ? "\"\(part)\"" : part
	}.joined(separator: " ")
}

private func commandFailure(
	_ command: [String],
	_ result: CommandResult,
	_ message: String
) -> String {
	let parts = [
		message,
		"Command: \(formatCommand(command))",
		result.stderr.isEmpty ? nil : "stderr: \(result.stderr)",
		result.stdout.isEmpty ? nil : "stdout: \(result.stdout)",
	].compactMap { $0 }
	return parts.joined(separator: "\n")
}

private func requireSuccess(
	_ command: [String],
	_ result: CommandResult,
	_ message: String
) throws {
	if result.exitCode == 0 { return }
	throw NSError(
		domain: "GameModeCore",
		code: Int(result.exitCode),
		userInfo: [NSLocalizedDescriptionKey: commandFailure(command, result, message)]
	)
}

public func probeXcode(paths: Paths, runner: CommandRunner) async throws -> XcodeProbe {
	let executable = try await runner.run([paths.test, "-x", paths.gamepolicy])
	if executable.exitCode != 0 {
		return XcodeProbe(
			available: false,
			reason: "Install full Xcode in /Applications.",
			statusOutput: ""
		)
	}
	let status = try await runner.run([paths.gamepolicy, "game-mode", "status"])
	if status.exitCode != 0 {
		let detail = [status.stderr, status.stdout].filter { !$0.isEmpty }.joined(separator: " ")
		let reason = detail.isEmpty
			? "gamepolicyctl game-mode status failed."
			: "gamepolicyctl game-mode status failed: \(detail)"
		return XcodeProbe(available: false, reason: reason, statusOutput: "")
	}
	return XcodeProbe(available: true, reason: "", statusOutput: status.stdout)
}

public func readState(paths: Paths, runner: CommandRunner) async throws -> SystemState {
	let awdl = try await runner.run([paths.ifconfig, "awdl0"])
	try requireSuccess(
		[paths.ifconfig, "awdl0"],
		awdl,
		"The awdl0 interface is unavailable."
	)
	let xcode = try await probeXcode(paths: paths, runner: runner)
	let awdlState = awdlFromOutput(awdl.stdout)
	if !xcode.available {
		return buildSystemState(awdl: awdlState, gameMode: .off, gamePolicy: .unknown, xcode: xcode)
	}
	return try parseState(awdlOutput: awdl.stdout, gameOutput: xcode.statusOutput, xcode: xcode)
}

public func sudoersRule(user: String, ifconfig: String) -> String {
	"\(user) ALL=(root) NOPASSWD: \(ifconfig) awdl0 down, \(ifconfig) awdl0 up\n"
}

public func buildPrerequisites(state: SystemState, authorization: Bool) -> Prerequisites {
	Prerequisites(
		awdlAuth: authorization
			? AwdlAuthPrerequisite(action: nil, ok: true)
			: AwdlAuthPrerequisite(action: "installSudoers", ok: false),
		xcode: state.xcode.available
			? XcodePrerequisite(action: nil, ok: true, reason: "")
			: XcodePrerequisite(
				action: "openAppStore",
				ok: false,
				reason: state.xcode.reason.isEmpty
					? "Install full Xcode in /Applications."
					: state.xcode.reason
			)
	)
}

public func authorizationReady(paths: Paths, runner: CommandRunner) async throws -> Bool {
	let awdl = try await runner.run([paths.ifconfig, "awdl0"])
	if awdl.exitCode != 0 { return false }
	let target = awdlFromOutput(awdl.stdout)
	let probe = try await runner.run([paths.sudo, "-n", paths.ifconfig, "awdl0", target.rawValue])
	return probe.exitCode == 0
}

private func shellQuote(_ value: String) -> String {
	"'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
}

private func appleQuote(_ value: String) -> String {
	"\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
}

private let trustedIfconfig = "/sbin/ifconfig"
private let trustedSudoers = "/etc/sudoers.d/gamemode-bar-awdl"

public func installAuthorization(
	paths: Paths,
	runner: CommandRunner,
	user: String
) async throws {
	guard paths.ifconfig == trustedIfconfig, paths.sudoers == trustedSudoers else {
		throw NSError(
			domain: "GameModeCore",
			code: 1,
			userInfo: [NSLocalizedDescriptionKey: "Unsupported tool path for sudoers install."]
		)
	}
	guard user.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
		throw NSError(
			domain: "GameModeCore",
			code: 1,
			userInfo: [NSLocalizedDescriptionKey: "Unsupported macOS account name."]
		)
	}
	let tmp = ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp"
	let temporary = try await runner.run([paths.mktemp, "\(tmp)/gamemode-bar-awdl.XXXXXX"])
	try requireSuccess(
		[paths.mktemp],
		temporary,
		"Could not create the sudoers staging file."
	)
	let file = temporary.stdout
	let rule = sudoersRule(user: user, ifconfig: trustedIfconfig)
	do {
		try rule.write(toFile: file, atomically: true, encoding: .utf8)
		try requireSuccess(
			[paths.chmod, "600", file],
			try await runner.run([paths.chmod, "600", file]),
			"Could not secure staging file."
		)
		try requireSuccess(
			[paths.visudo, "-cf", file],
			try await runner.run([paths.visudo, "-cf", file]),
			"The sudoers rule failed visudo validation."
		)
		let command = [
			"\(shellQuote(paths.visudo)) -cf \(shellQuote(file))",
			"\(shellQuote(paths.install)) -o root -g wheel -m 0440 \(shellQuote(file)) \(shellQuote(paths.sudoers))",
			"\(shellQuote(paths.visudo)) -cf \(shellQuote(paths.sudoers))",
			"\(shellQuote(paths.cmp)) -s \(shellQuote(file)) \(shellQuote(paths.sudoers))",
		].joined(separator: " && ")
		let authorizationCommand = [
			paths.osascript,
			"-e",
			"do shell script \(appleQuote(command)) with administrator privileges",
		]
		try requireSuccess(
			authorizationCommand,
			try await runner.run(authorizationCommand),
			"Authorization was cancelled or the sudoers rule could not be installed."
		)
		if try await !authorizationReady(paths: paths, runner: runner) {
			throw NSError(
				domain: "GameModeCore",
				code: 1,
				userInfo: [
					NSLocalizedDescriptionKey:
						"The AWDL rule was installed but passwordless ifconfig did not work.",
				]
			)
		}
	} catch {
		_ = try? await runner.run([paths.rm, "-f", file])
		throw error
	}
	_ = try? await runner.run([paths.rm, "-f", file])
}

private func runAwdl(paths: Paths, runner: CommandRunner, mode: AwdlState) async throws {
	let command = [paths.sudo, "-n", paths.ifconfig, "awdl0", mode.rawValue]
	try requireSuccess(command, try await runner.run(command), "Could not set AWDL \(mode.rawValue).")
}

private func runGamePolicy(paths: Paths, runner: CommandRunner, mode: GamePolicy) async throws {
	guard mode == .on || mode == .auto else { return }
	let command = [paths.gamepolicy, "game-mode", "set", mode.rawValue]
	try requireSuccess(
		command,
		try await runner.run(command),
		"Could not set Game Mode \(mode.rawValue)."
	)
}

private func restoreGame(
	paths: Paths,
	runner: CommandRunner,
	state: SystemState,
	errors: inout [String]
) async {
	guard state.xcode.available else { return }
	do {
		let policy: GamePolicy = state.gamePolicy == .on ? .on : .auto
		try await runGamePolicy(paths: paths, runner: runner, mode: policy)
	} catch {
		errors.append(error.localizedDescription)
	}
}

private func restoreAwdl(
	paths: Paths,
	runner: CommandRunner,
	awdl: AwdlState,
	errors: inout [String]
) async {
	do {
		try await runAwdl(paths: paths, runner: runner, mode: awdl)
	} catch {
		errors.append(error.localizedDescription)
	}
}

private func transitionFailure(
	paths: Paths,
	runner: CommandRunner,
	message: String,
	cause: Error,
	rollback: () async -> [String]
) async throws -> Never {
	var rollbackErrors = await rollback()
	var finalState: SystemState?
	do {
		finalState = try await readState(paths: paths, runner: runner)
	} catch {
		rollbackErrors.append(
			"Final state could not be read: \(error.localizedDescription)"
		)
	}
	let causeMessage = cause.localizedDescription
	let detailSuffix = rollbackErrors.isEmpty
		? "The previous setting was restored and re-read."
		: "Rollback issues: \(rollbackErrors.joined(separator: " "))"
	throw TransitionError(
		message: message,
		detail: [causeMessage, detailSuffix].joined(separator: "\n"),
		state: finalState
	)
}

public func allAvailableOn(_ state: SystemState) -> Bool {
	let gameOn = state.xcode.available ? state.gameModeChecked : true
	return gameOn && state.noAirDropChecked
}

/// Master toggle treats either checkbox as “on” for the next disable action.
public func anyFeatureOn(_ state: SystemState) -> Bool {
	state.noAirDropChecked || state.gameModeChecked
}

public func setAwdlMode(
	paths: Paths,
	runner: CommandRunner,
	mode: AwdlState
) async throws -> SystemState {
	let initial = try await readState(paths: paths, runner: runner)
	let previous = initial.awdl
	if previous == mode { return initial }
	do {
		try await runAwdl(paths: paths, runner: runner, mode: mode)
		return try await readState(paths: paths, runner: runner)
	} catch {
		try await transitionFailure(
			paths: paths,
			runner: runner,
			message: mode == .down
				? "No AirDrop could not be enabled."
				: "No AirDrop could not be disabled.",
			cause: error,
			rollback: {
				var errors: [String] = []
				await restoreAwdl(paths: paths, runner: runner, awdl: previous, errors: &errors)
				return errors
			}
		)
	}
}

public func setGameModePolicy(
	paths: Paths,
	runner: CommandRunner,
	mode: GamePolicy
) async throws -> SystemState {
	let initial = try await readState(paths: paths, runner: runner)
	guard initial.xcode.available else {
		throw TransitionError(
			message: "macOS Game Mode is unavailable.",
			detail: initial.xcode.reason.isEmpty
				? "Install full Xcode in /Applications."
				: initial.xcode.reason,
			state: initial
		)
	}
	let previousPolicy: GamePolicy
	if initial.gamePolicy == .on {
		previousPolicy = .on
	} else if initial.gamePolicy == .auto {
		previousPolicy = .auto
	} else {
		previousPolicy = .auto
	}
	do {
		try await runGamePolicy(paths: paths, runner: runner, mode: mode)
		return try await readState(paths: paths, runner: runner)
	} catch {
		try await transitionFailure(
			paths: paths,
			runner: runner,
			message: mode == .on
				? "macOS Game Mode could not be enabled."
				: "macOS Game Mode could not be restored to automatic.",
			cause: error,
			rollback: {
				var errors: [String] = []
				var rollbackState = initial
				rollbackState.gamePolicy = previousPolicy
				await restoreGame(paths: paths, runner: runner, state: rollbackState, errors: &errors)
				return errors
			}
		)
	}
}

public func toggleMode(paths: Paths, runner: CommandRunner) async throws -> ToggleResult {
	let initial = try await readState(paths: paths, runner: runner)
	let disabling = anyFeatureOn(initial)
	var warnings: [String] = []
	do {
		if disabling {
			try await runAwdl(paths: paths, runner: runner, mode: .up)
			if initial.xcode.available {
				try await runGamePolicy(paths: paths, runner: runner, mode: .auto)
			}
		} else {
			try await runAwdl(paths: paths, runner: runner, mode: .down)
			if initial.xcode.available {
				try await runGamePolicy(paths: paths, runner: runner, mode: .on)
			} else {
				warnings.append(initial.xcode.reason)
			}
		}
		let state = try await readState(paths: paths, runner: runner)
		return ToggleResult(state: state, warnings: warnings)
	} catch let error as TransitionError {
		throw error
	} catch {
		try await transitionFailure(
			paths: paths,
			runner: runner,
			message: disabling
				? "Game Mode Bar could not turn everything off."
				: "Game Mode Bar could not turn everything on.",
			cause: error,
			rollback: {
				var errors: [String] = []
				await restoreAwdl(paths: paths, runner: runner, awdl: initial.awdl, errors: &errors)
				await restoreGame(paths: paths, runner: runner, state: initial, errors: &errors)
				return errors
			}
		)
	}
}
