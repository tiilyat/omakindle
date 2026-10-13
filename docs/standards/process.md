# Process standard

Rules a reviewer checks on every diff. Each rule names its observable condition and its why.

## Writing files

1. A file another process reads (the status file, `omarchy-menu.jsonc`, config, secret) is written to a `mktemp` file in the same directory and then `mv`-ed over the target. Why: FileView and Omarchy's menu parser read a half-written file as garbage and drop it silently. Pass: no `>"$target"` redirect on such a file in the diff.
2. A Bash function invoked as `f || …` runs with errexit suspended; every write step inside it checks its own status (`|| return 1`). Why: a failed `printf` there is otherwise ignored and a truncated file is installed as success. Pass: each redirect inside such a function has an explicit status check.

## Tests

3. Every expected value in a test comes from the ticket or spec text, never from the implementation's output. Why: a test that copies the output cannot fail (the empty Settings icon passed review until the ticket was re-read). Pass: the reviewer can recompute the literal from the ticket.
4. `tests/run` is the single test entry point; external tools are substituted only by PATH shims in `tests/helpers.bash`, never by hooks in the CLI. Why: stock Omarchy ships nothing beyond curl, zenity, secret-tool, notify-send, so the shipped code must run unmodified. Pass: `bin/omakindle` contains no test-only branch.

## Live checks (consult when a change touches the widget or the menu)

5. Install the checked-out branch into the real shell with `omarchy plugin add "$PWD" --enable --yes`; the clone takes the current branch. Update it with `omarchy plugin update io.github.tiilyat.omakindle --yes`. Done when the widget appears in the bar and `$XDG_STATE_HOME/omakindle/menu-version` equals the manifest version.
6. Lint QML with `/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell Widget.qml Status.qml` (not on PATH); only errors count, `qs.*` typing warnings are noise. Done when the command reports no error.
7. Walk the widget states with `tests/widget-scenario.sh <state>` and tick each AC6 line by eye; the bar cannot be screenshotted from a script on this machine.
