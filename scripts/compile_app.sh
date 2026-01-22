#!/system/bin/sh
# 使用指定的 dex2oat 模式编译单个应用程序
# Usage: compile_app.sh <package_name> <mode> [--no-selinux]
# Modes: speed, verify, speed-profile
# --no-selinux: Skip SELinux handling (for batch compilation)

PACKAGE=$1
MODE=$2
NO_SELINUX=$3

# 获取配置
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
. "$SCRIPT_DIR/logger.sh"

if [ -z "$PACKAGE" ] || [ -z "$MODE" ]; then
  log_error "Usage: compile_app.sh <package_name> <mode> [--no-selinux]"
  exit 1
fi

# SELinux 处理函数
set_selinux_permissive() {
  log_debug "设置 SELinux 为宽容模式"
  setenforce 0 2>/dev/null
}

restore_selinux() {
  log_debug "恢复 SELinux 为严格模式"
  setenforce 1 2>/dev/null
}

# 设置 SELinux 为宽容模式（如果未跳过）
if [ "$NO_SELINUX" != "--no-selinux" ]; then
  set_selinux_permissive
  SELINUX_RESTORE=true
else
  SELINUX_RESTORE=false
fi

log_info "Compiling $PACKAGE with mode: $MODE"

# 包检查
if ! pm list packages | grep -q "package:$PACKAGE"; then
  log_error "Package not found: $PACKAGE"
  exit 1
fi

# Map mode to correct compile flag
case $MODE in
  speed)
    COMPILE_MODE="-m speed"
    ;;
  verify)
    COMPILE_MODE="-m verify"
    ;;
  speed-profile)
    COMPILE_MODE="-m speed-profile"
    ;;
  *)
    log_error "编译模式错误: $MODE (valid: speed, verify, speed-profile)"
    exit 1
    ;;
esac

# Execute compilation
log_debug "执行编译: cmd package compile $COMPILE_MODE $PACKAGE"
cmd package compile $COMPILE_MODE $PACKAGE 2>&1 | while read -r line; do
  log_debug "$line"
done

# Check exit code
if [ $? -eq 0 ]; then
  log_info "编译完成 $PACKAGE"
  # 恢复 SELinux
  [ "$SELINUX_RESTORE" = "true" ] && restore_selinux
  echo "{\"success\": true, \"package\": \"$PACKAGE\", \"mode\": \"$MODE\"}"
else
  log_error "编译失败 $PACKAGE"
  # 恢复 SELinux
  [ "$SELINUX_RESTORE" = "true" ] && restore_selinux
  echo "{\"success\": false, \"package\": \"$PACKAGE\", \"error\": \"Compilation command failed\"}"
  exit 1
fi
