#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
API="$ROOT_DIR/scripts/api.sh"

if [ ! -f "$API" ]; then
  echo "[FAIL] api.sh missing"
  exit 1
fi

TEST_MODULE_DIR="/tmp/dexoat_api_queue_test"
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

enq_out="$(sh "$API" enqueue --package com.example.q --source manual)"
assert_contains "$enq_out" '"success":true' 'enqueue success'

status_out="$(sh "$API" queue_status)"
assert_contains "$status_out" '"success":true' 'queue_status success'
assert_contains "$status_out" 'com.example.q' 'queue_status contains package'

history_out="$(sh "$API" task_history --page 1 --size 20)"
assert_contains "$history_out" '"success":true' 'task_history success'
assert_contains "$history_out" 'com.example.q' 'task_history contains package'

echo "[PASS] api_queue_history_test"
