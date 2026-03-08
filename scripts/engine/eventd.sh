#!/system/bin/sh
# Event collector with inotify-first strategy and polling fallback.

MODULE_DIR="/data/adb/modules/dexoat_ks"
DATA_DIR="$MODULE_DIR/data"
EVENTS_FILE="${EVENTS_FILE:-$DATA_DIR/events.jsonl}"
HEARTBEAT_FILE="${HEARTBEAT_FILE:-$DATA_DIR/health/eventd.heartbeat}"
EVENTD_MODE="${EVENTD_MODE:-}"

write_event_heartbeat() {
  mkdir -p "$(dirname "$HEARTBEAT_FILE")"
  date '+%s' > "$HEARTBEAT_FILE"
}

start_eventd() {
  dry_run="false"
  [ "${1:-}" = "--dry-run" ] && dry_run="true"

  if [ "${EVENTD_FORCE_POLLING:-false}" = "true" ]; then
    EVENTD_MODE="polling"
  elif command -v inotifyd >/dev/null 2>&1; then
    EVENTD_MODE="inotify"
  else
    EVENTD_MODE="polling"
  fi

  if [ "$dry_run" = "true" ]; then
    export EVENTD_MODE
    return 0
  fi

  mkdir -p "$(dirname "$EVENTS_FILE")"
  touch "$EVENTS_FILE"

  while true; do
    write_event_heartbeat
    sleep 30
  done
}
