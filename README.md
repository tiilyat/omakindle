# omakindle

Send a book file to your Kindle from the Omarchy menu or the bar.

## Install

```sh
omarchy plugin add https://github.com/tiilyat/omakindle --enable
```

The `Kindle` menu entry appears when the bar widget first loads.

## Before the first send

Amazon accepts mail only from approved senders.
Open Amazon's Personal Document Settings and add the email address you will send from to the Approved Personal Document E-mail List.
On the first send Amazon may email you a confirmation request; accept it, or the book is not delivered.

Gmail and Outlook need an app password, not your account password.
Create one in your account's security settings and enter it in the setup form.
Both presets use port 587 with STARTTLS: Gmail `smtp.gmail.com`, Outlook `smtp.office365.com`.
`Other` asks for SMTP host, port and login.

## Use

The first send opens the setup form: provider, Kindle address, email, password.
A test email to your own address must succeed before anything is saved.

The `Kindle` menu offers:
- `Send file…` — pick a file and send it.
- `Settings…` — reopen the setup form; an empty field keeps the stored value.

The bar widget shows `󰂺`, red after a failed send.
Clicking it opens the widget panel with the last send's state, message, file, time and error class.
The panel offers `Send file…` (`Set up…` before setup), `Settings…`, and `Log` after a failure.

Each send ends with a notification, unless you cancel the file dialog or another send is already running.

### From a terminal

```sh
~/.config/omarchy/plugins/io.github.tiilyat.omakindle/bin/omakindle send [file]
~/.config/omarchy/plugins/io.github.tiilyat.omakindle/bin/omakindle setup
~/.config/omarchy/plugins/io.github.tiilyat.omakindle/bin/omakindle install-menu
```

Without a file, `send` opens a file dialog.
`install-menu` rewrites the `Kindle` menu entry; the widget runs it for you, so use it only to restore the entry.

## Files

Accepted formats: `epub pdf doc docx txt rtf htm html png gif jpg jpeg bmp`.
Files over 50 MB are rejected before any connection.

"Sent" means your mail server accepted the message.
Amazon may still reject the file later; that rejection arrives as an email to the sender address.

| Exit code | Outcome |
|---|---|
| 0 | sent, or nothing to report (cancelled dialog, `setup` or `install-menu` finished) |
| 1 | usage error, or `setup` or `install-menu` could not write or refused to change its file |
| 2 | not-configured |
| 3 | file-rejected (format, size, missing or unreadable) |
| 4 | auth-failed |
| 5 | network |
| 6 | send-failed |
| 7 | already-sending |

## Where things live

| What | Path |
|---|---|
| Config | `~/.config/omakindle/config` |
| Password | keyring via `secret-tool`, label "omakindle SMTP password"; if the keyring is unavailable, `~/.config/omakindle/secret` (mode 0600) |
| Status file | `$XDG_STATE_HOME/omakindle/status.json` |
| Log of the last send or setup test | `$XDG_STATE_HOME/omakindle/last-send.log` (password redacted) |

`$XDG_STATE_HOME` defaults to `~/.local/state`.

## Limits

- SMTP over STARTTLS only; providers that offer only port 465 or plain SMTP do not work.
- No format conversion.
- One send at a time.

## Update

```sh
omarchy plugin update
```

## Remove

```sh
omarchy plugin remove io.github.tiilyat.omakindle
```

Omarchy has no uninstall hook, so the menu entry stays.
Delete it by hand from `~/.config/omarchy/extensions/omarchy-menu.jsonc`: everything between `// omakindle:begin` and `// omakindle:end`, markers included.
Config, password and state are not removed either.
If you reinstall later, also delete `$XDG_STATE_HOME/omakindle/menu-version`, or the menu entry will not come back.

## Development

`tests/run` runs shellcheck and the bats suite.
It needs `bats`, `bats-assert` and `shellcheck`.
