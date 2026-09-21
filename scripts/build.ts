import { cp, mkdir, rm } from "node:fs/promises";

const root = `${import.meta.dir}/..`;
const mode = Bun.argv[2] ?? "debug";
const debug = `${root}/build/debug`;
const app = `${root}/build/Game Mode Bar.app`;

const run = async (command: string[]) => {
	const child = Bun.spawn(command, { stderr: "inherit", stdout: "inherit" });
	if ((await child.exited) !== 0) process.exit(1);
};

await rm(debug, { force: true, recursive: true });
await mkdir(debug, { recursive: true });
await run([
	"bun",
	"build",
	`${root}/src/controller.ts`,
	"--target=bun",
	`--outfile=${debug}/controller.js`,
]);
await run([
	"swiftc",
	"-framework",
	"AppKit",
	...(mode === "debug" ? ["-g"] : ["-O"]),
	"-target",
	"arm64-apple-macos14.0",
	`${root}/src/native/GameModeBar.swift`,
	"-o",
	`${debug}/GameModeBar`,
]);

if (mode === "debug") process.exit(0);
if (mode !== "app") throw new Error("Expected build mode: debug or app.");

await rm(app, { force: true, recursive: true });
await mkdir(`${app}/Contents/MacOS`, { recursive: true });
await cp(`${root}/src/native/Info.plist`, `${app}/Contents/Info.plist`);
await cp(`${debug}/GameModeBar`, `${app}/Contents/MacOS/GameModeBar`);
await mkdir(`${app}/Contents/Resources`, { recursive: true });
await cp(`${debug}/controller.js`, `${app}/Contents/Resources/controller.js`);
await run(["/usr/bin/codesign", "--force", "--deep", "--sign", "-", app]);
