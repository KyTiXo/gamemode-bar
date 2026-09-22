import Foundation
import GameModeCore
import Testing

@Suite(.serialized)
struct CoreTests {
	init() {}

	@Test func readsANSIGameModeOutput() throws {
		let state = try parseState(
			awdlOutput: "awdl0: flags=8863<UP,BROADCAST,RUNNING>",
			gameOutput: "Game mode is \u{001B}[0;32mon\u{001B}[0;0m.\nGame mode is forced always on."
		)
		#expect(state.awdl == .up)
		#expect(state.gameMode == .on)
		#expect(state.gameModeChecked)
		#expect(!state.noAirDropChecked)
	}

	@Test func readsTahoeStyleDualPolicyLines() throws {
		let state = try parseState(
			awdlOutput: "awdl0: flags=8802<BROADCAST,SIMPLEX,MULTICAST>",
			gameOutput: "Game mode is off.\nGame mode enablement policy is currently enabled."
		)
		#expect(state.awdl == .down)
		#expect(state.gamePolicy == .auto)
		#expect(state.noAirDropChecked)
	}

	@Test func authorizationReadyWhenPasswordlessIfconfigWorks() async throws {
		let fake = try TestFixtures.makeFake(awdl: .up, game: .off, policy: .auto)
		let ready = try await authorizationReady(paths: fake.paths, runner: fake.runner)
		#expect(ready)
		TestFixtures.cleanupSandboxes()
	}

	@Test func authorizationDoesNotRequireSudoersFile() async throws {
		let fake = try TestFixtures.makeFake(awdl: .down, game: .on, policy: .on)
		let ready = try await authorizationReady(paths: fake.paths, runner: fake.runner)
		#expect(ready)
		#expect(!FileManager.default.fileExists(atPath: fake.paths.sudoers))
		TestFixtures.cleanupSandboxes()
	}

	@Test func setGameOnSucceedsWhenStatusStaysOff() async throws {
		let fake = try TestFixtures.makeFake(awdl: .up, game: .off, policy: .auto)
		try fake.staleGameStatus()
		let state = try await setGameModePolicy(paths: fake.paths, runner: fake.runner, mode: .on)
		#expect(!state.gameModeChecked)
		let log = try fake.log()
		#expect(log == "game on\nstale\n")
		let read = try fake.read()
		#expect(read.awdl == "up")
		#expect(read.game == "off")
		#expect(read.policy == "auto")
		TestFixtures.cleanupSandboxes()
	}

	@Test func setAwdlOnlyChangesAWDL() async throws {
		let fake = try TestFixtures.makeFake(awdl: .up, game: .off, policy: .auto)
		let state = try await setAwdlMode(paths: fake.paths, runner: fake.runner, mode: .down)
		#expect(state.awdl == .down)
		#expect(state.noAirDropChecked)
		let log = try fake.log()
		#expect(log == "awdl down\n")
		TestFixtures.cleanupSandboxes()
	}

	@Test func rollsBackSingleAWDLChangeOnFailure() async throws {
		let fake = try TestFixtures.makeFake(awdl: .up, game: .off, policy: .auto)
		try fake.fail("awdl-down")
		await #expect(throws: TransitionError.self) {
			try await setAwdlMode(paths: fake.paths, runner: fake.runner, mode: .down)
		}
		let read = try fake.read()
		#expect(read.awdl == "up")
		#expect(read.game == "off")
		#expect(read.policy == "auto")
		TestFixtures.cleanupSandboxes()
	}

	@Test func masterToggleEnablesAwdlDownAndGameModeOn() async throws {
		let fake = try TestFixtures.makeFake(awdl: .up, game: .off, policy: .auto)
		let result = try await toggleMode(paths: fake.paths, runner: fake.runner)
		#expect(result.warnings.isEmpty)
		#expect(result.state.awdl == .down)
		#expect(result.state.gameMode == .on)
		#expect(result.state.gameModeChecked)
		#expect(result.state.noAirDropChecked)
		let log = try fake.log()
		#expect(log == "awdl down\ngame on\n")
		TestFixtures.cleanupSandboxes()
	}

	@Test func masterToggleDisablesWhenEverythingOn() async throws {
		let fake = try TestFixtures.makeFake(awdl: .down, game: .on, policy: .on)
		let result = try await toggleMode(paths: fake.paths, runner: fake.runner)
		#expect(result.state.awdl == .up)
		#expect(result.state.gamePolicy == .auto)
		#expect(!result.state.noAirDropChecked)
		let log = try fake.log()
		#expect(log == "awdl up\ngame auto\n")
		TestFixtures.cleanupSandboxes()
	}

	@Test func masterToggleDisablesWhenOnlyOneFeatureOn() async throws {
		let fake = try TestFixtures.makeFake(awdl: .up, game: .on, policy: .on)
		let result = try await toggleMode(paths: fake.paths, runner: fake.runner)
		#expect(result.state.awdl == .up)
		#expect(result.state.gamePolicy == .auto)
		#expect(!result.state.gameModeChecked)
		#expect(!result.state.noAirDropChecked)
		let log = try fake.log()
		#expect(log == "awdl up\ngame auto\n")
		TestFixtures.cleanupSandboxes()
	}

	@Test func masterToggleAwdlWhenGamepolicyctlMissing() async throws {
		let fake = try TestFixtures.makeFake(
			awdl: .up,
			game: .off,
			policy: .auto,
			includeGamepolicy: false
		)
		let result = try await toggleMode(paths: fake.paths, runner: fake.runner)
		#expect(result.state.awdl == .down)
		#expect(result.state.noAirDropChecked)
		#expect(!result.state.xcode.available)
		#expect(result.warnings.first?.contains("Install full Xcode") == true)
		let log = try fake.log()
		#expect(log == "awdl down\n")
		TestFixtures.cleanupSandboxes()
	}

	@Test func anyFeatureOnWhenEitherCheckboxOn() {
		let state = SystemState(
			awdl: .up,
			detail: "",
			gameMode: .on,
			gameModeChecked: true,
			gamePolicy: .on,
			noAirDropChecked: false,
			xcode: XcodeProbe(available: true, reason: "", statusOutput: "")
		)
		#expect(anyFeatureOn(state))
	}

	@Test func allAvailableOnIgnoresGameModeWithoutXcode() throws {
		var state = try parseState(
			awdlOutput: "awdl0: flags=8802<BROADCAST,SIMPLEX,MULTICAST>",
			gameOutput: "Game mode is off.\nGame mode enablement policy is currently enabled."
		)
		state.xcode = XcodeProbe(
			available: false,
			reason: "Install full Xcode in /Applications.",
			statusOutput: ""
		)
		#expect(allAvailableOn(state))
	}

	@Test func prerequisitesXcodeWhenGamepolicyctlMissing() async throws {
		let fake = try TestFixtures.makeFake(
			awdl: .up,
			game: .off,
			policy: .auto,
			includeGamepolicy: false
		)
		let current = try await readState(paths: fake.paths, runner: fake.runner)
		let auth = try await authorizationReady(paths: fake.paths, runner: fake.runner)
		let prereq = buildPrerequisites(state: current, authorization: auth)
		#expect(prereq.awdlAuth.ok)
		#expect(prereq.xcode.action == "openAppStore")
		#expect(!prereq.xcode.ok)
		#expect(prereq.xcode.reason == "Install full Xcode in /Applications.")
		TestFixtures.cleanupSandboxes()
	}

	@Test func prerequisitesSudoersWhenAuthorizationMissing() async throws {
		let fake = try TestFixtures.makeFake(awdl: .up, game: .off, policy: .auto)
		let state = try await readState(paths: fake.paths, runner: fake.runner)
		let prereq = buildPrerequisites(state: state, authorization: false)
		#expect(prereq.awdlAuth.action == "installSudoers")
		#expect(!prereq.awdlAuth.ok)
		#expect(prereq.xcode.ok)
		TestFixtures.cleanupSandboxes()
	}

	@Test func sudoersRuleMatchesDesktopScriptFormat() {
		#expect(sudoersRule(user: "kytix", ifconfig: "/sbin/ifconfig")
			== "kytix ALL=(root) NOPASSWD: /sbin/ifconfig awdl0 down, /sbin/ifconfig awdl0 up\n")
	}

	@Test func installAuthorizationRejectsUntrustedIfconfigPath() async throws {
		let fake = try TestFixtures.makeFake(awdl: .up, game: .off, policy: .auto)
		var paths = fake.paths
		paths.ifconfig = "/tmp/evil"
		await #expect(throws: (any Error).self) {
			try await installAuthorization(paths: paths, runner: fake.runner, user: "kytix")
		}
		TestFixtures.cleanupSandboxes()
	}
}
