#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SERVICE_SH="$ROOT_DIR/service.sh"

TEST_DIR="/tmp/dexoat_service_test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

export DEXOAT_MODULE_DIR="$TEST_DIR/module"
export DEXOAT_SERVICE_NO_MAIN="true"
mkdir -p "$DEXOAT_MODULE_DIR"

# shellcheck disable=SC1090
. "$SERVICE_SH"

assert_true() {
  cond="$1"
  name="$2"
  if [ "$cond" != "true" ]; then
    echo "[FAIL] $name"
    exit 1
  fi
  echo "[PASS] $name"
}

assert_not_eq() {
  a="$1"
  b="$2"
  name="$3"
  if [ "$a" = "$b" ]; then
    echo "[FAIL] $name"
    exit 1
  fi
  echo "[PASS] $name"
}

QUEUED_COMMAND="sleep 120"
start_managed_component "queued" "$QUEUED_COMMAND" "$QUEUED_HEARTBEAT"
old_pid="$(cat "$PID_DIR/queued.pid")"
kill "$old_pid"
sleep 1

RECOVERY_TRIGGERED="false"
supervise_component "queued" "$QUEUED_COMMAND" "$QUEUED_HEARTBEAT" 120
new_pid="$(cat "$PID_DIR/queued.pid")"

assert_true "$RECOVERY_TRIGGERED" "recovery triggered"
assert_not_eq "$old_pid" "$new_pid" "pid replaced after recovery"

kill "$new_pid" 2>/dev/null || true

echo "[PASS] service_recovery_test"
