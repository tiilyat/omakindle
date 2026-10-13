#!/usr/bin/env bats

load helpers

assert_usage_exit() {
  run --separate-stderr "$OMAKINDLE" "$@"
  assert_failure 1
  assert_output ""
  [ "$(printf '%s\n' "$stderr" | wc -l)" -eq 1 ]
  [[ $stderr == *[Uu]sage* ]]
}

assert_not_implemented() {
  run --separate-stderr "$OMAKINDLE" "$@"
  assert_failure 1
  assert_output ""
  [[ $stderr == *"not implemented"* ]]
}

@test "no arguments prints one usage line to stderr and exits 1" {
  assert_usage_exit
}

@test "--help prints one usage line to stderr and exits 1" {
  assert_usage_exit --help
}

@test "unknown subcommand prints one usage line to stderr and exits 1" {
  assert_usage_exit bogus
}

@test "send is not implemented yet" {
  assert_not_implemented send
}

@test "setup is not implemented yet" {
  assert_not_implemented setup
}

@test "install-menu is not implemented yet" {
  assert_not_implemented install-menu
}
