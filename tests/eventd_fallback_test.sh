#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/engine/eventd.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "[FAIL] eventd.sh not found"
  exit 1
fi

# shellcheck disable=SC1090
. "$SCRIPT"

assert_eq() {
  expected="$1"
  actual="$2"
  name="$3"
  if [ "$expected" != "$actual" ]; then
    echo "[FAIL] $name: expected '$expected', got '$actual'"
    exit 1
  fi
  echo "[PASS] $name"
}

PATH="/tmp/no-such-bin"
EVENTD_MODE=""
start_eventd --dry-run >/dev/null 2>&1
assert_eq "polling" "$EVENTD_MODE" "fallback to polling when inotify unavailable"

echo "[PASS] eventd_fallback_test"
