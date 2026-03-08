#!/system/bin/sh
# Atomic persistence utilities for state/config files.

state_write_atomic() {
  file_path="$1"
  payload="$2"

  [ -z "$file_path" ] && return 2

  dir_path="$(dirname "$file_path")"
  if [ ! -d "$dir_path" ]; then
    mkdir -p "$dir_path" || return 1
  fi

  tmp_file="${file_path}.tmp.$$"

  if ! printf '%s' "$payload" > "$tmp_file"; then
    rm -f "$tmp_file" 2>/dev/null || true
    return 1
  fi

  sync "$tmp_file" >/dev/null 2>&1 || true

  if ! mv "$tmp_file" "$file_path"; then
    rm -f "$tmp_file" 2>/dev/null || true
    return 1
  fi

  return 0
}
