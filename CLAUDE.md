# omakindle — Agent & Human Shipyard

## Project conventions
- Stack: one Bash sender CLI (`bin/omakindle`) installed to `~/.local/bin` by `install.sh`; nothing else runs on a stock Omarchy, so no runtime is added (ADR 0006).
- Runtime state goes only to `$XDG_STATE_HOME/omakindle/`; the CLI writes nothing beside itself. Why: `~/.local/bin` is on PATH and is overwritten on every update.
- Tests run through `tests/run` only; tools are faked by PATH shims, never by hooks in the CLI. Why: the shipped script must be the tested script.

## Architecture principles
- Not yet sedimented. Add a principle here the first time a review corrects the same mistake twice; each principle states the observable condition and its why. Done when a reviewer can judge pass/fail from the text alone.

## Code comments
Run this evaluation for every comment introduced in a commit. A comment survives only if it carries knowledge the code cannot express; everything else is weight the reader pays for on every read.

| Comment describes | Verdict |
|---|---|
| function behavior that is obvious from the code | DROP |
| historical changes, including ADR and ticket references | DROP |
| a border condition | DROP |
| an invariant / precondition / postcondition expressible in TypeScript | DROP |
| why we cannot do it another way | RETAIN |
| an invariant / precondition / postcondition not expressible in TypeScript | RETAIN |
| repetition of the same pattern ("same as above") | DROP |
| docblock description | DROP |
| uncertain which row applies | DROP |

Rewrite every RETAINED comment so that it states no historical reason and uses as few words as possible. Done when the comment answers only "why not otherwise" or "what the types cannot say". (Why: history lives in version control and decision records; a comment that repeats it drifts the moment the history moves on.)

## Standards
- Index: docs/standards/ — `process.md` (writing files, tests, live checks). A reviewer checks every rule there on each diff.

## Decision records
- Index: docs/adr/ — one file per decision passing the ADR test (hard to reverse, surprising without context, a real tradeoff). Numbered `NNNN-<slug>.md`, status line first.

## Shared background
- Glossary: GLOSSARY.md
- Issue tracker: https://github.com/tiilyat/omakindle/issues. Maintainer communication authority for intake: issue comments and label changes on that repository.

## Agent guide
- Delivery follows the canonical workflow plan → execute → review → verify; `/oh-my-claudecode:launch` is an optional governed delivery pipeline (opt-in, invoke explicitly)
- On term conflicts GLOSSARY.md wins; new terms are recorded the moment they settle
- When a deferred surface first appears (standards, decision records, business knowledge, project skills, the design system), it gets an index section here at the moment it is created — never before
