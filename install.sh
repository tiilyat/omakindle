#!/bin/sh
set -eu

main() {
  url="https://raw.githubusercontent.com/tiilyat/omakindle/${OMAKINDLE_REF:-main}/bin/omakindle"
  dir="$HOME/.local/bin"
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/omakindle.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL "$url" >"$tmp" || { echo "omakindle: could not download $url" >&2; exit 1; }
  chmod 755 "$tmp"
  mv "$tmp" "$dir/omakindle"
  "$dir/omakindle" install-menu || { echo "omakindle: installed $dir/omakindle, but install-menu failed" >&2; exit 1; }
  echo "omakindle installed: Kindle is in the Omarchy menu"
}

# sh runs nothing until it has read all of main, so a cut-off download executes nothing.
main
