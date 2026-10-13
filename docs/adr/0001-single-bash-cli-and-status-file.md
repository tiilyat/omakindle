# 0001 — One Bash CLI sends; a status file is the only channel to the widget

Status: superseded by 0006 (2026-10-14). Decided in [omakindle#5](https://github.com/tiilyat/omakindle/issues/5).

## Decision
The sending logic is a Bash script, `omakindle send [file]`, using `curl` for SMTP. Both launch surfaces (omarchy-menu entry and bar widget) spawn this one CLI. There is no `service`-kind plugin. The CLI writes `$XDG_STATE_HOME/omakindle/status.json`; the QML widget observes it with `FileView`. Sends are serialised with `flock` on `send.lock` in the same directory.

## Drivers
- A public plugin must run on a stock Omarchy install: `curl` and `zenity` are there, `msmtp`, `bun`, `node`, `go`, `rustc` are not.
- The widget may be absent from the bar while a send runs from the menu; a file survives that, an IPC push does not.
- One send path keeps the SMTP, secret and error logic in one place, testable from a terminal.

## Alternatives rejected
- Python `smtplib`: readable, but a second language for one MIME body.
- QML-only sender with the menu calling shell IPC: fails whenever the widget is not loaded.
- IPC push of status into the widget: lost when the widget is not in the bar.
- Unbounded parallel sends: would need per-send state files for no v1 benefit.

## Consequences
- Adding the web backend later (see #3) means a second script behind the same `send` verb, not a redesign.
- The status file shape becomes a contract between CLI and widget; it is specified in #7/#8.
