# Game Mode Bar (moonlight-mode)

- Workspace: `/Users/kytix/Desktop/shadps4/moonlight-mode`.
- Local menu-bar install: `build/Game Mode Bar.app` (bundle id `dev.kytix.gamemode-bar`).

## After code changes

Menu UI must stay the standard AppKit `NSMenu` on the status item. Do not replace it with a custom `NSPopover` or hand-drawn panel unless the user explicitly asks.

When you change Swift UI, `src/controller.ts`, `src/core.ts`, or build scripts, **always** replace the running app:

```sh
bun run install:local
```

That rebuilds the `.app`, quits any running Game Mode Bar, and launches the new build. Do not leave the user on an old binary or only `build:debug` unless they explicitly ask for the debug executable.

## Versioning

Husky + commitlint only **validate** [Conventional Commits](https://www.conventionalcommits.org/) message shape (`commit-msg` hook). They do **not** bump semver.

When cutting a release, run `bun run release` (standard-version from commits since the last tag), then push with the generated tag. `scripts/sync-version.ts` keeps `src/native/Info.plist` aligned with `package.json` on build.
