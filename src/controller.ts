import {
	authorizationReady,
	buildPrerequisites,
	installAuthorization,
	pathsFromEnv,
	readState,
	setAwdlMode,
	setGameModePolicy,
	spawnRunner,
	TransitionError,
	toggleMode,
} from "./core";

const paths = pathsFromEnv();
const user = Bun.env.USER ?? Bun.env.LOGNAME ?? "";

const reply = (value: unknown) => console.log(JSON.stringify(value));

const statusPayload = async () => {
	const [state, authorization] = await Promise.all([
		readState(paths, spawnRunner),
		authorizationReady(paths, spawnRunner),
	]);
	return {
		authorization,
		needsAuthorization: !authorization,
		ok: true,
		prerequisites: buildPrerequisites(state, authorization),
		state,
	};
};

const requireAuthorization = async () => {
	if (await authorizationReady(paths, spawnRunner)) return true;
	reply({
		authorization: false,
		message: "One-time authorization is required for No AirDrop.",
		needsAuthorization: true,
		ok: false,
		state: await readState(paths, spawnRunner),
	});
	return false;
};

try {
	switch (Bun.argv[2] ?? "status") {
		case "status":
			reply(await statusPayload());
			break;
		case "setup":
			await installAuthorization(paths, spawnRunner, user);
			reply(await statusPayload());
			break;
		case "toggle": {
			if (!(await requireAuthorization())) break;
			const result = await toggleMode(paths, spawnRunner);
			reply({
				authorization: true,
				ok: true,
				state: result.state,
				...(result.warnings.length ? { warnings: result.warnings } : {}),
			});
			break;
		}
		case "set-game": {
			const mode = Bun.argv[3];
			if (mode !== "on" && mode !== "auto")
				throw new Error("Expected set-game on or auto.");
			reply({
				ok: true,
				state: await setGameModePolicy(paths, spawnRunner, mode),
			});
			break;
		}
		case "set-awdl": {
			const mode = Bun.argv[3];
			if (mode !== "down" && mode !== "up")
				throw new Error("Expected set-awdl down or up.");
			if (!(await requireAuthorization())) break;
			reply({
				authorization: true,
				ok: true,
				state: await setAwdlMode(paths, spawnRunner, mode),
			});
			break;
		}
		default:
			throw new Error("Expected status, setup, toggle, set-game, or set-awdl.");
	}
} catch (error) {
	const transition = error instanceof TransitionError ? error : null;
	reply({
		detail:
			transition?.detail ??
			(error instanceof Error ? error.message : String(error)),
		message:
			transition?.message ??
			"Game Mode Bar could not read or change the system state.",
		ok: false,
		state: transition?.state ?? null,
	});
}
