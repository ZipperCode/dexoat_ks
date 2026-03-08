#!/system/bin/sh
# 列出应用及其编译状态（支持过滤与分页）
# Usage: get_apps.sh [--type config|user|system|all] [--filter all|user|system|compiled|uncompiled|needs-recompile]
#                    [--search <keyword>] [--offset N] [--limit N]

CONFIG_FILE="/data/adb/modules/dexoat_ks/configs/dexoat.conf"
TYPE="config"
FILTER="all"
SEARCH=""
OFFSET=0
LIMIT=0

# 获取配置
DEFAULT_MODE=$(grep "^default_mode=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
[ -z "$DEFAULT_MODE" ] && DEFAULT_MODE="speed"
COMPILE_USER_APPS=$(grep "^compile_user_apps=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
[ -z "$COMPILE_USER_APPS" ] && COMPILE_USER_APPS="true"
COMPILE_SYSTEM_APPS=$(grep "^compile_system_apps=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
[ -z "$COMPILE_SYSTEM_APPS" ] && COMPILE_SYSTEM_APPS="false"

# 参数处理
while [ $# -gt 0 ]; do
  case "$1" in
    --type)
      shift
      TYPE="$1"
      ;;
    --type=*)
      TYPE="${1#--type=}"
      ;;
    --filter)
      shift
      FILTER="$1"
      ;;
    --filter=*)
      FILTER="${1#--filter=}"
      ;;
    --search)
      shift
      SEARCH="$1"
      ;;
    --search=*)
      SEARCH="${1#--search=}"
      ;;
    --offset)
      shift
      OFFSET="$1"
      ;;
    --offset=*)
      OFFSET="${1#--offset=}"
      ;;
    --limit)
      shift
      LIMIT="$1"
      ;;
    --limit=*)
      LIMIT="${1#--limit=}"
      ;;
  esac
  shift
  done

[ -z "$OFFSET" ] && OFFSET=0
[ -z "$LIMIT" ] && LIMIT=0

case "$TYPE" in
  user)
    INCLUDE_USER="true"
    INCLUDE_SYSTEM="false"
    ;;
  system)
    INCLUDE_USER="false"
    INCLUDE_SYSTEM="true"
    ;;
  all)
    INCLUDE_USER="true"
    INCLUDE_SYSTEM="true"
    ;;
  *)
    INCLUDE_USER="$COMPILE_USER_APPS"
    INCLUDE_SYSTEM="$COMPILE_SYSTEM_APPS"
    ;;
esac

FILTER_NEEDS_STATUS="false"
case "$FILTER" in
  compiled|uncompiled|needs-recompile)
    FILTER_NEEDS_STATUS="true"
    ;;
esac

FIRST=true
MATCH_INDEX=0
EMITTED=0
HAS_MORE="false"
PROCESSED_ALL="true"
STOP="false"

check_compiled() {
  current_mode="none"
  is_compiled="false"
  compile_time=""

  apk_path=$(pm path "$package" 2>/dev/null | head -1 | cut -d: -f2)

  if [ -n "$apk_path" ] && [ -f "$apk_path" ]; then
    oat_dir="${apk_path%/*}/oat"

    if [ -d "$oat_dir" ]; then
      odex_files=$(ls "$oat_dir"/*/*.odex 2>/dev/null | head -1)
      vdex_files=$(ls "$oat_dir"/*/*.vdex 2>/dev/null | head -1)

      if [ -n "$odex_files" ] || [ -n "$vdex_files" ]; then
        is_compiled="true"
        current_mode="speed"
      fi
    fi
  fi
}

matches_filter() {
  case "$FILTER" in
    compiled)
      [ "$is_compiled" = "true" ]
      return
      ;;
    uncompiled)
      [ "$is_compiled" = "false" ]
      return
      ;;
    needs-recompile)
      [ "$needs_recompile" = "true" ]
      return
      ;;
    *)
      return 0
      ;;
  esac
}

emit_json() {
  if [ "$FIRST" = "true" ]; then
    FIRST=false
  else
    echo ","
  fi

  printf '{"packageName":"%s","label":"%s","isSystem":%s,"compileMode":"%s","desiredMode":"%s","isCompiled":%s,"needsRecompile":%s,"compileTime":"%s"}' \
    "$package" "$label" "$is_system" "$current_mode" "$desired_mode" "$is_compiled" "$needs_recompile" "$compile_time"
}

process_package() {
  package_line=$1
  app_is_system=$2

  package=$(echo "$package_line" | sed 's/package://')
  [ -z "$package" ] && return

  if [ -n "$SEARCH" ]; then
    echo "$package" | grep -Fqi -- "$SEARCH" || return
  fi

  # 默认值
  is_system="$app_is_system"
  label="$package"
  desired_mode="$DEFAULT_MODE"
  needs_recompile="false"

  if [ "$FILTER_NEEDS_STATUS" = "true" ]; then
    check_compiled
    matches_filter || return
  fi

  if [ "$LIMIT" -le 0 ]; then
    if [ "$FILTER_NEEDS_STATUS" != "true" ]; then
      check_compiled
    fi
    MATCH_INDEX=$((MATCH_INDEX + 1))
    emit_json
    return
  fi

  if [ "$MATCH_INDEX" -lt "$OFFSET" ]; then
    MATCH_INDEX=$((MATCH_INDEX + 1))
    return
  fi

  if [ "$EMITTED" -lt "$LIMIT" ]; then
    if [ "$FILTER_NEEDS_STATUS" != "true" ]; then
      check_compiled
    fi
    emit_json
    MATCH_INDEX=$((MATCH_INDEX + 1))
    EMITTED=$((EMITTED + 1))
    return
  fi

  HAS_MORE="true"
  PROCESSED_ALL="false"
  STOP="true"
}

# 开始 JSON 输出
echo '{"apps":['

if [ "$INCLUDE_USER" = "true" ]; then
  while read -r package_line; do
    [ -z "$package_line" ] && continue
    process_package "$package_line" "false"
    [ "$STOP" = "true" ] && break
  done <<EOF
$(pm list packages -3 2>/dev/null)
EOF
fi

if [ "$STOP" != "true" ] && [ "$INCLUDE_SYSTEM" = "true" ]; then
  while read -r package_line; do
    [ -z "$package_line" ] && continue
    process_package "$package_line" "true"
    [ "$STOP" = "true" ] && break
  done <<EOF
$(pm list packages -s 2>/dev/null)
EOF
fi

if [ "$LIMIT" -gt 0 ] && [ "$PROCESSED_ALL" != "true" ]; then
  total_count=-1
else
  total_count=$MATCH_INDEX
fi

printf '],"total": %s, "hasMore": %s}\n' "$total_count" "$HAS_MORE"
