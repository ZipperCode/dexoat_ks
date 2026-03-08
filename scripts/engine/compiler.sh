#!/system/bin/sh
# Safe compile executor with SELinux restoration.

MODULE_DIR="/data/adb/modules/dexoat_ks"
SCRIPT_DIR="$MODULE_DIR/scripts"

if [ -f "$SCRIPT_DIR/logger.sh" ]; then
  # shellcheck disable=SC1090
  . "$SCRIPT_DIR/logger.sh"
fi

compile_app_safe() {
  package="$1"
  mode="$2"

  if [ -z "$package" ] || [ -z "$mode" ]; then
    [ "$(type -t log_error 2>/dev/null || true)" = "function" ] && log_error "compile_app_safe args invalid"
    return 2
  fi

  original_mode="$(getenforce 2>/dev/null || echo Enforcing)"
  switched="false"

  cleanup_selinux() {
    if [ "$switched" != "true" ]; then
      return
    fi

    if [ "$original_mode" = "Enforcing" ]; then
      setenforce 1 >/dev/null 2>&1 || true
    else
      setenforce 0 >/dev/null 2>&1 || true
    fi
  }

  trap cleanup_selinux EXIT INT TERM

  if [ "$original_mode" = "Enforcing" ]; then
    if setenforce 0 >/dev/null 2>&1; then
      switched="true"
    fi
  fi

  cmd package compile -m "$mode" "$package"
  rc=$?

  cleanup_selinux
  trap - EXIT INT TERM

  return "$rc"
}
