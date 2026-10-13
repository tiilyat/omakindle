#!/usr/bin/env bats

load helpers

KINDLE=reader@kindle.com
PASSWORD='s3cr"et\pass'
state_dir() { echo "$XDG_STATE_HOME/omakindle"; }

configure() {
  mkdir -p "$XDG_CONFIG_HOME/omakindle"
  cat >"$XDG_CONFIG_HOME/omakindle/config" <<CONF
PROVIDER=Gmail
KINDLE_ADDRESS=$KINDLE
FROM=me@gmail.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_LOGIN=me@gmail.com
CONF
  printf '%s' "$PASSWORD" >"$SHIM_DIR/secret-tool.out"
}

book() {
  local path="$BATS_TEST_TMPDIR/${1:-book.epub}"
  printf 'book bytes\n' >"$path"
  echo "$path"
}

status() { jq -c "$1" "$(state_dir)/status.json"; }

stderr_is_one_line() {
  [ "$(printf '%s\n' "$stderr" | wc -l)" -eq 1 ]
  [ "$stderr" = "$1" ]
}

@test "AC1.1 send to an accepting server exits 0 and writes sent status" {
  configure
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  run status 'del(.at)'
  assert_output '{"state":"sent","error_class":null,"file":"book.epub","message":"Sent book.epub to reader@kindle.com"}'
  run status '[keys_unsorted[]]'
  assert_output '["state","error_class","file","at","message"]'
  run jq -r .at "$(state_dir)/status.json"
  assert_output --regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
}

@test "AC1.1 without a file argument the zenity file dialog picks it" {
  configure
  book >"$SHIM_DIR/zenity.out"
  run --separate-stderr "$OMAKINDLE" send
  assert_success
  eval "set -- $(sed -n 1p "$SHIM_DIR/zenity.argv")"
  [ "$*" = "--file-selection --title Send to Kindle" ]
  [ "$3" = "Send to Kindle" ]
  run jq -r .state "$(state_dir)/status.json"
  assert_output sent
}

@test "AC1.2 status reads sending with the same file before curl runs" {
  configure
  cat >"$SHIM_DIR/curl" <<SHIM
#!/usr/bin/env bash
cat >/dev/null
cp "$XDG_STATE_HOME/omakindle/status.json" "$SHIM_DIR/curl.status"
SHIM
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  run jq -c '{state, file}' "$SHIM_DIR/curl.status"
  assert_output '{"state":"sending","file":"book.epub"}'
}

@test "AC1.3 success fires exactly one normal notification" {
  configure
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  [ "$(wc -l <"$SHIM_DIR/notify-send.argv")" -eq 1 ]
  eval "set -- $(sed -n 1p "$SHIM_DIR/notify-send.argv")"
  [ "$#" -eq 6 ]
  [ "$1 $2 $3 $4" = "-a omakindle -u normal" ]
  [ "$5" = "Sent" ]
  [ "$6" = "book.epub to $KINDLE" ]
}

@test "AC1.3 failure fires exactly one critical notification" {
  configure
  echo 56 >"$SHIM_DIR/curl.exit"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_failure 6
  [ "$(wc -l <"$SHIM_DIR/notify-send.argv")" -eq 1 ]
  eval "set -- $(sed -n 1p "$SHIM_DIR/notify-send.argv")"
  [ "$#" -eq 6 ]
  [ "$1 $2 $3 $4" = "-a omakindle -u critical" ]
  [ "$5" = "Mail server refused the message — see log" ]
  [ "$6" = "Log: $XDG_STATE_HOME/omakindle/last-send.log" ]
}

@test "AC1.4 cancelling the file dialog exits 0 and writes nothing" {
  configure
  echo 1 >"$SHIM_DIR/zenity.exit"
  run --separate-stderr "$OMAKINDLE" send
  assert_success
  [ ! -e "$(state_dir)/status.json" ]
  [ ! -e "$SHIM_DIR/notify-send.argv" ]
  [ ! -e "$SHIM_DIR/curl.argv" ]
}

@test "missing config and a cancelled setup exit 2 with not-configured status" {
  echo 1 >"$SHIM_DIR/zenity.exit"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_failure 2
  stderr_is_one_line "Kindle is not set up yet"
  run jq -c 'del(.at)' "$(state_dir)/status.json"
  assert_output '{"state":"not-configured","error_class":"not-configured","file":"book.epub","message":"Kindle is not set up yet"}'
  [ ! -e "$SHIM_DIR/curl.argv" ]
}

@test "no secret in keyring or file exits 2 not-configured" {
  configure
  rm "$SHIM_DIR/secret-tool.out"
  echo 1 >"$SHIM_DIR/secret-tool.exit"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_failure 2
  run jq -r .error_class "$(state_dir)/status.json"
  assert_output not-configured
}

@test "secret is looked up in the keyring first" {
  configure
  printf 'filepass' >"$XDG_CONFIG_HOME/omakindle/secret"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  eval "set -- $(sed -n 1p "$SHIM_DIR/secret-tool.argv")"
  [ "$*" = "lookup application omakindle key smtp-password" ]
  grep -qF 's3cr\"et\\pass' "$SHIM_DIR/curl.stdin"
  run ! grep -q filepass "$SHIM_DIR/curl.stdin"
}

@test "secret falls back to the secret file" {
  configure
  rm "$SHIM_DIR/secret-tool.out"
  echo 1 >"$SHIM_DIR/secret-tool.exit"
  printf 'filepass' >"$XDG_CONFIG_HOME/omakindle/secret"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  grep -qF 'user = "me@gmail.com:filepass"' "$SHIM_DIR/curl.stdin"
}

@test "state dir is created with mode 0700" {
  configure
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  run stat -c %a "$(state_dir)"
  assert_output 700
}

@test "AC4.4 password never on curl argv, only on its config stdin" {
  configure
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  [ "$(wc -l <"$SHIM_DIR/curl.argv")" -eq 1 ]
  eval "set -- $(sed -n 1p "$SHIM_DIR/curl.argv")"
  local arg
  for arg in "$@"; do [[ $arg != *s3cr* ]]; done
  [[ " $* " == *" --ssl-reqd "* ]]
  [[ " $* " == *" --url smtp://smtp.gmail.com:587 "* ]]
  [[ " $* " == *" --mail-from me@gmail.com "* ]]
  [[ " $* " == *" --mail-rcpt $KINDLE "* ]]
  [[ " $* " == *" --upload-file "* ]]
  [[ " $* " == *" --max-time 600 "* ]]
  [[ " $* " == *" -K - "* ]]
  [[ " $* " == *" -sS "* ]]
  [[ " $* " == *" -v "* ]]
  run cat "$SHIM_DIR/curl.stdin"
  assert_output 'user = "me@gmail.com:s3cr\"et\\pass"'
}

@test "MIME message is multipart/mixed with a base64 attachment" {
  configure
  local path
  path="$(book 'Kniga книга.epub')"
  run --separate-stderr "$OMAKINDLE" send "$path"
  assert_success
  local mime="$SHIM_DIR/curl.upload"
  grep -q $'^Subject: omakindle\r$' "$mime"
  grep -q $'^From: me@gmail.com\r$' "$mime"
  grep -q $'^To: reader@kindle.com\r$' "$mime"
  grep -qE $'^Date: [A-Z][a-z]{2}, [0-9]{2} [A-Z][a-z]{2} [0-9]{4} [0-9:]{8} [+-][0-9]{4}\r$' "$mime"
  grep -qE $'^Message-ID: <[0-9a-f-]{36}@omakindle>\r$' "$mime"
  grep -q '^Content-Type: multipart/mixed; boundary=' "$mime"
  grep -q $'^Content-Type: application/epub+zip; name="Kniga __________.epub"\r$' "$mime"
  grep -q '^Content-Transfer-Encoding: base64' "$mime"
  grep -q 'filename="Kniga __________.epub"' "$mime"
  run ! env LC_ALL=C grep -q '[^ -~[:space:]]' "$mime"
  local encoded
  encoded="$(sed -n '/^Content-Transfer-Encoding: base64/,/^--/p' "$mime" | sed '1,2d;$d' | tr -d '\r')"
  [ "$(printf '%s\n' "$encoded" | base64 -d)" = "book bytes" ]
}

disposition() {
  configure
  run --separate-stderr "$OMAKINDLE" send "$(book "$1")"
  assert_success
  sed -n '/^Content-Disposition: /,/^Content-Transfer-Encoding: /p' "$SHIM_DIR/curl.upload" | sed '$d'
}

@test "MIME attachment Content-Type follows the lowercase extension" {
  configure
  local ext type
  while read -r ext type; do
    run --separate-stderr "$OMAKINDLE" send "$(book "b.$ext")"
    assert_success
    grep -q "^Content-Type: $type; name=\"b.$ext\""$'\r$' "$SHIM_DIR/curl.upload"
  done <<'TYPES'
epub application/epub+zip
EPUB application/epub+zip
pdf application/pdf
doc application/msword
docx application/vnd.openxmlformats-officedocument.wordprocessingml.document
txt text/plain
rtf application/rtf
htm text/html
html text/html
png image/png
gif image/gif
jpg image/jpeg
JPEG image/jpeg
bmp image/bmp
TYPES
}

@test "MIME lines end in CRLF and base64 lines are at most 76 characters" {
  configure
  local path
  path="$BATS_TEST_TMPDIR/big.pdf"
  head -c 3000 /dev/urandom >"$path"
  run --separate-stderr "$OMAKINDLE" send "$path"
  assert_success
  local mime="$SHIM_DIR/curl.upload"
  run grep -c -v $'\r$' "$mime"
  assert_output 0
  local encoded
  encoded="$(sed -n '/^Content-Transfer-Encoding: base64/,/^--/p' "$mime" | sed '1,2d;$d' | tr -d '\r')"
  [ "$(printf '%s\n' "$encoded" | wc -l)" -gt 1 ]
  run awk 'length > 76' <<<"$encoded"
  assert_output ''
  cmp <(printf '%s\n' "$encoded" | base64 -d) "$path"
}

@test "MIME Content-Disposition carries the RFC 2231 UTF-8 filename next to the ASCII fallback" {
  run disposition 'Книга тест.epub'
  assert_output $'Content-Disposition: attachment; filename="__________ ________.epub"; filename*=UTF-8\'\'%D0%9A%D0%BD%D0%B8%D0%B3%D0%B0%20%D1%82%D0%B5%D1%81%D1%82.epub\r'
  grep -q $'^Content-Type: application/epub+zip; name="__________ ________.epub"\r$' "$SHIM_DIR/curl.upload"
}

@test "MIME Content-Disposition for an ASCII name repeats it in filename*" {
  run disposition 'book-1_v2.0~x.epub'
  assert_output $'Content-Disposition: attachment; filename="book-1_v2.0~x.epub"; filename*=UTF-8\'\'book-1_v2.0~x.epub\r'
}

@test "MIME Content-Disposition percent-encodes quote, semicolon and other reserved bytes" {
  run disposition $'O\'Neil; "a\\b" (c)*.epub'
  assert_output $'Content-Disposition: attachment; filename="O\'Neil; _a_b_ (c)*.epub"; filename*=UTF-8\'\'O%27Neil%3B%20%22a%5Cb%22%20%28c%29%2A.epub\r'
}

@test "MIME Content-Disposition folds filename* onto a continuation line past 900 bytes" {
  local name
  name="$(printf 'ж%.0s' {1..120}).epub"
  run disposition "$name"
  assert_equal "${#lines[@]}" 2
  assert_equal "${lines[0]}" "Content-Disposition: attachment; filename=\"$(printf '_%.0s' {1..240}).epub\";"$'\r'
  assert_equal "${lines[1]}" " filename*=UTF-8''$(printf '%%D0%%B6%.0s' {1..120}).epub"$'\r'
}

@test "AC3.1 unsupported extension exits 3 before any connection" {
  configure
  run --separate-stderr "$OMAKINDLE" send "$(book book.mobi)"
  assert_failure 3
  stderr_is_one_line "book.mobi: unsupported format or over 50 MB"
  run jq -c 'del(.at)' "$(state_dir)/status.json"
  assert_output '{"state":"error","error_class":"file-rejected","file":"book.mobi","message":"book.mobi: unsupported format or over 50 MB"}'
  [ ! -e "$SHIM_DIR/curl.argv" ]
  [ ! -e "$(state_dir)/last-send.log" ]
}

@test "AC3.1 extension check is case-insensitive" {
  configure
  run --separate-stderr "$OMAKINDLE" send "$(book BOOK.EPUB)"
  assert_success
}

@test "AC3.1 a name without an extension is rejected" {
  configure
  run --separate-stderr "$OMAKINDLE" send "$(book epub)"
  assert_failure 3
}

@test "AC3.2 a file over 52428800 bytes exits 3 before any connection" {
  configure
  local path="$BATS_TEST_TMPDIR/big.pdf"
  truncate -s 52428801 "$path"
  run --separate-stderr "$OMAKINDLE" send "$path"
  assert_failure 3
  run jq -r .error_class "$(state_dir)/status.json"
  assert_output file-rejected
  [ ! -e "$SHIM_DIR/curl.argv" ]
  [ ! -e "$(state_dir)/last-send.log" ]
}

@test "AC3.2 a file of exactly 52428800 bytes is sent" {
  configure
  local path="$BATS_TEST_TMPDIR/edge.pdf"
  truncate -s 52428800 "$path"
  run --separate-stderr "$OMAKINDLE" send "$path"
  assert_success
}

@test "AC3.3 a missing file exits 3 before any connection" {
  configure
  run --separate-stderr "$OMAKINDLE" send "$BATS_TEST_TMPDIR/gone.epub"
  assert_failure 3
  stderr_is_one_line "gone.epub: unsupported format or over 50 MB"
  run jq -r .error_class "$(state_dir)/status.json"
  assert_output file-rejected
  [ ! -e "$SHIM_DIR/curl.argv" ]
  [ ! -e "$(state_dir)/last-send.log" ]
}

@test "AC3.3 an unreadable file exits 3 before any connection" {
  configure
  local path
  path="$(book locked.epub)"
  chmod 000 "$path"
  run --separate-stderr "$OMAKINDLE" send "$path"
  assert_failure 3
  [ ! -e "$SHIM_DIR/curl.argv" ]
}

assert_curl_failure() {
  local curl_code=$1 exit_code=$2 class=$3 message=$4
  rm -f "$SHIM_DIR/notify-send.argv"
  echo "$curl_code" >"$SHIM_DIR/curl.exit"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_failure "$exit_code"
  stderr_is_one_line "$message"
  run jq -c 'del(.at)' "$(state_dir)/status.json"
  assert_output "$(jq -cn --arg c "$class" --arg m "$message" '{state:"error",error_class:$c,file:"book.epub",message:$m}')"
  [ "$(wc -l <"$SHIM_DIR/notify-send.argv")" -eq 1 ]
  eval "set -- $(sed -n 1p "$SHIM_DIR/notify-send.argv")"
  [ "$4 $5" = "critical $message" ]
}

@test "AC4.1 AC4.2 curl 67 is auth-failed, exit 4" {
  configure
  assert_curl_failure 67 4 auth-failed "Mail login failed — check Settings…"
}

@test "AC4.1 AC4.2 curl 6 7 28 35 are network, exit 5" {
  configure
  local code
  for code in 6 7 28 35; do
    assert_curl_failure "$code" 5 network "Could not reach smtp.gmail.com"
  done
}

@test "AC4.1 AC4.2 other curl failures are send-failed, exit 6" {
  configure
  assert_curl_failure 56 6 send-failed "Mail server refused the message — see log"
}

@test "AC4.3 last-send.log holds curl stderr with the password redacted" {
  configure
  local plain login_b64
  plain="$(printf '\0me@gmail.com\0%s' "$PASSWORD" | base64 -w0)"
  login_b64="$(printf '%s' "$PASSWORD" | base64 -w0)"
  printf '* Connected\n> AUTH PLAIN %s\n> %s\nleak %s here\n' "$plain" "$login_b64" "$PASSWORD" >"$SHIM_DIR/curl.err"
  echo 67 >"$SHIM_DIR/curl.exit"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_failure 4
  run cat "$(state_dir)/last-send.log"
  assert_output $'* Connected\n> AUTH PLAIN [redacted]\n> [redacted]\nleak [redacted] here'
}

@test "AC4.3 last-send.log is overwritten per send" {
  configure
  echo first-attempt >"$SHIM_DIR/curl.err"
  run "$OMAKINDLE" send "$(book)"
  echo second-attempt >"$SHIM_DIR/curl.err"
  run "$OMAKINDLE" send "$(book)"
  run cat "$(state_dir)/last-send.log"
  assert_output second-attempt
}

@test "AC5.1 a held send.lock exits 7 within one second, silently" {
  configure
  mkdir -p "$(state_dir)"
  exec 9>"$(state_dir)/send.lock"
  flock -n 9
  run --separate-stderr timeout 1 "$OMAKINDLE" send "$(book)"
  exec 9>&-
  assert_failure 7
  stderr_is_one_line "Another send is running"
  [ ! -e "$(state_dir)/status.json" ]
  [ ! -e "$SHIM_DIR/notify-send.argv" ]
  [ ! -e "$SHIM_DIR/curl.argv" ]
}

@test "AC3.2 a symlink to a file over 52428800 bytes exits 3" {
  configure
  truncate -s 52428801 "$BATS_TEST_TMPDIR/big.bin"
  ln -s "$BATS_TEST_TMPDIR/big.bin" "$BATS_TEST_TMPDIR/big.pdf"
  run --separate-stderr "$OMAKINDLE" send "$BATS_TEST_TMPDIR/big.pdf"
  assert_failure 3
  run jq -r .error_class "$(state_dir)/status.json"
  assert_output file-rejected
  [ ! -e "$SHIM_DIR/curl.argv" ]
}

@test "AC3.2 a symlink to a file of exactly 52428800 bytes is sent" {
  configure
  truncate -s 52428800 "$BATS_TEST_TMPDIR/edge.bin"
  ln -s "$BATS_TEST_TMPDIR/edge.bin" "$BATS_TEST_TMPDIR/edge.pdf"
  run --separate-stderr "$OMAKINDLE" send "$BATS_TEST_TMPDIR/edge.pdf"
  assert_success
}

@test "config values are taken verbatim, not parsed as shell" {
  configure
  echo 'FROM=Probe User <probe@example.org>' >>"$XDG_CONFIG_HOME/omakindle/config"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  eval "set -- $(sed -n 1p "$SHIM_DIR/curl.argv")"
  while [ "$1" != --mail-from ]; do shift; done
  [ "$2" = "Probe User <probe@example.org>" ]
}

@test "config values are never evaluated" {
  configure
  cat >>"$XDG_CONFIG_HOME/omakindle/config" <<'CONF'
PROVIDER=$(touch "$HOME/pwned")
CONF
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  [ ! -e "$HOME/pwned" ]
}

@test "termination during curl kills curl, keeps its transcript, leaves send-failed status" {
  configure
  cat >"$SHIM_DIR/curl" <<SHIM
#!/usr/bin/env bash
cat >/dev/null
echo '* transcript probe' >&2
echo \$\$ >"$SHIM_DIR/curl.pid"
exec sleep 5
SHIM
  "$OMAKINDLE" send "$(book)" 2>"$BATS_TEST_TMPDIR/stderr" &
  local cli=$! code=0
  sleep 0.5
  kill -TERM "$cli"
  wait "$cli" || code=$?
  [ "$code" -eq 6 ]
  [ "$(<"$BATS_TEST_TMPDIR/stderr")" = "Mail server refused the message — see log" ]
  run jq -c '{state, error_class}' "$(state_dir)/status.json"
  assert_output '{"state":"error","error_class":"send-failed"}'
  [ "$(wc -l <"$SHIM_DIR/notify-send.argv")" -eq 1 ]
  eval "set -- $(sed -n 1p "$SHIM_DIR/notify-send.argv")"
  [ "$4" = critical ]
  grep -qx '\* transcript probe' "$(state_dir)/last-send.log"
  run ls "$(state_dir)"
  refute_output --partial mime.
  run ! kill -0 "$(<"$SHIM_DIR/curl.pid")"
}

@test "environment variables cannot complete a partial config" {
  configure
  sed -i '/^SMTP_HOST=/d' "$XDG_CONFIG_HOME/omakindle/config"
  SMTP_HOST=evil.example run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_failure 2
  [ ! -e "$SHIM_DIR/curl.argv" ]
}

@test "a CRLF config yields values without carriage returns" {
  configure
  sed -i 's/$/\r/' "$XDG_CONFIG_HOME/omakindle/config"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  eval "set -- $(sed -n 1p "$SHIM_DIR/curl.argv")"
  while [ "$1" != --mail-rcpt ]; do shift; done
  [ "$2" = "$KINDLE" ]
}

assert_one_critical_notification() {
  local message=$1
  [ "$(wc -l <"$SHIM_DIR/notify-send.argv")" -eq 1 ]
  eval "set -- $(sed -n 1p "$SHIM_DIR/notify-send.argv")"
  [ "$#" -eq 6 ]
  [ "$1 $2 $3 $4" = "-a omakindle -u critical" ]
  [ "$5" = "$message" ]
  [ "$6" = "Log: $XDG_STATE_HOME/omakindle/last-send.log" ]
}

@test "AC4.2 not-configured fires one critical notification" {
  echo 1 >"$SHIM_DIR/zenity.exit"
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_failure 2
  assert_one_critical_notification "Kindle is not set up yet"
}

@test "AC4.2 file-rejected fires one critical notification" {
  configure
  run --separate-stderr "$OMAKINDLE" send "$(book book.mobi)"
  assert_failure 3
  assert_one_critical_notification "book.mobi: unsupported format or over 50 MB"
}

@test "AC5.1 send.lock is held while curl runs" {
  configure
  cat >"$SHIM_DIR/curl" <<SHIM
#!/usr/bin/env bash
cat >/dev/null
flock -n "$XDG_STATE_HOME/omakindle/send.lock" true || echo held >"$SHIM_DIR/curl.lock"
SHIM
  run --separate-stderr "$OMAKINDLE" send "$(book)"
  assert_success
  run cat "$SHIM_DIR/curl.lock"
  assert_output held
}
