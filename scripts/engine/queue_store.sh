#!/system/bin/sh
# Queue storage with per-engine lock and running/requeue markers.

MODULE_DIR="/data/adb/modules/dexoat_ks"

QUEUE_FILE="${QUEUE_FILE:-$MODULE_DIR/data/queue.txt}"
LOCK_DIR="${LOCK_DIR:-$MODULE_DIR/data/locks}"
RUNNING_DIR="${RUNNING_DIR:-$MODULE_DIR/data/running}"

ensure_queue_store() {
  mkdir -p "$(dirname "$QUEUE_FILE")"
  mkdir -p "$LOCK_DIR"
  mkdir -p "$RUNNING_DIR"
  touch "$QUEUE_FILE"
}

_acquire_lock() {
  lock_path="$LOCK_DIR/engine.lock"
  while ! mkdir "$lock_path" 2>/dev/null; do
    sleep 1
  done
}

_release_lock() {
  lock_path="$LOCK_DIR/engine.lock"
  rmdir "$lock_path" 2>/dev/null || true
}

_remove_queue_entry() {
  package="$1"
  tmp_file="${QUEUE_FILE}.tmp.$$"
  awk -F'|' -v pkg="$package" '$1 != pkg {print $0}' "$QUEUE_FILE" > "$tmp_file"
  mv "$tmp_file" "$QUEUE_FILE"
}

enqueue_task() {
  package="$1"
  source="$2"

  [ -z "$package" ] && return 2
  [ -z "$source" ] && source="event"

  ensure_queue_store
  _acquire_lock

  if [ -f "$RUNNING_DIR/$package.running" ]; then
    touch "$RUNNING_DIR/$package.requeue"
    _release_lock
    echo "REQUEUE_MARKED"
    return 0
  fi

  _remove_queue_entry "$package"
  echo "$package|$source" >> "$QUEUE_FILE"

  _release_lock
  echo "ENQUEUED"
  return 0
}

mark_running() {
  package="$1"
  [ -z "$package" ] && return 2

  ensure_queue_store
  _acquire_lock
  _remove_queue_entry "$package"
  touch "$RUNNING_DIR/$package.running"
  _release_lock
  return 0
}

mark_finished() {
  package="$1"
  [ -z "$package" ] && return 2

  ensure_queue_store
  _acquire_lock

  rm -f "$RUNNING_DIR/$package.running"

  if [ -f "$RUNNING_DIR/$package.requeue" ]; then
    rm -f "$RUNNING_DIR/$package.requeue"
    _remove_queue_entry "$package"
    echo "$package|requeue" >> "$QUEUE_FILE"
  fi

  _release_lock
  return 0
}

is_requeue_after_finish() {
  package="$1"
  [ -f "$RUNNING_DIR/$package.requeue" ] && {
    echo "true"
    return 0
  }
  echo "false"
  return 0
}
