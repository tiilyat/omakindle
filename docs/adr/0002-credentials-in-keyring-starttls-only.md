# 0002 — Password lives in the keyring; SMTP is STARTTLS only

Status: accepted (2026-10-13). Decided in [omakindle#6](https://github.com/tiilyat/omakindle/issues/6), building on [#4](https://github.com/tiilyat/omakindle/issues/4).

## Decision
The SMTP password is stored with `secret-tool` (libsecret, gnome-keyring). Only if that store call fails is it written to `~/.config/omakindle/secret` at mode 0600, with a one-time warning. Non-secret values live in `~/.config/omakindle/config` as `KEY=value`. Every SMTP connection uses STARTTLS (`curl --ssl-reqd`); there is no transport setting.

## Drivers
- Omarchy's plugin schema has no secret type and `shell.json` is readable by every unsandboxed plugin, so a password cannot be a widget setting.
- gnome-keyring is in the Omarchy base packages and runs by default; a stock install never needs the fallback.
- One transport removes a field from the setup form and a class of misconfiguration; Gmail and Outlook both serve 587/STARTTLS.

## Alternatives rejected
- Password in plugin settings: visible to any plugin, no secret type.
- Keyring only, no fallback: a headless or broken-keyring session would be unable to configure at all.
- TLS mode field (STARTTLS / implicit / none): more to explain than it saves; implicit TLS on 465 can be added behind the same config key later.

## Consequences
- A user whose provider only offers port 465 cannot use v1.
- The read path is two-step (keyring, then file); both must be tried on every send.
