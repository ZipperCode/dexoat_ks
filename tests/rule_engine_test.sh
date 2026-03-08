#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/engine/rule_engine.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "[FAIL] rule_engine.sh not found"
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

assert_eq "SKIP_GLOBAL_DISABLED" "$(rule_decide false user true false '' speed)" "global disabled"
assert_eq "SKIP_EXCLUDED" "$(rule_decide true user true true '' speed)" "excluded app"
assert_eq "SKIP_SCOPE_DISABLED" "$(rule_decide true system false false '' speed)" "scope disabled"
assert_eq "EXECUTE:verify" "$(rule_decide true user true false verify speed)" "forced mode"
assert_eq "EXECUTE:speed" "$(rule_decide true user true false '' speed)" "default mode"

echo "[PASS] rule_engine_test"
