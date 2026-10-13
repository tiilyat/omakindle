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
- Boundary: is the executable both launch surfaces spawn, not a shell plugin kind and not a daemon.
- Avoid: "service", "backend", "daemon".
- Resolved ambiguity: a `service`-kind plugin was considered and rejected for v1 (#5).

## status file
- Definition: `$XDG_STATE_HOME/omakindle/status.json`, written by the sender CLI and watched by the bar widget.
- Boundary: is the sole channel from sender to widget, not a log and not a config.
- Avoid: "state file", "IPC status".
- Resolved ambiguity: status is not pushed over shell IPC because the widget may be unloaded while a send runs (#5).
