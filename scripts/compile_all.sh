#!/system/bin/sh
# 批量编译
# Usage: compile_all.sh [manual|scheduled]

TRIGGER=${1:-manual}

# Source dependencies
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
. "$SCRIPT_DIR/logger.sh"
. "$SCRIPT_DIR/config_manager.sh"

log_info "开始批量编译 (trigger: $TRIGGER)"

# SELinux 处理函数
set_selinux_permissive() {
  log_debug "设置 SELinux 为宽容模式"
  setenforce 0 2>/dev/null
}

restore_selinux() {
  log_debug "恢复 SELinux 为严格模式"
  setenforce 1 2>/dev/null
}

# 设置 SELinux 为宽容模式（整个批量编译过程）
set_selinux_permissive
SELINUX_RESTORE=true

# 是否跳过编译
SKIP_COMPILED=$(get_config skip_compiled)
[ -z "$SKIP_COMPILED" ] && SKIP_COMPILED="true"
# 编译范围
COMPILE_SYSTEM_APPS=$(get_config compile_system_apps)
[ -z "$COMPILE_SYSTEM_APPS" ] && COMPILE_SYSTEM_APPS="false"
COMPILE_USER_APPS=$(get_config compile_user_apps)
[ -z "$COMPILE_USER_APPS" ] && COMPILE_USER_APPS="true"
# 并发数
PARALLEL_JOBS=$(get_config parallel_jobs)
[ -z "$PARALLEL_JOBS" ] && PARALLEL_JOBS=2

STORAGE_THRESHOLD=$(get_config storage_threshold)
[ -z "$STORAGE_THRESHOLD" ] && STORAGE_THRESHOLD=500

# 储存检查
free_space=$(df /data 2>/dev/null | tail -1 | awk '{print $4}')
if [ -n "$free_space" ]; then
  free_space_mb=$((free_space / 1024))

  if [ "$free_space_mb" -lt "$STORAGE_THRESHOLD" ]; then
    log_error "存储空间不足: ${free_space_mb}MB available, ${STORAGE_THRESHOLD}MB required"
    [ "$SELINUX_RESTORE" = "true" ] && restore_selinux
    echo "{\"success\": false, \"error\": \"存储空间不足: ${free_space_mb}MB available, ${STORAGE_THRESHOLD}MB required\"}"
    exit 1
  fi
fi

# 获取app列表状态
log_debug "获取所有app的编译状态"
APPS_JSON=$(sh "$SCRIPT_DIR/get_apps.sh" 2>/dev/null)

# Check if we got valid JSON
if ! echo "$APPS_JSON" | grep -q '"apps"'; then
  log_error "无法获取到app列表"
  [ "$SELINUX_RESTORE" = "true" ] && restore_selinux
  echo "{\"success\": false, \"error\": \"Failed to get app list\"}"
  exit 1
fi

# app数量
apps_count=$(echo "$APPS_JSON" | grep -o '"packageName"' | wc -l)
log_info "Total apps: $apps_count"

# 编译数量
compiled_count=0
# 跳过数量
skipped_count=0
# 失败数量
failed_count=0

# 临时文件跟踪进度
PROGRESS_FILE="/data/adb/modules/dexoat_ks/data/compile_progress.json"
mkdir -p "$(dirname "$PROGRESS_FILE")"
echo "{\"compiled\": [], \"skipped\": [], \"failed\": []}" > "$PROGRESS_FILE"

# Process each app from JSON
APPS_FLAT=$(echo "$APPS_JSON" | tr -d '\n')
APPS_LIST=$(echo "$APPS_FLAT" | sed 's/^.*"apps":[[:space:]]*\\[//' | sed 's/\\].*$//')

echo "$APPS_LIST" | sed 's/},{/}\n{/g' | while IFS= read -r app_json; do

  # 空行
  [ -z "$app_json" ] && continue

  # Parse JSON manually (simplified)
  package=$(echo "$app_json" | grep -o '"packageName": *"[^"]*"' | cut -d'"' -f4)
  is_system=$(echo "$app_json" | grep -o '"isSystem": *[^,}]*' | cut -d: -f2 | tr -d ' ')
  is_compiled=$(echo "$app_json" | grep -o '"isCompiled": *[^,}]*' | cut -d: -f2 | tr -d ' ')
  needs_recompile=$(echo "$app_json" | grep -o '"needsRecompile": *[^,}]*' | cut -d: -f2 | tr -d ' ')
  desired_mode=$(echo "$app_json" | grep -o '"desiredMode": *"[^"]*"' | cut -d'"' -f4)

  # Skip if package is empty
  [ -z "$package" ] && continue
  [ -z "$is_system" ] && is_system="false"

  # Skip by app type selection
  if [ "$is_system" = "true" ] && [ "$COMPILE_SYSTEM_APPS" != "true" ]; then
    log_debug "跳过 $package (系统应用已禁用)"
    skipped_count=$((skipped_count + 1))
    continue
  fi
  if [ "$is_system" = "false" ] && [ "$COMPILE_USER_APPS" != "true" ]; then
    log_debug "跳过 $package (第三方应用已禁用)"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  # Skip if already compiled and skip_compiled is enabled
  if [ "$SKIP_COMPILED" = "true" ] && [ "$is_compiled" = "true" ] && [ "$needs_recompile" = "false" ]; then
    log_debug "跳过 $package (已经编译)"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  # Compile app
  log_info "编译 $package 编译模式: $desired_mode"

  if sh "$SCRIPT_DIR/compile_app.sh" "$package" "$desired_mode" --no-selinux >/dev/null 2>&1; then
    log_info "成功编译 $package"
    compiled_count=$((compiled_count + 1))
  else
    log_error "编译失败 $package"
    failed_count=$((failed_count + 1))
  fi

  # Respect parallel job limit - wait a bit after each compilation
  sleep 2
done

log_info "批量编译完成: compiled=$compiled_count, skipped=$skipped_count, failed=$failed_count"

# 恢复 SELinux 为严格模式
[ "$SELINUX_RESTORE" = "true" ] && restore_selinux

# Output result as JSON
echo "{"
echo "  \"success\": true,"
echo "  \"trigger\": \"$TRIGGER\","
echo "  \"stats\": {"
echo "    \"total\": $apps_count,"
echo "    \"compiled\": $compiled_count,"
echo "    \"skipped\": $skipped_count,"
echo "    \"failed\": $failed_count"
echo "  }"
echo "}"
