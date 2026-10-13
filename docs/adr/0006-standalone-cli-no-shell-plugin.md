# 0006 — A standalone CLI in ~/.local/bin, installed by curl | sh; no shell plugin

Status: accepted (2026-10-14).

## Decision
omakindle is one Bash script, `bin/omakindle`, with no shell plugin of any kind. The install script `install.sh` is run as `curl -fsSL https://raw.githubusercontent.com/tiilyat/omakindle/main/install.sh | sh`; it downloads `bin/omakindle` from `main`, or from `OMAKINDLE_REF` when set, into `~/.local/bin/omakindle` (mktemp in the same directory, mode 755, `mv`) and runs `install-menu`. `install-menu` writes the absolute path it runs from (`realpath -s "$0"`). Update is the same line run again. There is no status file, no menu-version marker and no manifest; the state dir holds `last-send.log` and `send.lock`, and the failure notification names the log path. From 0001 remain one Bash CLI, curl for SMTP, `flock` on `send.lock` and no service plugin; from 0004 remain an always-releasable `main` and work landing through branches and pull requests. There is no version number: a commit on `main` is the release, and tags are not required.

## Drivers
- Omarchy's plugin system has no install hook; the bar widget was the only trigger for `install-menu` (0004 Decision), so without it something outside the plugin system must run `install-menu`.
- The widget was the only reader of `status.json` (0001 Consequences).
- The user takes as few steps as possible, and the update path needs no extra explanation.
- Every install behaviour must be testable through `tests/run` with PATH shims.

## Alternatives rejected
- A `service`-kind shell plugin that runs `install-menu` on load: still a shell plugin with `manifest.json`, a QML entry point and a version marker, and the plugin-folder write rule stays.
- `git clone` plus `./install`: two commands to update and two copies on disk, or a menu that points into the clone.
- A fixed `$HOME/.local/bin/omakindle` inside `install-menu`: a copy run from anywhere else points the menu at a file that may not exist.
- Plain `realpath` without `-s`: under symlinked dotfiles the menu points at the dotfiles target instead of `~/.local/bin`.
- A hard-wired `main` with no `OMAKINDLE_REF`: no way to pin a ref, and no live check of `install.sh` before merge.
- An AUR package: a second channel to keep current, and not stock Omarchy tooling.

## Why chosen
It is the only option where a single line both installs and updates, the only addition to PATH is the script, the plugin-folder constraint disappears, and every install behaviour can be tested with the existing curl shim and no test-only code.

## Consequences
- Users pipe a remote script into sh; README points to `install.sh` in the repository so they can read it first.
- There is no version string, so a bug report cannot name a build; the closest identifier is the date of the last install, or the `OMAKINDLE_REF` used.
- `main` HEAD is the release; an update right after a push can fetch the cached previous file for a few minutes.
- Removal is manual (README "Remove").
- ADR 0001 and 0004 are superseded; the status-file and widget statements of ADR 0003 no longer apply. ADR 0002's plugin-settings drivers are moot, but its decision stands.
- Existing plugin installs are not migrated; they are removed by hand with `omarchy plugin remove io.github.tiilyat.omakindle`, then the install line is run and `$XDG_STATE_HOME/omakindle/status.json` and `menu-version` are deleted.

## Follow-ups
- If an issue is opened for this change, link it from the status line as "Decided in".
- Remove the maintainer's plugin install by hand as above.
- Revisit a `--version` output if bug reports start needing to name a build.
