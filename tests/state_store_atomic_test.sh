#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/engine/state_store.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "[FAIL] state_store.sh not found"
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

TEST_DIR="/tmp/dexoat_state_store_test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

STATE_FILE="$TEST_DIR/state.json"
printf '%s' 'old' > "$STATE_FILE"
state_write_atomic "$STATE_FILE" '{"ok":true}'
assert_eq '{"ok":true}' "$(cat "$STATE_FILE")" "atomic write success"

READONLY_DIR="$TEST_DIR/readonly"
mkdir -p "$READONLY_DIR"
FAIL_FILE="$READONLY_DIR/state.json"
printf '%s' 'stable' > "$FAIL_FILE"
chmod 555 "$READONLY_DIR"

if state_write_atomic "$FAIL_FILE" '{"broken":true}' 2>/dev/null; then
  echo "[FAIL] expected write to fail on readonly directory"
  chmod 755 "$READONLY_DIR"
  exit 1
fi
assert_eq 'stable' "$(cat "$FAIL_FILE")" "failed write keeps original"
chmod 755 "$READONLY_DIR"

echo "[PASS] state_store_atomic_test"
