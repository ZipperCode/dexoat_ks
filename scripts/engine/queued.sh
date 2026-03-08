#!/system/bin/sh
# Queue worker daemon (minimal scaffold for next tasks).

MODULE_DIR="/data/adb/modules/dexoat_ks"
SCRIPT_DIR="$MODULE_DIR/scripts"

# shellcheck disable=SC1090
. "$SCRIPT_DIR/engine/queue_store.sh"

start_queue_worker_once() {
  ensure_queue_store
  # Actual dequeue-execute loop will be implemented in later tasks.
  return 0
}

if [ "${1:-}" = "--once" ]; then
  start_queue_worker_once
fi
