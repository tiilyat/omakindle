---
documentLanguage: en
---

# Glossary

One entry per term: definition, boundaries, one resolved ambiguity. Agents write here the moment a term is settled. Vocabulary here is law for all specs, tickets, and code naming. Ship-specific terms only: a concept any sea chart carries does not get an entry.

## <term>
- Definition:
- Boundary: (is X, not Y)
- Avoid: (near-synonyms this ship does not use)
- Resolved ambiguity:

## sender CLI
- Definition: the `omakindle` Bash script that picks a file, reads the secret, and delivers it over SMTP; the only code path that sends.
- Boundary: is the executable `~/.local/bin/omakindle` the menu entries spawn, installed by the install script; not a shell plugin and not a daemon.
- Avoid: "service", "backend", "daemon".
- Resolved ambiguity: a `service`-kind plugin was rejected for v1 (#5) and again in ADR 0006.

## setup form
- Definition: the two-step `zenity --forms` flow the sender CLI opens on the first send without a config and on `omakindle setup`; it writes config and secret only after a test email to the sender succeeds.
- Boundary: is a CLI dialog, not a plugin `schema` entry.
- Avoid: "wizard", "onboarding", "settings panel".
- Resolved ambiguity: cancel or a failed test writes nothing (#6).

## provider preset
- Definition: a named SMTP host and port pair (`Gmail`, `Outlook`) the setup form offers so the user enters only email and password; `Other` asks for host, port and login.
- Boundary: fixes host and port only, never credentials or transport; transport is always STARTTLS (ADR 0002).
- Avoid: "account type", "profile".
- Resolved ambiguity: for presets the sender address and the login are the entered email (#6).

## send outcome
- Definition: the final state the sender CLI reports for one send: `sent` when the SMTP server accepts the message, otherwise one error class; mirrored by the CLI exit code and the notification.
- Boundary: is SMTP acceptance, not delivery to the device; Amazon's later rejection email is outside it.
- Avoid: "delivered", "success status".
- Resolved ambiguity: `already-sending` (lock held) is an outcome of the invocation, not an error class of a send (#7).

## error class
- Definition: one of `not-configured`, `file-rejected`, `auth-failed`, `network`, `send-failed`; each carries one user-facing text and one CLI exit code.
- Boundary: is the user-action grouping, not the curl exit code; several curl codes fold into one class.
- Avoid: "error code", "failure reason".
- Resolved ambiguity: a raw curl message alone was rejected because it does not tell the user what to do (#7).

## install-menu
- Definition: the `omakindle install-menu` subcommand that idempotently writes the `Kindle` submenu into `~/.config/omarchy/extensions/omarchy-menu.jsonc`, pointing at the sender CLI by absolute path.
- Boundary: is run by the install script on every install and update; a user runs it by hand only to restore a deleted entry.
- Avoid: "menu setup", "register menu", "postinstall".
- Resolved ambiguity: it writes the path it runs from (symlinks kept), not a plugin-folder path, so the entry follows wherever the install script put the CLI (ADR 0006).

## install script
- Definition: `install.sh` at the repository root, run as `curl -fsSL https://raw.githubusercontent.com/tiilyat/omakindle/main/install.sh | sh`; it downloads `bin/omakindle` from `main` (or `OMAKINDLE_REF`) to `~/.local/bin/omakindle` and runs install-menu.
- Boundary: is the only install and update path, not an uninstaller and not a package.
- Avoid: "installer", "bootstrap", "setup script".
- Resolved ambiguity: update is the same line run again; there is no version check (ADR 0006).
