#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_MODULE_DIR="/tmp/dexoat_legacy_test"
rm -rf "$TEST_MODULE_DIR"
mkdir -p "$TEST_MODULE_DIR"

export DEXOAT_MODULE_DIR="$TEST_MODULE_DIR"

assert_contains() {
  haystack="$1"
  needle="$2"
  name="$3"
  echo "$haystack" | grep -Fq "$needle" || {
    echo "[FAIL] $name: missing '$needle'"
    exit 1
  }
  echo "[PASS] $name"
}

out_all="$(sh "$ROOT_DIR/scripts/compile_all.sh" manual 2>/dev/null || true)"
assert_contains "$out_all" '"success":true' 'compile_all shim success'
assert_contains "$out_all" '__ALL__' 'compile_all shim enqueue marker'

out_app="$(sh "$ROOT_DIR/scripts/compile_app.sh" com.example.legacy speed 2>/dev/null || true)"
assert_contains "$out_app" '"success":true' 'compile_app shim success'
assert_contains "$out_app" 'com.example.legacy' 'compile_app target package'

out_get="$(sh "$ROOT_DIR/scripts/get_apps.sh" 2>/dev/null || true)"
assert_contains "$out_get" '"success":true' 'get_apps shim success'
assert_contains "$out_get" '"count"' 'get_apps shim returns queue data'

echo "[PASS] legacy_compat_test"
