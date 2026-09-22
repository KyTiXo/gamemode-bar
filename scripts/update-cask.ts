import { readFile, writeFile } from "node:fs/promises";

const root = `${import.meta.dir}/..`;
const caskPath = `${root}/Casks/gamemode-bar.rb`;

const version = Bun.argv[2];
const sha256 = Bun.argv[3];

if (!version || !sha256 || !/^[a-f0-9]{64}$/.test(sha256)) {
	console.error("Usage: bun run scripts/update-cask.ts <version> <sha256>");
	process.exit(1);
}

let cask = await readFile(caskPath, "utf8");
cask = cask.replace(/^\s*version "[^"]+"/m, `  version "${version}"`);
cask = cask.replace(/^\s*sha256 "[^"]+"/m, `  sha256 "${sha256}"`);
await writeFile(caskPath, cask);

console.log(`Updated Casks/gamemode-bar.rb to ${version}`);
