#!/usr/bin/env bash
set -euo pipefail
dir="${XDG_STATE_HOME:-$HOME/.local/state}/omakindle"
status="$dir/status.json"

write() {
  local tmp
  (umask 077; mkdir -p "$dir")
  tmp="$(mktemp "$dir/status.XXXXXX")"
  jq -n --arg state "$1" --arg class "$2" --arg file "$3" --arg message "$4" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    'def nullable: if . == "" then null else . end;
     {state: $state, error_class: ($class | nullable), file: ($file | nullable), at: $at, message: ($message | nullable)}' >"$tmp" ||
    { rm -f "$tmp"; exit 1; }
  mv "$tmp" "$status"
}

case "${1:-}" in
  idle)
    write idle "" "" ""
    echo "Bar: glyph in bar foreground. Panel: Kindle · Ready; no message; no LAST SEND; buttons Send file…, Settings…" ;;
  sending)
    write sending "" "war-and-peace.epub" ""
    echo "Bar: glyph in bar foreground. Panel: Kindle · Sending…; LAST SEND File war-and-peace.epub, When <now>, no Error; buttons Send file…, Settings…" ;;
  sent)
    write sent "" "war-and-peace.epub" "Sent war-and-peace.epub to reader@kindle.com"
    echo "Bar: glyph in bar foreground. Panel: Kindle · Sent; message 'Sent war-and-peace.epub to reader@kindle.com'; LAST SEND File, When, no Error; buttons Send file…, Settings…" ;;
  error)
    write error auth-failed "war-and-peace.epub" "Mail login failed — check Settings…"
    echo "Bar: glyph in urgent colour. Panel: Kindle · Failed · auth-failed (urgent); message in urgent; LAST SEND File, When, Error auth-failed; buttons Send file…, Settings…, Log (Log opens last-send.log in the editor)" ;;
  not-configured)
    write not-configured not-configured "book.epub" "Kindle is not set up yet"
    echo "Bar: glyph in bar foreground. Panel: Kindle · Not set up; message 'Kindle is not set up yet'; LAST SEND File book.epub, When <now>, Error not-configured; buttons Set up…, Settings…" ;;
  rm)
    rm -f "$status"
    echo "Bar: glyph in bar foreground. Panel: Kindle · Not set up; message 'Kindle is not set up yet'; no LAST SEND; buttons Set up…, Settings… (AC6.3)" ;;
  rmdir)
    rm -rf "$dir"
    echo "Bar: glyph in bar foreground. Panel: Kindle · Not set up; message 'Kindle is not set up yet'; no LAST SEND; buttons Set up…, Settings…; the widget recreates $dir (mode 700) and the next scenario still shows up" ;;
  *)
    echo "usage: $0 idle|sending|sent|error|not-configured|rm|rmdir" >&2
    exit 1 ;;
esac
echo "Change must appear without a shell restart (AC6.5)."
