#!/usr/bin/env bats

load helpers

install_fixture() { cp "$OMAKINDLE" "$SHIM_DIR/curl.out"; }

curl_argv() {
  eval "set -- $(sed -n 1p "$SHIM_DIR/curl.argv")"
  echo "$*"
}

@test "AC1 install.sh downloads the CLI from main into ~/.local/bin and runs install-menu" {
  install_fixture
  run --separate-stderr sh "$REPO/install.sh"
  assert_success
  [ "$(curl_argv)" = "-fsSL https://raw.githubusercontent.com/tiilyat/omakindle/main/bin/omakindle" ]
  cmp "$OMAKINDLE" "$HOME/.local/bin/omakindle"
  [ "$(stat -c %a "$HOME/.local/bin/omakindle")" = 755 ]
  [ "$(ls -A "$HOME/.local/bin")" = omakindle ]
  run omarchy_parse '."kindle.send".action'
  assert_output "\"$HOME/.local/bin/omakindle send\""
  [ "$(grep -c '^menu refresh' "$SHIM_DIR/omarchy.argv")" -eq 1 ]
}

@test "AC1 piped into sh it behaves the same" {
  install_fixture
  run bash -c 'cat "$REPO/install.sh" | sh'
  assert_success
  cmp "$OMAKINDLE" "$HOME/.local/bin/omakindle"
  [ "$(stat -c %a "$HOME/.local/bin/omakindle")" = 755 ]
  [ "$(ls -A "$HOME/.local/bin")" = omakindle ]
  run omarchy_parse '."kindle.send".action'
  assert_output "\"$HOME/.local/bin/omakindle send\""
}

@test "AC1 a rerun installs the new body and leaves the menu byte-identical" {
  install_fixture
  run sh "$REPO/install.sh"
  assert_success
  cp "$(menu)" "$BATS_TEST_TMPDIR/first"
  { cat "$OMAKINDLE"; echo '# rerun'; } >"$SHIM_DIR/curl.out"
  run sh "$REPO/install.sh"
  assert_success
  cmp "$SHIM_DIR/curl.out" "$HOME/.local/bin/omakindle"
  cmp "$BATS_TEST_TMPDIR/first" "$(menu)"
  [ "$(grep -c '^menu refresh' "$SHIM_DIR/omarchy.argv")" -eq 2 ]
}

@test "AC1 a failed download exits non-zero, keeps the old CLI and leaves no temp file" {
  mkdir -p "$HOME/.local/bin"
  echo old >"$HOME/.local/bin/omakindle"
  echo 22 >"$SHIM_DIR/curl.exit"
  run --separate-stderr sh "$REPO/install.sh"
  assert_failure
  [[ "$stderr" == *"could not download"* ]]
  [ "$(<"$HOME/.local/bin/omakindle")" = old ]
  [ "$(ls -A "$HOME/.local/bin")" = omakindle ]
  [ ! -e "$(menu)" ]
}

@test "AC1 a failing install-menu makes install.sh exit non-zero" {
  install_fixture
  user_menu <<'JSONC'
{
// omakindle:begin
}
JSONC
  run --separate-stderr sh "$REPO/install.sh"
  assert_failure
  [[ "$stderr" == *"install-menu failed"* ]]
}

@test "AC1 a cut-off install script runs nothing" {
  install_fixture
  run bash -c 'sed "\$d" "$REPO/install.sh" | sh'
  [ ! -e "$SHIM_DIR/curl.argv" ]
  [ ! -e "$HOME/.local/bin" ]
}

@test "AC-R OMAKINDLE_REF selects the ref in the URL" {
  install_fixture
  OMAKINDLE_REF=feature/x run sh "$REPO/install.sh"
  assert_success
  [ "$(curl_argv)" = "-fsSL https://raw.githubusercontent.com/tiilyat/omakindle/feature/x/bin/omakindle" ]
}
