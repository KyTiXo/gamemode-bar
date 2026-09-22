import Foundation

public actor PolicySession {
	private let paths: Paths
	private let runner: CommandRunner
	private let user: String

	public init(
		paths: Paths = .fromEnv(),
		runner: CommandRunner = ProcessCommandRunner(),
		user: String? = nil
	) {
		self.paths = paths
		self.runner = runner
		self.user = user ?? Self.currentUser()
	}

	private static func currentUser() -> String {
		if let user = ProcessInfo.processInfo.environment["USER"], !user.isEmpty {
			return user
		}
		if let logname = ProcessInfo.processInfo.environment["LOGNAME"], !logname.isEmpty {
			return logname
		}
		return NSUserName()
	}

	public func status() async -> ActionResult {
		do {
			let snapshot = try await statusSnapshot()
			return ActionResult(
				ok: true,
				state: snapshot.state,
				authorization: snapshot.authorization,
				needsAuthorization: snapshot.needsAuthorization,
				message: nil,
				detail: nil,
				warnings: nil,
				prerequisites: snapshot.prerequisites
			)
		} catch let error as TransitionError {
			return .failure(message: error.message, detail: error.detail, state: error.state)
		} catch {
			return .failure(
				message: "Game Mode Bar could not read or change the system state.",
				detail: error.localizedDescription,
				state: nil
			)
		}
	}

	public func statusSnapshot() async throws -> StatusSnapshot {
		async let stateTask = readState(paths: paths, runner: runner)
		async let authTask = authorizationReady(paths: paths, runner: runner)
		let state = try await stateTask
		let authorization = try await authTask
		return StatusSnapshot(
			state: state,
			authorization: authorization,
			needsAuthorization: !authorization,
			prerequisites: buildPrerequisites(state: state, authorization: authorization)
		)
	}

	public func setup() async -> ActionResult {
		do {
			try await installAuthorization(paths: paths, runner: runner, user: user)
			let snapshot = try await statusSnapshot()
			return ActionResult(
				ok: true,
				state: snapshot.state,
				authorization: snapshot.authorization,
				needsAuthorization: snapshot.needsAuthorization,
				message: nil,
				detail: nil,
				warnings: nil,
				prerequisites: snapshot.prerequisites
			)
		} catch let error as TransitionError {
			return .failure(message: error.message, detail: error.detail, state: error.state)
		} catch {
			return .failure(
				message: "Game Mode Bar could not read or change the system state.",
				detail: error.localizedDescription,
				state: nil
			)
		}
	}

	public func toggle(requireAuthorization: Bool = true) async -> ActionResult {
		do {
			if requireAuthorization {
				let authorized = try await authorizationReady(paths: paths, runner: runner)
				if !authorized {
					let state = try await readState(paths: paths, runner: runner)
					return .needsAuth(state: state)
				}
			}
			let result = try await toggleMode(paths: paths, runner: runner)
			return .success(
				state: result.state,
				authorization: true,
				warnings: result.warnings.isEmpty ? nil : result.warnings
			)
		} catch let error as TransitionError {
			return .failure(message: error.message, detail: error.detail, state: error.state)
		} catch {
			return .failure(
				message: "Game Mode Bar could not read or change the system state.",
				detail: error.localizedDescription,
				state: nil
			)
		}
	}

	public func setGame(_ mode: GamePolicy) async -> ActionResult {
		guard mode == .on || mode == .auto else {
			return .failure(
				message: "Game Mode Bar could not read or change the system state.",
				detail: "Expected set-game on or auto.",
				state: nil
			)
		}
		do {
			let state = try await setGameModePolicy(paths: paths, runner: runner, mode: mode)
			return .success(state: state)
		} catch let error as TransitionError {
			return .failure(message: error.message, detail: error.detail, state: error.state)
		} catch {
			return .failure(
				message: "Game Mode Bar could not read or change the system state.",
				detail: error.localizedDescription,
				state: nil
			)
		}
	}

	public func setAwdl(_ mode: AwdlState, requireAuthorization: Bool = true) async -> ActionResult {
		do {
			if requireAuthorization {
				let authorized = try await authorizationReady(paths: paths, runner: runner)
				if !authorized {
					let state = try await readState(paths: paths, runner: runner)
					return .needsAuth(state: state)
				}
			}
			let state = try await setAwdlMode(paths: paths, runner: runner, mode: mode)
			return .success(state: state, authorization: true)
		} catch let error as TransitionError {
			return .failure(message: error.message, detail: error.detail, state: error.state)
		} catch {
			return .failure(
				message: "Game Mode Bar could not read or change the system state.",
				detail: error.localizedDescription,
				state: nil
			)
		}
	}
}
