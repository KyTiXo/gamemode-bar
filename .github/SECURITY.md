# Security

Game Mode Bar installs one narrow sudoers rule: passwordless `ifconfig awdl0 up/down` for No AirDrop, validated with `visudo`. The app does not store your admin password.

## Reporting

Please **do not** open public issues for security-sensitive problems (privilege escalation, unexpected root access, malicious install paths, etc.).

Prefer **[GitHub private vulnerability reporting](https://github.com/KyTiXo/gamemode-bar/security/advisories/new)** on this repository. That keeps details off the public issue tracker until there is a fix.

If private reporting is unavailable, open a minimal public issue asking for a private channel — do not paste exploit steps or full sudoers contents in the thread.

## Safe to discuss in public

General questions about how authorization works, what the sudoers line allows, or whether a behavior is expected. Redact account names and machine-specific paths if you paste logs.

## Out of scope

Vulnerabilities in macOS, Xcode, Bun, or Homebrew themselves — report those to the upstream vendor.
