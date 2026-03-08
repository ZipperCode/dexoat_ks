#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
API="$ROOT_DIR/scripts/api.sh"

if [ ! -f "$API" ]; then
  echo "[FAIL] api.sh missing"
  exit 1
fi

TEST_MODULE_DIR="/tmp/dexoat_api_test"
rm -rf "$TEST_MODULE_DIR"
mkdir -p "$TEST_MODULE_DIR/scripts"

# 让 api.sh 使用测试目录
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

out_get="$(sh "$API" get_config)"
assert_contains "$out_get" '"success":true' 'get_config success'
assert_contains "$out_get" '"code":"OK"' 'get_config code'
assert_contains "$out_get" '"data":' 'get_config data field'

out_set="$(sh "$API" set_config --key global_enabled --value true)"
assert_contains "$out_set" '"success":true' 'set_config success'

out_rule="$(sh "$API" upsert_rule --package com.example.app --mode speed --enabled true)"
assert_contains "$out_rule" '"success":true' 'upsert_rule success'

out_del="$(sh "$API" delete_rule --package com.example.app)"
assert_contains "$out_del" '"success":true' 'delete_rule success'

echo "[PASS] api_config_rules_test"
