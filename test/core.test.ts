import { afterEach, describe, expect, test } from "bun:test";
import { chmod, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
	allAvailableOn,
	anyFeatureOn,
	authorizationReady,
	buildPrerequisites,
	type Paths,
	parseState,
	type Runner,
	setAwdlMode,
	setGameModePolicy,
	sudoersRule,
	TransitionError,
	toggleMode,
} from "../src/core";

const sandboxes: string[] = [];

afterEach(async () => {
	await Promise.all(
		sandboxes
			.splice(0)
			.map((path) => rm(path, { force: true, recursive: true })),
	);
});

const fakeBinary = `#!/bin/sh
root="$NM_FAKE_ROOT"
name="\${0##*/}"
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
`;

const makeFake = async (
	awdl: "down" | "up",
	game: "off" | "on",
	policy: "auto" | "on",
	options: { gamepolicy?: string | null } = {},
) => {
	const root = await mkdtemp(join(tmpdir(), "gamemode-bar-test-"));
	sandboxes.push(root);
	await Promise.all([
		writeFile(join(root, "awdl"), awdl),
		writeFile(join(root, "game"), game),
		writeFile(join(root, "policy"), policy),
		writeFile(join(root, "log"), ""),
	]);
	const binary = async (name: string) => {
		const path = join(root, name);
		await writeFile(path, fakeBinary);
		await chmod(path, 0o755);
		return path;
	};
	const [ifconfig, sudo, testPath] = await Promise.all([
		binary("ifconfig"),
		binary("sudo"),
		binary("test"),
	]);
	const gamepolicy =
		options.gamepolicy === null ? null : await binary("gamepolicyctl");
	const paths: Paths = {
		chmod: join(root, "chmod"),
		cmp: join(root, "cmp"),
		gamepolicy: gamepolicy ?? join(root, "gamepolicyctl"),
		ifconfig,
		install: join(root, "install"),
		mktemp: join(root, "mktemp"),
		osascript: join(root, "osascript"),
		rm: join(root, "rm"),
		sudo,
		sudoers: join(root, "sudoers"),
		test: testPath,
		visudo: join(root, "visudo"),
	};
	const environment = {
		...process.env,
		NM_FAKE_ROOT: root,
	};
	const run: Runner = async (command) => {
		const child = Bun.spawn(command, {
			env: environment,
			stderr: "pipe",
			stdout: "pipe",
		});
		const [exitCode, stdout, stderr] = await Promise.all([
			child.exited,
			new Response(child.stdout).text(),
			new Response(child.stderr).text(),
		]);
		return { exitCode, stderr: stderr.trim(), stdout: stdout.trim() };
	};
	return {
		fail: (operation: string) => writeFile(join(root, "fail"), operation),
		log: () => Bun.file(join(root, "log")).text(),
		paths,
		read: async () => ({
			awdl: (await Bun.file(join(root, "awdl")).text()).trim(),
			game: (await Bun.file(join(root, "game")).text()).trim(),
			policy: (await Bun.file(join(root, "policy")).text()).trim(),
		}),
		root,
		run,
		staleGameStatus: () => writeFile(join(root, "stale-status"), "1"),
	};
};

describe("state parsing", () => {
	test("reads ANSI Game Mode output and independent checks", () => {
		const state = parseState(
			"awdl0: flags=8863<UP,BROADCAST,RUNNING>",
			"Game mode is \u001b[0;32mon\u001b[0;0m.\nGame mode is forced always on.",
		);
		expect(state).toMatchObject({
			awdl: "up",
			gameMode: "on",
			gameModeChecked: true,
			noAirDropChecked: false,
		});
	});

	test("reads Tahoe-style dual policy lines", () => {
		const state = parseState(
			"awdl0: flags=8802<BROADCAST,SIMPLEX,MULTICAST>",
			"Game mode is off.\nGame mode enablement policy is currently enabled.",
		);
		expect(state).toMatchObject({
			awdl: "down",
			gamePolicy: "auto",
			noAirDropChecked: true,
		});
	});
});

describe("authorization", () => {
	test("is ready when passwordless ifconfig works for the current state", async () => {
		const fake = await makeFake("up", "off", "auto");
		expect(await authorizationReady(fake.paths, fake.run)).toBe(true);
	});

	test("does not require a gamemode-bar-awdl file on disk", async () => {
		const fake = await makeFake("down", "on", "on");
		expect(await authorizationReady(fake.paths, fake.run)).toBe(true);
		expect(await Bun.file(fake.paths.sudoers).exists()).toBe(false);
	});
});

describe("independent setters", () => {
	test("set-game on succeeds on exit 0 even if live status stays off", async () => {
		const fake = await makeFake("up", "off", "auto");
		await fake.staleGameStatus();
		const state = await setGameModePolicy(fake.paths, fake.run, "on");
		expect(state.gameModeChecked).toBe(false);
		expect(await fake.log()).toBe("game on\nstale\n");
		expect(await fake.read()).toEqual({
			awdl: "up",
			game: "off",
			policy: "auto",
		});
	});

	test("set-awdl only changes AWDL", async () => {
		const fake = await makeFake("up", "off", "auto");
		const state = await setAwdlMode(fake.paths, fake.run, "down");
		expect(state).toMatchObject({ awdl: "down", noAirDropChecked: true });
		expect(await fake.log()).toBe("awdl down\n");
	});

	test("rolls back a single AWDL change on failure", async () => {
		const fake = await makeFake("up", "off", "auto");
		await fake.fail("awdl-down");
		await expect(
			setAwdlMode(fake.paths, fake.run, "down"),
		).rejects.toBeInstanceOf(TransitionError);
		expect(await fake.read()).toEqual({
			awdl: "up",
			game: "off",
			policy: "auto",
		});
	});
});

describe("master toggle", () => {
	test("enables AWDL down and Game Mode on", async () => {
		const fake = await makeFake("up", "off", "auto");
		const { state, warnings } = await toggleMode(fake.paths, fake.run);
		expect(warnings).toEqual([]);
		expect(state).toMatchObject({
			awdl: "down",
			gameMode: "on",
			gameModeChecked: true,
			noAirDropChecked: true,
		});
		expect(await fake.log()).toBe("awdl down\ngame on\n");
	});

	test("disables when everything available is on", async () => {
		const fake = await makeFake("down", "on", "on");
		const { state } = await toggleMode(fake.paths, fake.run);
		expect(state).toMatchObject({
			awdl: "up",
			gamePolicy: "auto",
			noAirDropChecked: false,
		});
		expect(await fake.log()).toBe("awdl up\ngame auto\n");
	});

	test("disables when only one feature is on", async () => {
		const fake = await makeFake("up", "on", "on");
		const { state } = await toggleMode(fake.paths, fake.run);
		expect(state).toMatchObject({
			awdl: "up",
			gamePolicy: "auto",
			gameModeChecked: false,
			noAirDropChecked: false,
		});
		expect(await fake.log()).toBe("awdl up\ngame auto\n");
	});

	test("still toggles AWDL when gamepolicyctl is missing", async () => {
		const fake = await makeFake("up", "off", "auto", { gamepolicy: null });
		const { state, warnings } = await toggleMode(fake.paths, fake.run);
		expect(state).toMatchObject({ awdl: "down", noAirDropChecked: true });
		expect(state.xcode.available).toBe(false);
		expect(warnings[0]).toContain("Install full Xcode");
		expect(await fake.log()).toBe("awdl down\n");
	});
});

describe("anyFeatureOn", () => {
	test("is true when either checkbox is on", () => {
		expect(
			anyFeatureOn({
				awdl: "up",
				detail: "",
				gameMode: "on",
				gameModeChecked: true,
				gamePolicy: "on",
				noAirDropChecked: false,
				xcode: {
					available: true,
					reason: "",
					statusOutput: "",
				},
			}),
		).toBe(true);
	});
});

describe("allAvailableOn", () => {
	test("ignores Game Mode when Xcode tools are unavailable", () => {
		const state = parseState(
			"awdl0: flags=8802<BROADCAST,SIMPLEX,MULTICAST>",
			"Game mode is off.\nGame mode enablement policy is currently enabled.",
		);
		state.xcode = {
			available: false,
			reason: "Install full Xcode in /Applications.",
			statusOutput: "",
		};
		expect(allAvailableOn(state)).toBe(true);
	});
});

describe("prerequisites", () => {
	test("reports Xcode App Store action when gamepolicyctl is missing", async () => {
		const fake = await makeFake("up", "off", "auto", { gamepolicy: null });
		const { readState } = await import("../src/core");
		const current = await readState(fake.paths, fake.run);
		const auth = await authorizationReady(fake.paths, fake.run);
		expect(buildPrerequisites(current, auth)).toEqual({
			awdlAuth: { ok: true },
			xcode: {
				action: "openAppStore",
				ok: false,
				reason: "Install full Xcode in /Applications.",
			},
		});
	});

	test("reports sudoers install when authorization is missing", async () => {
		const fake = await makeFake("up", "off", "auto");
		const { readState } = await import("../src/core");
		const state = await readState(fake.paths, fake.run);
		expect(buildPrerequisites(state, false)).toEqual({
			awdlAuth: { action: "installSudoers", ok: false },
			xcode: { ok: true, reason: "" },
		});
	});
});

describe("sudoersRule", () => {
	test("matches the Desktop script format", () => {
		expect(sudoersRule("kytix", "/sbin/ifconfig")).toBe(
			"kytix ALL=(root) NOPASSWD: /sbin/ifconfig awdl0 down, /sbin/ifconfig awdl0 up\n",
		);
	});
});
