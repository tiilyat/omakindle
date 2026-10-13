#!/usr/bin/env bats

load helpers

@test "bin/omakindle is mode 755 in git" {
  run git -C "$REPO" ls-files -s bin/omakindle
  assert_output --regexp '^100755 '
}

@test "README's first fenced command is the install line" {
  run awk '/^```/ { if (inside) exit; inside = 1; next } inside { print }' "$REPO/README.md"
  assert_output "curl -fsSL https://raw.githubusercontent.com/tiilyat/omakindle/main/install.sh | sh"
}

@test "README's Update section runs the same install line" {
  run awk '/^## Update/{u=1} u&&/^```/{if(i)exit;i=1;next} u&&i' "$REPO/README.md"
  assert_output "curl -fsSL https://raw.githubusercontent.com/tiilyat/omakindle/main/install.sh | sh"
}
