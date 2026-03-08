#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/engine/queue_store.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "[FAIL] queue_store.sh not found"
  exit 1
fi

# shellcheck disable=SC1090
. "$SCRIPT"

TEST_DIR="/tmp/dexoat_queue_test"
QUEUE_FILE="$TEST_DIR/queue.txt"
LOCK_DIR="$TEST_DIR/locks"
RUNNING_DIR="$TEST_DIR/running"
export QUEUE_FILE LOCK_DIR RUNNING_DIR

rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

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

enqueue_task "com.example.a" "event" >/dev/null
enqueue_task "com.example.a" "schedule" >/dev/null
count_a="$(grep -c '^com.example.a|' "$QUEUE_FILE" || true)"
assert_eq "1" "$count_a" "dedup keeps single queue item"

mark_running "com.example.a"
enqueue_task "com.example.a" "event" >/dev/null
requeue="$(is_requeue_after_finish "com.example.a")"
assert_eq "true" "$requeue" "running package marks requeue_after_finish"

echo "[PASS] queue_dedup_test"
