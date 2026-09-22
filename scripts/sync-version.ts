import { readFile, writeFile } from "node:fs/promises";

const root = `${import.meta.dir}/..`;
const packageJsonPath = `${root}/package.json`;
const infoPlistPath = `${root}/src/native/Info.plist`;

const packageJson = JSON.parse(await readFile(packageJsonPath, "utf8")) as {
	version: string;
};
const version = packageJson.version;

let plist = await readFile(infoPlistPath, "utf8");
plist = plist.replace(
	/(<key>CFBundleShortVersionString<\/key>\s*<string>)[^<]+(<\/string>)/,
	`$1${version}$2`,
);
plist = plist.replace(
	/(<key>CFBundleVersion<\/key>\s*<string>)[^<]+(<\/string>)/,
	`$1${version}$2`,
);
await writeFile(infoPlistPath, plist);
