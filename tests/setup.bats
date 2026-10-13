#!/usr/bin/env bats

load helpers

KINDLE=reader@kindle.com
EMAIL=me@gmail.com
PASSWORD='s3cr"et\pass'
config() { echo "$XDG_CONFIG_HOME/omakindle/config"; }
secret() { echo "$XDG_CONFIG_HOME/omakindle/secret"; }
state_dir() { echo "$XDG_STATE_HOME/omakindle"; }

answer() {
  local n=$1 IFS=$'\t'
  shift
  printf '%s\n' "$*" >"$SHIM_DIR/zenity.out.$n"
}

cancel() { echo 1 >"$SHIM_DIR/zenity.exit.$1"; }

args_of() {
  eval "set -- $(sed -n "$2p" "$SHIM_DIR/$1.argv")"
  printf '%s\n' "$@"
}

text_of() {
  eval "set -- $(sed -n "$1p" "$SHIM_DIR/zenity.argv")"
  while [ "$1" != --text ]; do shift; done
  printf '%s\n' "$2"
}

fields_of() {
  eval "set -- $(sed -n "$1p" "$SHIM_DIR/zenity.argv")"
  while [ "$#" -gt 0 ]; do
    if [ "$1" = --text ]; then shift 2; else printf '%s\n' "$1"; shift; fi
  done
}

omakindle() { run --separate-stderr timeout 10 "$OMAKINDLE" "$@"; }

book() {
  printf 'book bytes\n' >"$BATS_TEST_TMPDIR/book.epub"
  echo "$BATS_TEST_TMPDIR/book.epub"
}

configure() {
  mkdir -p "$XDG_CONFIG_HOME/omakindle"
  cat >"$(config)" <<CONF
PROVIDER=Outlook
KINDLE_ADDRESS=$KINDLE
FROM=me@outlook.com
SMTP_HOST=smtp.office365.com
SMTP_PORT=587
SMTP_LOGIN=me@outlook.com
CONF
  chmod 600 "$(config)"
  printf '%s' stored-pass >"$SHIM_DIR/secret-tool.out"
}

assert_nothing_written() {
  [ ! -e "$(config)" ]
  [ ! -e "$(secret)" ]
  run ! grep -q '^store' "$SHIM_DIR/secret-tool.argv"
}

@test "AC2.1 step 1 asks provider, Kindle address, email and hidden password" {
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_success
  run fields_of 1
  assert_output "$(printf '%s\n' --forms --title 'Kindle setup' --add-combo Provider --combo-values 'Gmail|Outlook|Other' \
    --add-entry 'Kindle address' --add-entry Email --add-password Password --separator=$'\t')"
  run text_of 1
  assert_output --partial "app password"
  [ "$(wc -l <"$SHIM_DIR/zenity.argv")" -eq 1 ]
}

@test "AC2.1 AC2.3 Gmail preset writes the six keys unquoted with mode 0600" {
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_success
  run cat "$(config)"
  assert_output "PROVIDER=Gmail
KINDLE_ADDRESS=$KINDLE
FROM=$EMAIL
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_LOGIN=$EMAIL"
  run stat -c %a "$(config)"
  assert_output 600
}

@test "AC2.1 Outlook preset uses smtp.office365.com:587 and the email as login" {
  answer 1 Outlook "$KINDLE" me@outlook.com "$PASSWORD"
  omakindle setup
  assert_success
  grep -qx SMTP_HOST=smtp.office365.com "$(config)"
  grep -qx SMTP_PORT=587 "$(config)"
  grep -qx SMTP_LOGIN=me@outlook.com "$(config)"
  grep -qx FROM=me@outlook.com "$(config)"
}

@test "AC2.1 Other opens step 2 for host, port and login" {
  answer 1 Other "$KINDLE" me@example.org "$PASSWORD"
  answer 2 mail.example.org 2525 login-name
  omakindle setup
  assert_success
  run fields_of 2
  assert_output "$(printf '%s\n' --forms --title 'Kindle setup' --add-entry 'SMTP host' --add-entry 'SMTP port' --add-entry Login --separator=$'\t')"
  run cat "$(config)"
  assert_output "PROVIDER=Other
KINDLE_ADDRESS=$KINDLE
FROM=me@example.org
SMTP_HOST=mail.example.org
SMTP_PORT=2525
SMTP_LOGIN=login-name"
}

@test "AC2.2 the test email goes to FROM with the setup body and no attachment" {
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_success
  [ "$(wc -l <"$SHIM_DIR/curl.argv")" -eq 1 ]
  eval "set -- $(sed -n 1p "$SHIM_DIR/curl.argv")"
  [[ " $* " == *" --url smtp://smtp.gmail.com:587 "* ]]
  [[ " $* " == *" --mail-from $EMAIL "* ]]
  [[ " $* " == *" --mail-rcpt $EMAIL "* ]]
  [[ " $* " == *" --ssl-reqd "* ]]
  [[ " $* " == *" -K - "* ]]
  grep -q $'^To: me@gmail.com\r$' "$SHIM_DIR/curl.upload"
  grep -q $'^omakindle setup test\r$' "$SHIM_DIR/curl.upload"
  run ! grep -qi '^Content-Disposition: attachment' "$SHIM_DIR/curl.upload"
  run cat "$SHIM_DIR/curl.stdin"
  assert_output 'user = "me@gmail.com:s3cr\"et\\pass"'
}

@test "AC2.2 a failed test email reopens the form with the error text and writes nothing" {
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  echo 67 >"$SHIM_DIR/curl.exit"
  cancel 2
  omakindle setup
  assert_failure 2
  [ "$(wc -l <"$SHIM_DIR/zenity.argv")" -eq 2 ]
  run text_of 2
  assert_output --partial "Mail login failed — check Settings…"
  assert_nothing_written
}

@test "AC2.2 the reopened form succeeds once the test email is accepted" {
  answer 1 Gmail "$KINDLE" "$EMAIL" wrong
  echo 6 >"$SHIM_DIR/curl.exit.1"
  answer 2 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_success
  run text_of 2
  assert_output --partial "Could not reach smtp.gmail.com"
  grep -qx "FROM=$EMAIL" "$(config)"
  run cat "$SHIM_DIR/secret-tool.stdin"
  assert_output "$PASSWORD"
}

@test "AC2.2 cancel at step 1 exits 2, writes not-configured, touches nothing" {
  cancel 1
  omakindle setup
  assert_failure 2
  run jq -r .state "$(state_dir)/status.json"
  assert_output not-configured
  assert_nothing_written
  [ ! -e "$SHIM_DIR/curl.argv" ]
}

@test "AC2.2 cancel at step 2 exits 2, writes not-configured, touches nothing" {
  answer 1 Other "$KINDLE" me@example.org "$PASSWORD"
  cancel 2
  omakindle setup
  assert_failure 2
  run jq -r .state "$(state_dir)/status.json"
  assert_output not-configured
  assert_nothing_written
  [ ! -e "$SHIM_DIR/curl.argv" ]
}

@test "AC2.3 the password goes to secret-tool store on stdin" {
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_success
  run args_of secret-tool 1
  assert_output "$(printf '%s\n' store --label 'omakindle SMTP password' application omakindle key smtp-password)"
  run cat "$SHIM_DIR/secret-tool.stdin"
  assert_output "$PASSWORD"
  [ ! -e "$(secret)" ]
}

@test "AC2.3 a failed store writes the secret file 0600 and warns once" {
  echo 1 >"$SHIM_DIR/secret-tool.exit"
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_success
  [ "$(<"$(secret)")" = "$PASSWORD" ]
  run stat -c %a "$(secret)"
  assert_output 600
  [ "$(grep -c -- '^--warning' "$SHIM_DIR/zenity.argv")" -eq 1 ]
  [ -e "$(state_dir)/secret-fallback-warned" ]

  rm "$SHIM_DIR/zenity.calls"
  answer 1 Gmail "$KINDLE" "$EMAIL" other-pass
  omakindle setup
  assert_success
  [ "$(<"$(secret)")" = other-pass ]
  [ "$(grep -c -- '^--warning' "$SHIM_DIR/zenity.argv")" -eq 1 ]
}

@test "AC2.4 setup without a pending send writes idle, Kindle is set up" {
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_success
  run jq -c '{state, error_class, message}' "$(state_dir)/status.json"
  assert_output '{"state":"idle","error_class":null,"message":"Kindle is set up"}'
  [ ! -e "$SHIM_DIR/notify-send.argv" ]
}

@test "AC2.4 setup is prefilled from config: empty fields keep the stored values" {
  configure
  answer 1 "" "" "" ""
  omakindle setup
  assert_success
  run fields_of 1
  assert_line 'Outlook|Gmail|Other'
  run text_of 1
  assert_output --partial "$KINDLE"
  assert_output --partial me@outlook.com
  run cat "$(config)"
  assert_output "PROVIDER=Outlook
KINDLE_ADDRESS=$KINDLE
FROM=me@outlook.com
SMTP_HOST=smtp.office365.com
SMTP_PORT=587
SMTP_LOGIN=me@outlook.com"
}

@test "AC2.4 an empty password keeps the stored one" {
  configure
  answer 1 Gmail "$KINDLE" "$EMAIL" ""
  omakindle setup
  assert_success
  run cat "$SHIM_DIR/curl.stdin"
  assert_output "user = \"$EMAIL:stored-pass\""
  run ! grep -q '^store' "$SHIM_DIR/secret-tool.argv"
  grep -qx PROVIDER=Gmail "$(config)"
}

@test "AC2.4 cancelling setup of a configured install leaves config and status alone" {
  configure
  cp "$(config)" "$BATS_TEST_TMPDIR/before"
  cancel 1
  omakindle setup
  assert_failure 2
  cmp "$(config)" "$BATS_TEST_TMPDIR/before"
  [ ! -e "$(state_dir)/status.json" ]
}

@test "US2 send without config runs setup, then sends the file in the same invocation" {
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle send "$(book)"
  assert_success
  [ "$(wc -l <"$SHIM_DIR/curl.argv")" -eq 2 ]
  eval "set -- $(sed -n 1p "$SHIM_DIR/curl.argv")"
  [[ " $* " == *" --mail-rcpt $EMAIL "* ]]
  eval "set -- $(sed -n 2p "$SHIM_DIR/curl.argv")"
  [[ " $* " == *" --mail-rcpt $KINDLE "* ]]
  grep -q 'filename="book.epub"' "$SHIM_DIR/curl.upload"
  run jq -c 'del(.at)' "$(state_dir)/status.json"
  assert_output '{"state":"sent","error_class":null,"file":"book.epub","message":"Sent book.epub to reader@kindle.com"}'
  [ -e "$(config)" ]
}

@test "US2 cancelling the lazy setup aborts the send with exit 2 and not-configured" {
  cancel 1
  omakindle send "$(book)"
  assert_failure 2
  run jq -c '{state, file}' "$(state_dir)/status.json"
  assert_output '{"state":"not-configured","file":"book.epub"}'
  assert_nothing_written
  [ ! -e "$SHIM_DIR/curl.argv" ]
}

@test "AC4.4 the password never appears on any argv" {
  echo 1 >"$SHIM_DIR/secret-tool.exit"
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle send "$(book)"
  assert_success
  local argv
  for argv in "$SHIM_DIR"/*.argv; do
    run ! grep -qF s3cr "$argv"
  done
  [ "$(wc -l <"$SHIM_DIR/curl.argv")" -eq 2 ]
}

@test "AC2.2 an incomplete form reopens without sending or writing" {
  answer 1 Gmail "" "$EMAIL" "$PASSWORD"
  cancel 2
  omakindle setup
  assert_failure 2
  run text_of 2
  assert_output --partial "Some required values are missing."
  [ ! -e "$SHIM_DIR/curl.argv" ]
  assert_nothing_written
}

@test "setup that cannot write the config exits 1 with a stderr line and installs nothing" {
  configure
  rm -r "$XDG_CONFIG_HOME/omakindle"
  touch "$XDG_CONFIG_HOME/omakindle"
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_failure 1
  [ -n "$stderr" ]
  [ -f "$XDG_CONFIG_HOME/omakindle" ] && [ ! -s "$XDG_CONFIG_HOME/omakindle" ]
  run ! grep -qs '"Kindle is set up"' "$(state_dir)/status.json"
}

@test "lazy setup that cannot write the config ends the send as send-failed" {
  touch "$XDG_CONFIG_HOME/omakindle"
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle send "$(book)"
  assert_failure 6
  [ ! -s "$XDG_CONFIG_HOME/omakindle" ]
  run jq -c '{state, error_class}' "$(state_dir)/status.json"
  assert_output '{"state":"error","error_class":"send-failed"}'
  [ "$(wc -l <"$SHIM_DIR/curl.argv")" -eq 1 ]
}

@test "AC2.3 the fallback secret replaces the path instead of writing through it" {
  echo 1 >"$SHIM_DIR/secret-tool.exit"
  mkdir -p "$XDG_CONFIG_HOME/omakindle"
  printf elsewhere >"$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$(secret)"
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_success
  [ ! -L "$(secret)" ]
  [ "$(<"$(secret)")" = "$PASSWORD" ]
  run stat -c %a "$(secret)"
  assert_output 600
  [ "$(<"$BATS_TEST_TMPDIR/elsewhere")" = elsewhere ]
}

@test "AC2.4 the keep hint after a failed test email names the values just entered" {
  configure
  answer 1 Outlook "" new@outlook.com ""
  echo 67 >"$SHIM_DIR/curl.exit"
  cancel 2
  omakindle setup
  assert_failure 2
  run text_of 2
  assert_output --partial "Leave a field empty to keep: $KINDLE, new@outlook.com."
}

@test "AC2.3 a successful keyring store deletes a stale secret file" {
  mkdir -p "$XDG_CONFIG_HOME/omakindle"
  printf stale >"$(secret)"
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  omakindle setup
  assert_success
  grep -q '^store' "$SHIM_DIR/secret-tool.argv"
  [ ! -e "$(secret)" ]
}

wait_for() {
  local tries=50
  until [ -e "$1" ]; do
    [ "$((tries -= 1))" -gt 0 ] || return 1
    sleep 0.1
  done
}

@test "a signal during the reopened form does not resend the test email" {
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  answer 2 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  echo 67 >"$SHIM_DIR/curl.exit.1"
  mv "$SHIM_DIR/zenity" "$SHIM_DIR/zenity.real"
  cat >"$SHIM_DIR/zenity" <<SHIM
#!/usr/bin/env bash
[ ! -e "$SHIM_DIR/zenity.calls" ] || { touch "$SHIM_DIR/zenity.waiting"; sleep 1; }
exec "$SHIM_DIR/zenity.real" "\$@"
SHIM
  chmod +x "$SHIM_DIR/zenity"
  "$OMAKINDLE" setup 2>/dev/null &
  local cli=$!
  wait_for "$SHIM_DIR/zenity.waiting"
  kill -TERM "$cli"
  wait "$cli" || true
  sleep 2
  [ "$(<"$SHIM_DIR/curl.calls")" -eq 1 ]
  [ ! -e "$(config)" ]
}

@test "US2 a signal during the lazy setup test email ends with one notification and a status" {
  answer 1 Gmail "$KINDLE" "$EMAIL" "$PASSWORD"
  cat >"$SHIM_DIR/curl" <<SHIM
#!/usr/bin/env bash
cat >/dev/null
touch "$SHIM_DIR/curl.started"
exec sleep 5
SHIM
  "$OMAKINDLE" send "$(book)" 2>/dev/null &
  local cli=$! code=0
  wait_for "$SHIM_DIR/curl.started"
  kill -TERM "$cli"
  wait "$cli" || code=$?
  [ "$code" -eq 2 ]
  [ "$(wc -l <"$SHIM_DIR/notify-send.argv")" -eq 1 ]
  run jq -r .state "$(state_dir)/status.json"
  assert_output not-configured
  [ ! -e "$(config)" ]
}
