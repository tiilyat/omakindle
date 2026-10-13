#!/usr/bin/env bats

load helpers

assert_usage_exit() {
  run --separate-stderr "$OMAKINDLE" "$@"
  assert_failure 1
  assert_output ""
  [ "$(printf '%s\n' "$stderr" | wc -l)" -eq 1 ]
  [[ $stderr == *[Uu]sage* ]]
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
