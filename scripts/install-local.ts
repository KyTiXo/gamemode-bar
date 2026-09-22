import { spawn } from "bun";

const root = `${import.meta.dir}/..`;
const appPath = `${root}/build/Game Mode Bar.app`;
const bundleId = "dev.kytix.gamemode-bar";

const run = async (command: string[], allowFailure = false) => {
	const child = spawn(command, {
		cwd: root,
		stdout: "inherit",
		stderr: "inherit",
	});
	const code = await child.exited;
	if (code !== 0 && !allowFailure) process.exit(code ?? 1);
	return code;
};

await run(["bun", "run", "scripts/build.ts", "app"]);

await run(
	["osascript", "-e", `tell application id "${bundleId}" to quit`],
	true,
);
await run(["pkill", "-x", "GameModeBar"], true);

await Bun.sleep(400);

await run(["open", "-a", appPath]);

console.log(`Installed and launched ${appPath}`);
