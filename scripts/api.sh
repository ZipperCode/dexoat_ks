#!/system/bin/sh
# Unified API entrypoint for WebUI and CLI.

MODULE_DIR="${DEXOAT_MODULE_DIR:-/data/adb/modules/dexoat_ks}"
DATA_DIR="$MODULE_DIR/data"
CONFIG_JSON="$DATA_DIR/config.json"
RULES_DB="$DATA_DIR/rules.db"
QUEUE_DB="$DATA_DIR/queue.db"
TASK_HISTORY_DB="$DATA_DIR/task_history.db"

mkdir -p "$DATA_DIR"

init_store() {
  [ -f "$CONFIG_JSON" ] || printf '%s' '{}' > "$CONFIG_JSON"
  [ -f "$RULES_DB" ] || touch "$RULES_DB"
  [ -f "$QUEUE_DB" ] || touch "$QUEUE_DB"
  [ -f "$TASK_HISTORY_DB" ] || touch "$TASK_HISTORY_DB"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

json_ok() {
  message="$1"
  data="$2"
  msg_esc="$(json_escape "$message")"
  printf '{"success":true,"code":"OK","message":"%s","data":%s}\n' "$msg_esc" "$data"
}

json_err() {
  code="$1"
  message="$2"
  code_esc="$(json_escape "$code")"
  msg_esc="$(json_escape "$message")"
  printf '{"success":false,"code":"%s","message":"%s","data":{}}\n' "$code_esc" "$msg_esc"
}

json_set_key_value() {
  file="$1"
  key="$2"
  value="$3"

  raw="$(tr -d '\n\r\t' < "$file" 2>/dev/null || true)"
  [ -z "$raw" ] && raw='{}'

  if printf '%s' "$raw" | grep -q "\"$key\":"; then
    new="$(printf '%s' "$raw" | sed -E "s#\"$key\":\"[^\"]*\"#\"$key\":\"$value\"#")"
  else
    if [ "$raw" = "{}" ]; then
      new="{\"$key\":\"$value\"}"
    else
      new="${raw%}}"
      new="$new,\"$key\":\"$value\"}"
    fi
  fi

  printf '%s' "$new" > "$file"
}

parse_kv_args() {
  key=""
  value=""
  package=""
  mode=""
  enabled=""
  source=""
  page="1"
  size="20"

  while [ $# -gt 0 ]; do
    case "$1" in
      --key)
        shift; key="$1" ;;
      --value)
        shift; value="$1" ;;
      --package)
        shift; package="$1" ;;
      --mode)
        shift; mode="$1" ;;
      --enabled)
        shift; enabled="$1" ;;
      --source)
        shift; source="$1" ;;
      --page)
        shift; page="$1" ;;
      --size)
        shift; size="$1" ;;
    esac
    shift || true
  done
}

build_queue_items_json() {
  first="true"
  printf '['
  while IFS='|' read -r pkg src ts; do
    [ -z "$pkg" ] && continue
    if [ "$first" = "true" ]; then
      first="false"
    else
      printf ','
    fi
    printf '{"package":"%s","source":"%s","enqueueTime":"%s"}' \
      "$(json_escape "$pkg")" "$(json_escape "$src")" "$(json_escape "$ts")"
  done < "$QUEUE_DB"
  printf ']'
}

build_history_items_json() {
  first="true"
  printf '['
  while IFS='|' read -r ts pkg src action; do
    [ -z "$pkg" ] && continue
    if [ "$first" = "true" ]; then
      first="false"
    else
      printf ','
    fi
    printf '{"time":"%s","package":"%s","source":"%s","action":"%s"}' \
      "$(json_escape "$ts")" "$(json_escape "$pkg")" "$(json_escape "$src")" "$(json_escape "$action")"
  done < "$TASK_HISTORY_DB"
  printf ']'
}

cmd_get_config() {
  cfg="$(cat "$CONFIG_JSON" 2>/dev/null || echo '{}')"
  json_ok "config loaded" "$cfg"
}

cmd_set_config() {
  parse_kv_args "$@"

  if [ -z "$key" ] || [ -z "$value" ]; then
    json_err "INVALID_ARGS" "set_config requires --key and --value"
    return 1
  fi

  key_esc="$(json_escape "$key")"
  val_esc="$(json_escape "$value")"

  json_set_key_value "$CONFIG_JSON" "$key_esc" "$val_esc"
  json_ok "config updated" "{\"key\":\"$key_esc\",\"value\":\"$val_esc\"}"
}

cmd_upsert_rule() {
  parse_kv_args "$@"

  if [ -z "$package" ]; then
    json_err "INVALID_ARGS" "upsert_rule requires --package"
    return 1
  fi

  [ -z "$mode" ] && mode="speed"
  [ -z "$enabled" ] && enabled="true"

  tmp_file="${RULES_DB}.tmp.$$"
  grep -v "^$package|" "$RULES_DB" > "$tmp_file" 2>/dev/null || true
  printf '%s|%s|%s\n' "$package" "$mode" "$enabled" >> "$tmp_file"
  mv "$tmp_file" "$RULES_DB"

  json_ok "rule upserted" "{\"package\":\"$(json_escape "$package")\",\"mode\":\"$(json_escape "$mode")\",\"enabled\":\"$(json_escape "$enabled")\"}"
}

cmd_delete_rule() {
  parse_kv_args "$@"

  if [ -z "$package" ]; then
    json_err "INVALID_ARGS" "delete_rule requires --package"
    return 1
  fi

  tmp_file="${RULES_DB}.tmp.$$"
  grep -v "^$package|" "$RULES_DB" > "$tmp_file" 2>/dev/null || true
  mv "$tmp_file" "$RULES_DB"

  json_ok "rule deleted" "{\"package\":\"$(json_escape "$package")\"}"
}

cmd_enqueue() {
  parse_kv_args "$@"

  if [ -z "$package" ]; then
    json_err "INVALID_ARGS" "enqueue requires --package"
    return 1
  fi

  [ -z "$source" ] && source="manual"
  now="$(date '+%Y-%m-%dT%H:%M:%S')"

  tmp_file="${QUEUE_DB}.tmp.$$"
  grep -v "^$package|" "$QUEUE_DB" > "$tmp_file" 2>/dev/null || true
  printf '%s|%s|%s\n' "$package" "$source" "$now" >> "$tmp_file"
  mv "$tmp_file" "$QUEUE_DB"

  printf '%s|%s|%s|%s\n' "$now" "$package" "$source" "enqueue" >> "$TASK_HISTORY_DB"

  json_ok "task enqueued" "{\"package\":\"$(json_escape "$package")\",\"source\":\"$(json_escape "$source")\"}"
}

cmd_queue_status() {
  count="$(awk -F'|' 'NF >= 2 { c++ } END { print c + 0 }' "$QUEUE_DB" 2>/dev/null)"
  items="$(build_queue_items_json)"
  json_ok "queue status" "{\"count\":$count,\"items\":$items}"
}

cmd_task_history() {
  parse_kv_args "$@"
  items="$(build_history_items_json)"
  json_ok "task history" "{\"page\":$page,\"size\":$size,\"items\":$items}"
}

main() {
  init_store

  cmd="${1:-}"
  shift || true

  case "$cmd" in
    get_config) cmd_get_config "$@" ;;
    set_config) cmd_set_config "$@" ;;
    upsert_rule) cmd_upsert_rule "$@" ;;
    delete_rule) cmd_delete_rule "$@" ;;
    enqueue) cmd_enqueue "$@" ;;
    queue_status) cmd_queue_status "$@" ;;
    task_history) cmd_task_history "$@" ;;
    *)
      json_err "UNKNOWN_COMMAND" "unsupported command: $cmd"
      return 1
      ;;
  esac
}

main "$@"
