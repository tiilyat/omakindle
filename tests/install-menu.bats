#!/usr/bin/env bats

load helpers

menu() { echo "$XDG_CONFIG_HOME/omarchy/extensions/omarchy-menu.jsonc"; }

block() {
  cat <<BLOCK
// omakindle:begin
"kindle": {"icon":"󰂺","label":"Kindle"},
"kindle.send": {"icon":"󰂺","label":"Send file…","action":"$1/bin/omakindle send"},
"kindle.settings": {"icon":"󰒓","label":"Settings…","action":"$1/bin/omakindle setup"},
// omakindle:end
BLOCK
}

user_menu() {
  mkdir -p "$(dirname "$(menu)")"
  cat >"$(menu)"
}

plugin_copy() {
  local dir="$BATS_TEST_TMPDIR/$1"
  mkdir -p "$dir/bin"
  cp "$OMAKINDLE" "$dir/bin/"
  cp "$REPO/manifest.json" "$dir/"
  echo "$dir"
}

omarchy_parse() {
  sed -E '/^[[:space:]]*\/\//d' "$(menu)" | sed -z -E 's/,([[:space:]]*[]}])/\1/g' | jq -ec "$1"
}

refused() {
  cp "$(menu)" "$BATS_TEST_TMPDIR/before"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_failure 1
  assert_output ""
  [ "$stderr" = "$1" ]
  cmp "$BATS_TEST_TMPDIR/before" "$(menu)"
  [ ! -e "$SHIM_DIR/omarchy.argv" ]
}

@test "AC7.1 missing menu file is created with the block" {
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  diff <(printf '{\n'; block "$REPO"; printf '}\n') "$(menu)"
  run omarchy_parse 'to_entries | map([.key, .value.icon, .value.label, .value.action])'
  assert_output "[[\"kindle\",\"󰂺\",\"Kindle\",null],[\"kindle.send\",\"󰂺\",\"Send file…\",\"$REPO/bin/omakindle send\"],[\"kindle.settings\",\"󰒓\",\"Settings…\",\"$REPO/bin/omakindle setup\"]]"
}

@test "AC7.1 stock template keeps every line and gains the block before the final brace" {
  user_menu <<'JSONC'
{
  // Extend the Quickshell Omarchy menu with JSONC.
  //
  // Examples:
  // "personal": {"icon":"","label":"Personal"},
}
JSONC
  cp "$(menu)" "$BATS_TEST_TMPDIR/before"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  diff <(head -n -1 "$BATS_TEST_TMPDIR/before"; block "$REPO"; echo '}') "$(menu)"
  omarchy_parse . >/dev/null
}

@test "AC7.2 second run yields a byte-identical file" {
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  cp "$(menu)" "$BATS_TEST_TMPDIR/first"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  cmp "$BATS_TEST_TMPDIR/first" "$(menu)"
  omarchy_parse . >/dev/null
}

@test "AC7.2 user entries around the block survive and a moved plugin rewrites only the block" {
  local moved
  moved="$(plugin_copy moved)"
  user_menu <<JSONC
{
  "personal": {"icon":"x","label":"Personal"},
$(block /old/place)
  // trailing note
  "personal.notes": {"icon":"y","label":"Notes","action":"notes"},
}
JSONC
  run --separate-stderr "$moved/bin/omakindle" install-menu
  assert_success
  diff <(cat <<JSONC
{
  "personal": {"icon":"x","label":"Personal"},
$(block "$moved")
  // trailing note
  "personal.notes": {"icon":"y","label":"Notes","action":"notes"},
}
JSONC
  ) "$(menu)"
  omarchy_parse . >/dev/null
}

@test "AC7.1 a plugin dir with a space is shell-quoted in the action" {
  local dir action
  dir="$(plugin_copy "my plugins")"
  run --separate-stderr "$dir/bin/omakindle" install-menu
  assert_success
  action="$(omarchy_parse '."kindle.send".action' | jq -r .)"
  [ "$action" = "${dir// /\\ }/bin/omakindle send" ]
  eval "set -- $action"
  [ "$#" -eq 2 ]
  [ "$1" = "$dir/bin/omakindle" ]
  [ "$2" = send ]
}

@test "AC7.3 a result that would not parse restores the file and exits 1" {
  user_menu <<'JSONC'
{
  "personal": {"icon":"x","label":"Personal"},
JSONC
  cp "$(menu)" "$BATS_TEST_TMPDIR/before"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_failure 1
  assert_output ""
  [ "$stderr" = "omarchy-menu.jsonc would not parse; left unchanged" ]
  cmp "$BATS_TEST_TMPDIR/before" "$(menu)"
  [ ! -e "$SHIM_DIR/omarchy.argv" ]
  [ ! -e "$XDG_STATE_HOME/omakindle/menu-version" ]
}

@test "AC7.4 menu-version records the version of the manifest beside the CLI" {
  local dir
  dir="$(plugin_copy versioned)"
  jq '.version = "9.8.7"' "$REPO/manifest.json" >"$dir/manifest.json"
  run --separate-stderr "$dir/bin/omakindle" install-menu
  assert_success
  [ "$(cat "$XDG_STATE_HOME/omakindle/menu-version")" = 9.8.7 ]
  [ "$(stat -c %a "$XDG_STATE_HOME/omakindle")" = 700 ]
}

@test "successful write refreshes the omarchy menu" {
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  [ "$(cat "$SHIM_DIR/omarchy.argv")" = "menu refresh " ]
}

@test "a failing menu refresh is ignored" {
  echo 1 >"$SHIM_DIR/omarchy.exit"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
}

@test "a last user entry without a trailing comma gets a bare comma line before the block" {
  user_menu <<'JSONC'
{
  "a": {"icon":"x","label":"A"},
  "b": {"icon":"y","label":"B"}
}
JSONC
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  diff <(cat <<JSONC
{
  "a": {"icon":"x","label":"A"},
  "b": {"icon":"y","label":"B"}
,
$(block "$REPO")
}
JSONC
  ) "$(menu)"
  omarchy_parse . >/dev/null
  cp "$(menu)" "$BATS_TEST_TMPDIR/first"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  cmp "$BATS_TEST_TMPDIR/first" "$(menu)"
}

@test "stock template gets no comma line" {
  user_menu <<'JSONC'
{
  // "personal": {"icon":"","label":"Personal"}
}
JSONC
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  run ! grep -qx '[[:space:]]*,[[:space:]]*' "$(menu)"
  omarchy_parse . >/dev/null
}

@test "an orphan begin marker is refused" {
  user_menu <<'JSONC'
{
// omakindle:begin
}
JSONC
  refused "omarchy-menu.jsonc has unbalanced omakindle markers; left unchanged"
}

@test "an end marker before the begin marker is refused" {
  user_menu <<'JSONC'
{
// omakindle:end
// omakindle:begin
}
JSONC
  refused "omarchy-menu.jsonc has unbalanced omakindle markers; left unchanged"
}

@test "duplicate omakindle blocks are refused" {
  user_menu <<JSONC
{
$(block /a)
$(block /b)
}
JSONC
  refused "omarchy-menu.jsonc has unbalanced omakindle markers; left unchanged"
}

@test "the write keeps the file mode and leaves no temp file" {
  user_menu <<'JSONC'
{
}
JSONC
  chmod 600 "$(menu)"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  diff <(printf '{\n'; block "$REPO"; printf '}\n') "$(menu)"
  [ "$(stat -c %a "$(menu)")" = 600 ]
  omarchy_parse . >/dev/null
  [ "$(ls -A "$(dirname "$(menu)")")" = omarchy-menu.jsonc ]
}

@test "a file with two top-level values is refused" {
  user_menu <<'JSONC'
{
}
{
}
JSONC
  refused "omarchy-menu.jsonc would not parse; left unchanged"
}

@test "a file with a leading UTF-8 BOM is refused" {
  mkdir -p "$(dirname "$(menu)")"
  printf '\xef\xbb\xbf{\n}\n' >"$(menu)"
  refused "omarchy-menu.jsonc would not parse; left unchanged"
}

@test "a one-line file is split at its final brace" {
  mkdir -p "$(dirname "$(menu)")"
  printf '%s\n' '{"a":{"icon":"x","label":"A"}}' >"$(menu)"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  diff <(printf '%s\n' '{"a":{"icon":"x","label":"A"}' ','; block "$REPO"; echo '}') "$(menu)"
  omarchy_parse . >/dev/null
  cp "$(menu)" "$BATS_TEST_TMPDIR/first"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  cmp "$BATS_TEST_TMPDIR/first" "$(menu)"
}

@test "an own-line comment after the final brace stays after it" {
  user_menu <<'JSONC'
{
  "a": {"icon":"x","label":"A"},
}
// see {"b": {}}
JSONC
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  diff <(cat <<JSONC
{
  "a": {"icon":"x","label":"A"},
$(block "$REPO")
}
// see {"b": {}}
JSONC
  ) "$(menu)"
  omarchy_parse . >/dev/null
}

@test "an empty menu file is treated like a missing one" {
  mkdir -p "$(dirname "$(menu)")"
  : >"$(menu)"
  run --separate-stderr "$OMAKINDLE" install-menu
  assert_success
  diff <(printf '{\n'; block "$REPO"; printf '}\n') "$(menu)"
  omarchy_parse . >/dev/null
}

@test "AC7.2 a CRLF file whose last entry has a trailing comma gets no extra comma" {
  mkdir -p "$(dirname "$(menu)")"
  printf '{\r\n  // c\r\n  "a": {"label":"A"},\r\n}\r\n' >"$(menu)"
  run --separate-stderr "$OMAKINDLE" install-menu
  [ "$status" -eq 0 ]
  omarchy_parse 'keys == ["a","kindle","kindle.send","kindle.settings"]' >/dev/null
  run ! grep -qx ',' "$(menu)"
  cp "$(menu)" "$BATS_TEST_TMPDIR/first"
  "$OMAKINDLE" install-menu
  cmp "$BATS_TEST_TMPDIR/first" "$(menu)"
}
