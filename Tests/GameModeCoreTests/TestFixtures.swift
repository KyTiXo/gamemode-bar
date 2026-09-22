import Foundation
import GameModeCore

struct FakeEnvironment {
	let root: String
	let paths: Paths
	let runner: CommandRunner

	func fail(_ operation: String) throws {
		try operation.write(toFile: "\(root)/fail", atomically: true, encoding: .utf8)
	}

	func staleGameStatus() throws {
		try "1".write(toFile: "\(root)/stale-status", atomically: true, encoding: .utf8)
	}

	func log() throws -> String {
		try String(contentsOfFile: "\(root)/log", encoding: .utf8)
	}

	func read() throws -> (awdl: String, game: String, policy: String) {
		let awdl = try String(contentsOfFile: "\(root)/awdl", encoding: .utf8).trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let game = try String(contentsOfFile: "\(root)/game", encoding: .utf8).trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let policy = try String(contentsOfFile: "\(root)/policy", encoding: .utf8).trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		return (awdl, game, policy)
	}
}

enum TestFixtures {
	private static let fakeBinary = """
	#!/bin/sh
	root="$NM_FAKE_ROOT"
	name="${0##*/}"
	log() { printf '%s\\n' "$*" >> "$root/log"; }
	fails() { [ -f "$root/fail" ] && [ "$(cat "$root/fail")" = "$1" ]; }
	case "$name" in
	  ifconfig)
	    awdl=$(cat "$root/awdl")
	    if [ "$awdl" = up ]; then echo 'awdl0: flags=8863<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500'; else echo 'awdl0: flags=8802<BROADCAST,SIMPLEX,MULTICAST> mtu 1500'; fi
	    ;;
	  gamepolicyctl)
	    if [ "$2" = status ]; then
	      game=$(cat "$root/game")
	      policy=$(cat "$root/policy")
	      echo "Game mode is $game."
	      if [ "$policy" = on ]; then echo 'Game mode is forced always on.'; else echo 'Game mode enablement policy is currently enabled.'; fi
	    else
	      mode="$3"; log "game $mode"
	      if fails "game-$mode"; then echo "fake game failure" >&2; exit 1; fi
	      if [ -f "$root/stale-status" ]; then log "stale"; exit 0; fi
	      if [ "$mode" = on ]; then echo on > "$root/game"; echo on > "$root/policy"; else echo off > "$root/game"; echo auto > "$root/policy"; fi
	    fi
	    ;;
	  sudo)
	    if [ "$1" = -n ] && [ "$3" = awdl0 ]; then
	      mode="$4"
	      log "awdl $mode"
	      if fails "awdl-$mode"; then echo "fake awdl failure" >&2; exit 1; fi
	      echo "$mode" > "$root/awdl"
	    fi
	    ;;
	  test)
	    if [ "$1" = -x ] && [ -f "$2" ]; then exit 0; fi
	    exit 1
	    ;;
	esac
	"""

	nonisolated(unsafe) private static var sandboxes: [String] = []

	static func cleanupSandboxes() {
		for path in sandboxes {
			try? FileManager.default.removeItem(atPath: path)
		}
		sandboxes.removeAll()
	}

	static func makeFake(
		awdl: AwdlState,
		game: GameMode,
		policy: GamePolicy,
		includeGamepolicy: Bool = true
	) throws -> FakeEnvironment {
		let root = NSTemporaryDirectory() + "gamemode-bar-test-\(UUID().uuidString)"
		try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
		sandboxes.append(root)
		try awdl.rawValue.write(toFile: "\(root)/awdl", atomically: true, encoding: .utf8)
		try game.rawValue.write(toFile: "\(root)/game", atomically: true, encoding: .utf8)
		try policy.rawValue.write(toFile: "\(root)/policy", atomically: true, encoding: .utf8)
		try "".write(toFile: "\(root)/log", atomically: true, encoding: .utf8)

		func binary(_ name: String) throws -> String {
			let path = "\(root)/\(name)"
			try fakeBinary.write(toFile: path, atomically: true, encoding: .utf8)
			try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
			return path
		}

		let ifconfig = try binary("ifconfig")
		let sudo = try binary("sudo")
		let testPath = try binary("test")
		let gamepolicyPath = includeGamepolicy ? try binary("gamepolicyctl") : "\(root)/gamepolicyctl"

		let paths = Paths(
			chmod: "\(root)/chmod",
			cmp: "\(root)/cmp",
			gamepolicy: gamepolicyPath,
			ifconfig: ifconfig,
			install: "\(root)/install",
			mktemp: "\(root)/mktemp",
			osascript: "\(root)/osascript",
			rm: "\(root)/rm",
			sudo: sudo,
			sudoers: "\(root)/sudoers",
			test: testPath,
			visudo: "\(root)/visudo"
		)
		let runner = EnvironmentCommandRunner(
			base: ProcessCommandRunner(),
			environment: ["NM_FAKE_ROOT": root]
		)
		return FakeEnvironment(root: root, paths: paths, runner: runner)
	}
}
