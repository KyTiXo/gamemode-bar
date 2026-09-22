import { cp, mkdir, rm } from "node:fs/promises";

const root = `${import.meta.dir}/..`;
const mode = Bun.argv[2] ?? "debug";
const debug = `${root}/build/debug`;
const app = `${root}/build/Game Mode Bar.app`;

const run = async (command: string[]) => {
	const child = Bun.spawn(command, { stderr: "inherit", stdout: "inherit" });
	if ((await child.exited) !== 0) process.exit(1);
};

const sips = async (size: number, dest: string) => {
	const child = Bun.spawn(
		[
			"sips",
			"-z",
			String(size),
			String(size),
			`${root}/src/native/icon.png`,
			"--out",
			dest,
		],
		{ stderr: "inherit", stdout: "ignore" },
	);
	if ((await child.exited) !== 0) process.exit(1);
};

await run(["bun", "run", "scripts/sync-version.ts"]);

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
	"-framework",
	"ServiceManagement",
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

const iconset = `${debug}/AppIcon.iconset`;
await mkdir(iconset, { recursive: true });
const iconSizes: Array<[number, string]> = [
	[16, "icon_16x16.png"],
	[32, "icon_16x16@2x.png"],
	[32, "icon_32x32.png"],
	[64, "icon_32x32@2x.png"],
	[128, "icon_128x128.png"],
	[256, "icon_128x128@2x.png"],
	[256, "icon_256x256.png"],
	[512, "icon_256x256@2x.png"],
	[512, "icon_512x512.png"],
	[1024, "icon_512x512@2x.png"],
];
for (const [size, name] of iconSizes) await sips(size, `${iconset}/${name}`);
await run([
	"iconutil",
	"-c",
	"icns",
	iconset,
	"-o",
	`${app}/Contents/Resources/AppIcon.icns`,
]);

await run(["/usr/bin/codesign", "--force", "--deep", "--sign", "-", app]);
