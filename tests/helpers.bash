# shellcheck shell=bash

load /usr/lib/bats/bats-support/load.bash
load /usr/lib/bats/bats-assert/load.bash

bats_require_minimum_version 1.5.0

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
export REPO
export OMAKINDLE="$REPO/bin/omakindle"

setup() {
  exec </dev/null
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export SHIM_DIR="$BATS_TEST_TMPDIR/shims"
  mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$SHIM_DIR"

  local name
  for name in curl zenity secret-tool notify-send omarchy; do
    cat >"$SHIM_DIR/$name" <<SHIM
#!/usr/bin/env bash
base="$SHIM_DIR/$name"
{ printf '%q ' "\$@"; echo; } >>"\$base.argv"
if [ -p /dev/stdin ] || [ -f /dev/stdin ]; then cat >>"\$base.stdin"; fi
prev=
for arg in "\$@"; do
  [ "\$prev" = --upload-file ] && cp "\$arg" "\$base.upload"
  prev=\$arg
done
n=\$((\$(cat "\$base.calls" 2>/dev/null || echo 0) + 1))
echo "\$n" >"\$base.calls"
if [ -f "\$base.out.\$n" ]; then cat "\$base.out.\$n"; elif [ -f "\$base.out" ]; then cat "\$base.out"; fi
[ -f "\$base.err" ] && cat "\$base.err" >&2
code="\$(cat "\$base.exit.\$n" 2>/dev/null || cat "\$base.exit" 2>/dev/null)"
exit "\${code:-0}"
SHIM
    chmod +x "$SHIM_DIR/$name"
  done
  export PATH="$SHIM_DIR:$PATH"
}
