# Contributing

## Read this first

Game Mode Bar is beta software. Not at 1.0 yet. Most changes happen in-house.

You can still open an issue or PR, but there is a real chance we close it, defer it, or never get to it. That is not personal — scope is small on purpose.

Feature ideas are fine as issues; say **feature** in the title. We are not running a formal roadmap.

## What we are most likely to accept

Small, focused bug fixes.

Reliability fixes around Game Mode, AWDL / No AirDrop, or permissions (Xcode, sudoers).

Menu copy or Settings behavior that matches how the app actually works.

Build, cask, or CI fixes that do not change product direction.

## What we are least likely to accept

Large PRs or drive-by features.

Electron, custom popover UI, or anything that replaces the native `NSMenu` status item unless we asked for it.

Broader sudoers rules or extra root powers.

Unrelated refactors mixed with a fix.

## If you open a PR anyway

Keep it small. One concern per PR — if the description says "also", split it.

Use a [Conventional Commits](https://www.conventionalcommits.org/) style title.

Run `bun run check` before you push (or say why you could not).

If you touch Swift, the controller, core, or build scripts, read [AGENTS.md](AGENTS.md) — maintainers expect `bun run install:local` for the live menu-bar app.

Menu or Settings changes: a screenshot in the PR helps.

## Bugs

Use the **Bug report** issue template. Search existing issues first.

## Developing locally

See [README.md](README.md#develop). Agent and maintainer workflow details live in [AGENTS.md](AGENTS.md).

## Be realistic

Opening a PR does not create an obligation on our side. We may close it, ask you to shrink it, or reimplement the idea ourselves later. If that is okay with you, proceed.
