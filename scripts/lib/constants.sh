#!/system/bin/sh
# Shared constants for Dex2Oat module scripts.

MODULE_DIR="/data/adb/modules/dexoat_ks"
SCRIPT_DIR="$MODULE_DIR/scripts"
DATA_DIR="$MODULE_DIR/data"
LOG_DIR="$MODULE_DIR/logs"
CONFIG_DIR="$MODULE_DIR/configs"

STATE_FILE="$DATA_DIR/state.json"
QUEUE_FILE="$DATA_DIR/queue.json"
CONFIG_FILE_JSON="$DATA_DIR/config.json"
RULES_FILE="$DATA_DIR/rules.json"
EVENTS_FILE="$DATA_DIR/events.jsonl"
RUNTIME_LOG_JSON="$LOG_DIR/runtime.jsonl"

LOCK_DIR="$DATA_DIR/locks"
HEALTH_DIR="$DATA_DIR/health"
