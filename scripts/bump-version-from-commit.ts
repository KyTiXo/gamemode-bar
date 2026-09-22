import { readFile, writeFile } from "node:fs/promises";

const commitMessagePath = process.argv[2];
if (!commitMessagePath) {
	console.error("Usage: bump-version-from-commit.ts <commit-msg-file>");
	process.exit(1);
}

const message = await readFile(commitMessagePath, "utf8");
const firstLine = message.split("\n")[0]?.trim() ?? "";
const header = /^(\w+)(?:\([^)]+\))?!?:\s/.exec(firstLine);
if (!header) process.exit(0);

const type = header[1];
const breaking =
	firstLine.includes("!:") ||
	message.includes("\nBREAKING CHANGE:") ||
	message.includes("\nBREAKING-CHANGE:");

const root = `${import.meta.dir}/..`;
const packageJsonPath = `${root}/package.json`;
const packageJson = JSON.parse(await readFile(packageJsonPath, "utf8")) as {
	version: string;
};
const [major, minor, patch] = packageJson.version.split(".").map(Number);
if ([major, minor, patch].some((part) => Number.isNaN(part))) {
	console.error(`Invalid package.json version: ${packageJson.version}`);
	process.exit(1);
}

let next: string | undefined;
if (breaking) {
	next = `${major + 1}.0.0`;
} else if (type === "feat") {
	next = `${major}.${minor + 1}.0`;
} else if (type === "fix" || type === "perf") {
	next = `${major}.${minor}.${patch + 1}`;
}

if (!next || next === packageJson.version) process.exit(0);

packageJson.version = next;
await writeFile(
	packageJsonPath,
	`${JSON.stringify(packageJson, null, "\t")}\n`,
);
await Bun.spawn(["bun", "run", "scripts/sync-version.ts"], {
	cwd: root,
	stdout: "inherit",
	stderr: "inherit",
}).exited;

console.log(
	`Version bumped to ${next} (${type}${breaking ? ", breaking" : ""})`,
);
