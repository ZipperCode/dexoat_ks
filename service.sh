#!/system/bin/sh
# Dex2Oat service supervisor: starts and recovers engine daemons.

export PATH="/data/adb/ksu/bin/busybox:$PATH"
export ASH_STANDALONE=1

MODULE_DIR="${DEXOAT_MODULE_DIR:-/data/adb/modules/dexoat_ks}"
SCRIPT_DIR="$MODULE_DIR/scripts"
DATA_DIR="$MODULE_DIR/data"
HEALTH_DIR="$DATA_DIR/health"
PID_DIR="$DATA_DIR/pids"

EVENTD_HEARTBEAT="$HEALTH_DIR/eventd.heartbeat"
QUEUED_HEARTBEAT="$HEALTH_DIR/queued.heartbeat"

COMPONENT_TIMEOUT_SECONDS="${COMPONENT_TIMEOUT_SECONDS:-180}"
SUPERVISE_INTERVAL_SECONDS="${SUPERVISE_INTERVAL_SECONDS:-15}"

EVENTD_COMMAND="${EVENTD_COMMAND:-sh '$SCRIPT_DIR/engine/eventd.sh'}"
QUEUED_COMMAND="${QUEUED_COMMAND:-while true; do sh '$SCRIPT_DIR/engine/queued.sh' --once; date '+%s' > '$QUEUED_HEARTBEAT'; sleep 5; done}"

if [ -f "$SCRIPT_DIR/logger.sh" ]; then
  # shellcheck disable=SC1090
  . "$SCRIPT_DIR/logger.sh"
fi

log_info_safe() {
  if [ "$(type -t log_info 2>/dev/null || true)" = "function" ]; then
    log_info "$@"
  else
    printf '[INFO] %s\n' "$*"
  fi
}

log_warn_safe() {
  if [ "$(type -t log_warn 2>/dev/null || true)" = "function" ]; then
    log_warn "$@"
  else
    printf '[WARN] %s\n' "$*"
  fi
}

ensure_runtime_dirs() {
  mkdir -p "$DATA_DIR" "$HEALTH_DIR" "$PID_DIR"
}

is_pid_alive() {
  pid="$1"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

start_managed_component() {
  name="$1"
  command="$2"
  heartbeat_file="$3"

  ensure_runtime_dirs

  sh -c "$command" >/dev/null 2>&1 &
  new_pid="$!"

  printf '%s' "$new_pid" > "$PID_DIR/$name.pid"
  date '+%s' > "$heartbeat_file"

  log_info_safe "started $name (pid=$new_pid)"
}

should_restart_component() {
  pid_file="$1"
  heartbeat_file="$2"
  timeout_seconds="$3"

  [ -f "$pid_file" ] || {
    echo "true"
    return 0
  }

  pid="$(cat "$pid_file" 2>/dev/null || true)"
  is_pid_alive "$pid" || {
    echo "true"
    return 0
  }

  [ -f "$heartbeat_file" ] || {
    echo "true"
    return 0
  }

  heartbeat_ts="$(cat "$heartbeat_file" 2>/dev/null || true)"
  now_ts="$(date '+%s')"

  case "$heartbeat_ts" in
    ''|*[!0-9]*)
      echo "true"
      return 0
      ;;
  esac

  age=$((now_ts - heartbeat_ts))
  if [ "$age" -gt "$timeout_seconds" ]; then
    echo "true"
  else
    echo "false"
  fi
}

supervise_component() {
  name="$1"
  command="$2"
  heartbeat_file="$3"
  timeout_seconds="$4"

  pid_file="$PID_DIR/$name.pid"
  need_restart="$(should_restart_component "$pid_file" "$heartbeat_file" "$timeout_seconds")"

  if [ "$need_restart" = "true" ]; then
    old_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if is_pid_alive "$old_pid"; then
      kill "$old_pid" 2>/dev/null || true
    fi

    start_managed_component "$name" "$command" "$heartbeat_file"
    RECOVERY_TRIGGERED="true"
    log_warn_safe "recovered $name"
    return 0
  fi

  RECOVERY_TRIGGERED="false"
  return 0
}

supervise_once() {
  supervise_component "eventd" "$EVENTD_COMMAND" "$EVENTD_HEARTBEAT" "$COMPONENT_TIMEOUT_SECONDS"
  supervise_component "queued" "$QUEUED_COMMAND" "$QUEUED_HEARTBEAT" "$COMPONENT_TIMEOUT_SECONDS"
}

wait_for_boot_complete() {
  if ! command -v getprop >/dev/null 2>&1; then
    return 0
  fi

  i=1
  while [ "$i" -le 60 ]; do
    if [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ]; then
      return 0
    fi
    sleep 5
    i=$((i + 1))
  done

  log_warn_safe "boot completion wait timeout"
}

main() {
  ensure_runtime_dirs

  if [ "${DEXOAT_SKIP_BOOT_WAIT:-false}" != "true" ]; then
    wait_for_boot_complete
  fi

  start_managed_component "eventd" "$EVENTD_COMMAND" "$EVENTD_HEARTBEAT"
  start_managed_component "queued" "$QUEUED_COMMAND" "$QUEUED_HEARTBEAT"

  while true; do
    supervise_once
    sleep "$SUPERVISE_INTERVAL_SECONDS"
  done
}

if [ "${DEXOAT_SERVICE_NO_MAIN:-false}" = "true" ]; then
  return 0 2>/dev/null || exit 0
fi

main "$@"
