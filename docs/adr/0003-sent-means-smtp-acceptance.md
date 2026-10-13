# 0003 — Sent means SMTP acceptance; failures are five classes

Status: accepted (2026-10-13). Decided in [omakindle#7](https://github.com/tiilyat/omakindle/issues/7).

## Decision
A send is successful when the SMTP server accepts the message (`curl` exit 0). Delivery to the Kindle is not tracked. Before any network call the sender CLI rejects files with an unaccepted extension or larger than 50 MB. Failures fall into five classes — `not-configured`, `file-rejected`, `auth-failed`, `network`, `send-failed` — each with one user-facing text, one CLI exit code (2–6; 7 is `already-sending`), and one `error_class` value in the status file. Both outcomes raise a `notify-send` notification; the full curl stderr of the last send lands in `$XDG_STATE_HOME/omakindle/last-send.log`, password redacted. The status file holds only the last send.

## Drivers
- Amazon sends no acceptance signal; its rejection arrives by email later, so SMTP acceptance is the last observable point the CLI owns.
- The size and format checks catch the two rejections Amazon documents, before the user waits on an upload that cannot succeed.
- Five classes map one-to-one onto the curl exit codes that need a different user action (reconfigure, fix the file, fix the network, read the log); fewer classes hide the action, more add text nobody acts on.
- Notifications render through omarchy-shell, which already owns `org.freedesktop.Notifications`; the widget alone is invisible when it is not in the bar.

## Alternatives rejected
- Tracking delivery by polling the sender mailbox for Amazon's rejection: a second credential scope (IMAP) and a delay of minutes for a rare case.
- Raw curl message as the only error text: the user cannot tell a typo in the password from an outage.
- History in the status file: no consumer in v1; the widget shows one state.

## Consequences
- A file Amazon rejects for a reason other than size or format still shows `sent`; the user learns it from Amazon's email.
- The 50 MB constant and the extension list must track Amazon's published limits by hand.
