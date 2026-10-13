#!/usr/bin/env bats

load helpers

@test "plugin folder passes omarchy plugin validate" {
  PATH=${PATH#"$SHIM_DIR:"} run omarchy plugin validate "$REPO"
  assert_success
}

@test "bin/omakindle is mode 755 in git" {
  run git -C "$REPO" ls-files -s bin/omakindle
  assert_output --regexp '^100755 '
}

@test "README's first fenced command installs the plugin from GitHub" {
  run awk '/^```/ { if (inside) exit; inside = 1; next } inside { print }' "$REPO/README.md"
  assert_output "omarchy plugin add https://github.com/tiilyat/omakindle --enable"
}

@test "manifest version is 1.0.0" {
  run jq -r .version "$REPO/manifest.json"
  assert_output "1.0.0"
}
