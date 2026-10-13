# Process standard

Rules a reviewer checks on every diff. Each rule names its observable condition and its why.

## Writing files

1. A file another process reads (`omarchy-menu.jsonc`, config, secret, the installed CLI) is written to a `mktemp` file in the same directory and then `mv`-ed over the target. Why: Omarchy's menu parser reads a half-written file as garbage and drops it silently, and a running send reads its script while it executes. Pass: no `>"$target"` redirect on such a file in the diff.
2. A Bash function invoked as `f || …` runs with errexit suspended; every write step inside it checks its own status (`|| return 1`). Why: a failed `printf` there is otherwise ignored and a truncated file is installed as success. Pass: each redirect inside such a function has an explicit status check.

## Tests

3. Every expected value in a test comes from the ticket or spec text, never from the implementation's output. Why: a test that copies the output cannot fail (the empty Settings icon passed review until the ticket was re-read). Pass: the reviewer can recompute the literal from the ticket.
4. `tests/run` is the single test entry point; external tools are substituted only by PATH shims in `tests/helpers.bash`, never by hooks in the CLI. Why: stock Omarchy ships nothing beyond curl, zenity, secret-tool, notify-send, so `bin/omakindle` and `install.sh` must run unmodified as tested. Pass: `bin/omakindle` and `install.sh` contain no test-only branch; `OMAKINDLE_REF` is the only variable that changes what install.sh fetches, and README documents it.

## Live checks (consult when a change touches install.sh or the menu)

5. Push the branch and run `curl -fsSL https://raw.githubusercontent.com/tiilyat/omakindle/<branch>/install.sh | OMAKINDLE_REF=<branch> sh`; after merge, run the README install line. Done when `cmp bin/omakindle ~/.local/bin/omakindle` succeeds on the pushed commit and, after `omarchy menu refresh`, the Omarchy menu shows `Kindle` with `Send file…` and `Settings…`.
