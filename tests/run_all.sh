#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

sh "$ROOT_DIR/tests/rule_engine_test.sh"
sh "$ROOT_DIR/tests/compiler_selinux_test.sh"
sh "$ROOT_DIR/tests/queue_dedup_test.sh"
sh "$ROOT_DIR/tests/state_store_atomic_test.sh"
sh "$ROOT_DIR/tests/eventd_fallback_test.sh"
sh "$ROOT_DIR/tests/api_config_rules_test.sh"
sh "$ROOT_DIR/tests/api_queue_history_test.sh"
sh "$ROOT_DIR/tests/service_recovery_test.sh"
sh "$ROOT_DIR/tests/legacy_compat_test.sh"

echo "[PASS] run_all"
