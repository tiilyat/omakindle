#!/usr/bin/env bats

load helpers

@test "plugin folder passes omarchy plugin validate" {
  run omarchy plugin validate "$REPO"
  assert_success
}

@test "bin/omakindle is mode 755 in git" {
  run git -C "$REPO" ls-files -s bin/omakindle
  assert_output --regexp '^100755 '
}
