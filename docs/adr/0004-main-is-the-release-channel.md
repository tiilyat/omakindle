# 0004 — One repository, main is the release channel, CLI stays inside the plugin folder

Status: accepted (2026-10-13). Decided in [omakindle#9](https://github.com/tiilyat/omakindle/issues/9).

## Decision
The plugin is this repository, id `io.github.tiilyat.omakindle`, with `manifest.json` at the root; the only install path is `omarchy plugin add https://github.com/tiilyat/omakindle`. `main` is always releasable: work lands through branches and pull requests, releases are semver tags `vX.Y.Z` and the manifest `version` equals the tag. The sender CLI lives at `bin/omakindle` inside the installed plugin folder and is called by absolute path; nothing is placed on PATH. `omakindle install-menu` records the manifest `version` in the state dir, and the widget re-runs it when that marker is missing or differs from the manifest; the marker never lives in the plugin folder, because a write there makes omarchy-shell reload every plugin widget. Shipyard files (docs, glossary, CLAUDE.md) ship inside the installed folder; loft artifacts stay on `loft/*` branches.

## Drivers
- `omarchy plugin update` fetches `origin HEAD` and fast-forwards; it never reads tags, so whatever sits on the default branch is what every user runs after an update.
- `omarchy plugin add` validates `manifest.json` at the clone root, so the plugin cannot live in a subdirectory of a shipyard repo.
- The installed folder path is deterministic (`~/.config/omarchy/plugins/<id>/`), so an absolute path from the menu entry and the widget is stable across updates without touching PATH.
- The Omarchy CLI has no remote catalog; a listing elsewhere adds a second place to keep current with no install benefit.

## Alternatives rejected
- A separate `release` default branch: two branches to keep in step for a one-maintainer plugin.
- A second repository for the plugin code: the paper trail and the code would drift apart.
- Symlinking the CLI into `~/.local/bin` at first run: writes outside the plugin folder that `omarchy plugin remove` does not undo.
- Re-running `install-menu` at every widget load: a write to `omarchy-menu.jsonc` on every shell start for a change that happens once per release.

## Consequences
- A commit on `main` is a release to everyone who runs `omarchy plugin update`; unfinished work must stay on a branch.
- Users receive docs and the glossary in their config folder; they are inert.
- Forgetting to bump `version` on release leaves updated users with the old menu entry until the next bump.
