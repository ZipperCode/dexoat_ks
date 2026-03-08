#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/engine/compiler.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "[FAIL] compiler.sh not found"
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

SETENFORCE_LOG=""
CMD_EXIT=0

getenforce() {
  echo "Enforcing"
}

setenforce() {
  if [ -z "$SETENFORCE_LOG" ]; then
    SETENFORCE_LOG="$1"
  else
    SETENFORCE_LOG="$SETENFORCE_LOG,$1"
  fi
  return 0
}

cmd() {
  return "$CMD_EXIT"
}

CMD_EXIT=0
SETENFORCE_LOG=""
compile_app_safe "com.example.ok" "speed" >/dev/null 2>&1
assert_eq "0,1" "$SETENFORCE_LOG" "selinux restore on success"

CMD_EXIT=1
SETENFORCE_LOG=""
if compile_app_safe "com.example.fail" "speed" >/dev/null 2>&1; then
  echo "[FAIL] compile should fail"
  exit 1
fi
assert_eq "0,1" "$SETENFORCE_LOG" "selinux restore on failure"

echo "[PASS] compiler_selinux_test"
