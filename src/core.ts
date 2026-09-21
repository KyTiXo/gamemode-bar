export type CommandResult = {
	exitCode: number;
	stderr: string;
	stdout: string;
};

export type Runner = (command: string[]) => Promise<CommandResult>;

export type Paths = {
	chmod: string;
	cmp: string;
	gamepolicy: string;
	ifconfig: string;
	install: string;
	mktemp: string;
	osascript: string;
	rm: string;
	sudo: string;
	sudoers: string;
	test: string;
	visudo: string;
};

export type XcodeProbe = {
	available: boolean;
	reason: string;
	statusOutput: string;
};

export type SystemState = {
	awdl: "down" | "up";
	detail: string;
	gameMode: "off" | "on";
	gameModeChecked: boolean;
	gamePolicy: "auto" | "on" | "unknown";
	noAirDropChecked: boolean;
	xcode: XcodeProbe;
};

export class TransitionError extends Error {
	constructor(
		message: string,
		readonly detail: string,
		readonly state: SystemState | null,
		readonly command?: string,
	) {
		super(message);
	}
}

const envPath = (key: string, fallback: string) =>
	Bun.env[`GAME_MODE_BAR_${key}`] ?? fallback;

export const pathsFromEnv = (): Paths => ({
	chmod: envPath("CHMOD", "/bin/chmod"),
	cmp: envPath("CMP", "/usr/bin/cmp"),
	gamepolicy: envPath(
		"GAMEPOLICYCTL",
		"/Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl",
	),
	ifconfig: envPath("IFCONFIG", "/sbin/ifconfig"),
	install: envPath("INSTALL", "/usr/bin/install"),
	mktemp: envPath("MKTEMP", "/usr/bin/mktemp"),
	osascript: envPath("OSASCRIPT", "/usr/bin/osascript"),
	rm: envPath("RM", "/bin/rm"),
	sudo: envPath("SUDO", "/usr/bin/sudo"),
	sudoers: envPath("SUDOERS", "/etc/sudoers.d/gamemode-bar-awdl"),
	test: envPath("TEST", "/usr/bin/test"),
	visudo: envPath("VISUDO", "/usr/sbin/visudo"),
});

export const spawnRunner: Runner = async (command) => {
	const child = Bun.spawn(command, { stderr: "pipe", stdout: "pipe" });
	const [exitCode, stdout, stderr] = await Promise.all([
		child.exited,
		new Response(child.stdout).text(),
		new Response(child.stderr).text(),
	]);
	return { exitCode, stderr: stderr.trim(), stdout: stdout.trim() };
};

const ansi = new RegExp(`${String.fromCharCode(27)}\\[[0-9;]*m`, "g");
const stripAnsi = (value: string) => value.replaceAll(ansi, "");

const formatCommand = (command: string[]) =>
	command.map((part) => (/\s/.test(part) ? `"${part}"` : part)).join(" ");

const commandFailure = (
	command: string[],
	result: CommandResult,
	message: string,
) => {
	const parts = [
		message,
		`Command: ${formatCommand(command)}`,
		result.stderr ? `stderr: ${result.stderr}` : "",
		result.stdout ? `stdout: ${result.stdout}` : "",
	].filter(Boolean);
	return parts.join("\n");
};

const requireSuccess = (
	command: string[],
	result: CommandResult,
	message: string,
) => {
	if (result.exitCode === 0) return;
	throw new Error(commandFailure(command, result, message));
};

export const awdlFromOutput = (awdlOutput: string): "down" | "up" => {
	const firstLine = awdlOutput.split("\n", 1)[0] ?? "";
	return /<[^>]*\bUP(?:,|>)/.test(firstLine) ? "up" : "down";
};

export const parseGameOutput = (gameOutput: string) => {
	const cleanGame = stripAnsi(gameOutput);
	const gameMatch = cleanGame.match(/Game mode is (on|off)\./i);
	if (!gameMatch) throw new Error("gamepolicyctl returned an unknown state.");
	const gameMode = gameMatch[1]?.toLowerCase() === "on" ? "on" : "off";
	const gamePolicy = /forced always on/i.test(cleanGame)
		? "on"
		: /enablement policy is currently enabled|automatic|\bauto\b/i.test(
					cleanGame,
				)
			? "auto"
			: "unknown";
	return { gameMode, gamePolicy };
};

export const buildSystemState = (
	awdl: "down" | "up",
	gameMode: "off" | "on",
	gamePolicy: "auto" | "on" | "unknown",
	xcode: XcodeProbe,
): SystemState => {
	const gameModeChecked = gameMode === "on";
	const noAirDropChecked = awdl === "down";
	const policy =
		gamePolicy === "unknown" ? "unknown policy" : `${gamePolicy} policy`;
	return {
		awdl,
		detail: `AWDL ${awdl} • Game Mode ${gameMode} (${policy})`,
		gameMode,
		gameModeChecked,
		gamePolicy,
		noAirDropChecked,
		xcode,
	};
};

export const parseState = (
	awdlOutput: string,
	gameOutput: string,
	xcode: XcodeProbe = { available: true, reason: "", statusOutput: gameOutput },
): SystemState => {
	const awdl = awdlFromOutput(awdlOutput);
	const { gameMode, gamePolicy } = parseGameOutput(gameOutput);
	return buildSystemState(awdl, gameMode, gamePolicy, xcode);
};

export const probeXcode = async (
	paths: Paths,
	run: Runner,
): Promise<XcodeProbe> => {
	const executable = await run([paths.test, "-x", paths.gamepolicy]);
	if (executable.exitCode !== 0) {
		return {
			available: false,
			reason: "Install full Xcode in /Applications.",
			statusOutput: "",
		};
	}
	const status = await run([paths.gamepolicy, "game-mode", "status"]);
	if (status.exitCode !== 0) {
		const detail = [status.stderr, status.stdout].filter(Boolean).join(" ");
		return {
			available: false,
			reason: detail
				? `gamepolicyctl game-mode status failed: ${detail}`
				: "gamepolicyctl game-mode status failed.",
			statusOutput: "",
		};
	}
	return {
		available: true,
		reason: "",
		statusOutput: status.stdout,
	};
};

export const readState = async (paths: Paths, run: Runner) => {
	const awdl = await run([paths.ifconfig, "awdl0"]);
	requireSuccess(
		[paths.ifconfig, "awdl0"],
		awdl,
		"The awdl0 interface is unavailable.",
	);
	const xcode = await probeXcode(paths, run);
	const awdlState = awdlFromOutput(awdl.stdout);
	if (!xcode.available) {
		return buildSystemState(awdlState, "off", "unknown", xcode);
	}
	return parseState(awdl.stdout, xcode.statusOutput, xcode);
};

export const sudoersRule = (user: string, ifconfig: string) =>
	`${user} ALL=(root) NOPASSWD: ${ifconfig} awdl0 down, ${ifconfig} awdl0 up\n`;

export type Prerequisites = {
	awdlAuth: { action?: "installSudoers"; ok: boolean };
	xcode: { action?: "openAppStore"; ok: boolean; reason: string };
};

export const buildPrerequisites = (
	state: SystemState,
	authorization: boolean,
): Prerequisites => ({
	awdlAuth: authorization
		? { ok: true }
		: { action: "installSudoers", ok: false },
	xcode: state.xcode.available
		? { ok: true, reason: "" }
		: {
				action: "openAppStore",
				ok: false,
				reason: state.xcode.reason || "Install full Xcode in /Applications.",
			},
});

export const authorizationReady = async (paths: Paths, run: Runner) => {
	const awdl = await run([paths.ifconfig, "awdl0"]);
	if (awdl.exitCode !== 0) return false;
	const target = awdlFromOutput(awdl.stdout);
	const probe = await run([paths.sudo, "-n", paths.ifconfig, "awdl0", target]);
	return probe.exitCode === 0;
};

const shellQuote = (value: string) => `'${value.replaceAll("'", `'"'"'`)}'`;
const appleQuote = (value: string) =>
	`"${value.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}"`;

export const installAuthorization = async (
	paths: Paths,
	run: Runner,
	user: string,
) => {
	if (!/^[A-Za-z0-9._-]+$/.test(user))
		throw new Error("Unsupported macOS account name.");
	const temporary = await run([
		paths.mktemp,
		`${Bun.env.TMPDIR ?? "/tmp"}/gamemode-bar-awdl.XXXXXX`,
	]);
	requireSuccess(
		[paths.mktemp],
		temporary,
		"Could not create the sudoers staging file.",
	);
	const file = temporary.stdout;
	const rule = sudoersRule(user, paths.ifconfig);
	try {
		await Bun.write(file, rule);
		requireSuccess(
			[paths.chmod, "600", file],
			await run([paths.chmod, "600", file]),
			"Could not secure staging file.",
		);
		requireSuccess(
			[paths.visudo, "-cf", file],
			await run([paths.visudo, "-cf", file]),
			"The sudoers rule failed visudo validation.",
		);
		const command = [
			`${shellQuote(paths.visudo)} -cf ${shellQuote(file)}`,
			`${shellQuote(paths.install)} -o root -g wheel -m 0440 ${shellQuote(file)} ${shellQuote(paths.sudoers)}`,
			`${shellQuote(paths.visudo)} -cf ${shellQuote(paths.sudoers)}`,
			`${shellQuote(paths.cmp)} -s ${shellQuote(file)} ${shellQuote(paths.sudoers)}`,
		].join(" && ");
		const authorizationCommand = [
			paths.osascript,
			"-e",
			`do shell script ${appleQuote(command)} with administrator privileges`,
		];
		requireSuccess(
			authorizationCommand,
			await run(authorizationCommand),
			"Authorization was cancelled or the sudoers rule could not be installed.",
		);
		if (!(await authorizationReady(paths, run)))
			throw new Error(
				"The AWDL rule was installed but passwordless ifconfig did not work.",
			);
	} finally {
		await run([paths.rm, "-f", file]);
	}
};

const runAwdl = async (paths: Paths, run: Runner, mode: "down" | "up") => {
	const command = [paths.sudo, "-n", paths.ifconfig, "awdl0", mode];
	requireSuccess(command, await run(command), `Could not set AWDL ${mode}.`);
};

const runGamePolicy = async (
	paths: Paths,
	run: Runner,
	mode: "auto" | "on",
) => {
	const command = [paths.gamepolicy, "game-mode", "set", mode];
	requireSuccess(
		command,
		await run(command),
		`Could not set Game Mode ${mode}.`,
	);
};

const restoreGame = async (
	paths: Paths,
	run: Runner,
	state: SystemState,
	errors: string[],
) => {
	if (!state.xcode.available) return;
	try {
		await runGamePolicy(paths, run, state.gamePolicy === "on" ? "on" : "auto");
	} catch (error) {
		errors.push(error instanceof Error ? error.message : String(error));
	}
};

const restoreAwdl = async (
	paths: Paths,
	run: Runner,
	awdl: "down" | "up",
	errors: string[],
) => {
	try {
		await runAwdl(paths, run, awdl);
	} catch (error) {
		errors.push(error instanceof Error ? error.message : String(error));
	}
};

const transitionFailure = async (
	paths: Paths,
	run: Runner,
	message: string,
	cause: unknown,
	rollback: () => Promise<string[]>,
): Promise<never> => {
	const rollbackErrors = await rollback();
	let finalState: SystemState | null = null;
	try {
		finalState = await readState(paths, run);
	} catch (readError) {
		rollbackErrors.push(
			`Final state could not be read: ${readError instanceof Error ? readError.message : String(readError)}`,
		);
	}
	const causeMessage = cause instanceof Error ? cause.message : String(cause);
	throw new TransitionError(
		message,
		[
			causeMessage,
			rollbackErrors.length
				? `Rollback issues: ${rollbackErrors.join(" ")}`
				: "The previous setting was restored and re-read.",
		].join("\n"),
		finalState,
	);
};

export const allAvailableOn = (state: SystemState) => {
	const gameOn = state.xcode.available ? state.gameModeChecked : true;
	return gameOn && state.noAirDropChecked;
};

export const setAwdlMode = async (
	paths: Paths,
	run: Runner,
	mode: "down" | "up",
) => {
	const initial = await readState(paths, run);
	const previous = initial.awdl;
	if (previous === mode) return initial;
	try {
		await runAwdl(paths, run, mode);
		return await readState(paths, run);
	} catch (error) {
		return transitionFailure(
			paths,
			run,
			mode === "down"
				? "No AirDrop could not be enabled."
				: "No AirDrop could not be disabled.",
			error,
			async () => {
				const errors: string[] = [];
				await restoreAwdl(paths, run, previous, errors);
				return errors;
			},
		);
	}
};

export const setGameModePolicy = async (
	paths: Paths,
	run: Runner,
	mode: "auto" | "on",
) => {
	const initial = await readState(paths, run);
	if (!initial.xcode.available)
		throw new TransitionError(
			"macOS Game Mode is unavailable.",
			initial.xcode.reason || "Install full Xcode in /Applications.",
			initial,
		);
	const previousPolicy =
		initial.gamePolicy === "on"
			? "on"
			: initial.gamePolicy === "auto"
				? "auto"
				: mode === "on"
					? "auto"
					: "auto";
	try {
		await runGamePolicy(paths, run, mode);
		return await readState(paths, run);
	} catch (error) {
		return transitionFailure(
			paths,
			run,
			mode === "on"
				? "macOS Game Mode could not be enabled."
				: "macOS Game Mode could not be restored to automatic.",
			error,
			async () => {
				const errors: string[] = [];
				const rollbackState = { ...initial, gamePolicy: previousPolicy };
				await restoreGame(paths, run, rollbackState, errors);
				return errors;
			},
		);
	}
};

export type ToggleResult = {
	state: SystemState;
	warnings: string[];
};

export const toggleMode = async (
	paths: Paths,
	run: Runner,
): Promise<ToggleResult> => {
	const initial = await readState(paths, run);
	const disabling = allAvailableOn(initial);
	const warnings: string[] = [];
	try {
		if (disabling) {
			await runAwdl(paths, run, "up");
			if (initial.xcode.available) {
				await runGamePolicy(paths, run, "auto");
			}
		} else {
			await runAwdl(paths, run, "down");
			if (initial.xcode.available) {
				await runGamePolicy(paths, run, "on");
			} else {
				warnings.push(initial.xcode.reason);
			}
		}
		return { state: await readState(paths, run), warnings };
	} catch (error) {
		if (error instanceof TransitionError) throw error;
		return transitionFailure(
			paths,
			run,
			disabling
				? "Game Mode Bar could not turn everything off."
				: "Game Mode Bar could not turn everything on.",
			error,
			async () => {
				const errors: string[] = [];
				await restoreAwdl(paths, run, initial.awdl, errors);
				await restoreGame(paths, run, initial, errors);
				return errors;
			},
		);
	}
};
