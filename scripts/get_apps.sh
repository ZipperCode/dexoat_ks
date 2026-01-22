#!/system/bin/sh
# 列出所有应用及其编译状态 - 优化版
# 输出格式: JSON

CONFIG_FILE="/data/adb/modules/dexoat_ks/configs/dexoat.conf"

# 获取配置
DEFAULT_MODE=$(grep "^default_mode=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
[ -z "$DEFAULT_MODE" ] && DEFAULT_MODE="speed"

# 开始 JSON 输出
echo '{"apps":['

# 仅获取用户应用（更快）
FIRST=true
pm list packages -3 2>/dev/null | while read -r package_line; do
  package=$(echo "$package_line" | sed 's/package://')
  [ -z "$package" ] && continue

  # 默认值
  is_system="false"
  label="$package"
  current_mode="none"
  is_compiled="false"
  desired_mode="$DEFAULT_MODE"
  needs_recompile="false"
  compile_time=""

  # 获取 APK 路径
  apk_path=$(pm path "$package" 2>/dev/null | head -1 | cut -d: -f2)

  if [ -n "$apk_path" ] && [ -f "$apk_path" ]; then
    # 检查 oat 目录（包含编译后的代码）
    oat_dir="${apk_path%/*}/oat"

    # 快速检查：测试 oat 目录是否存在
    if [ -d "$oat_dir" ]; then
      # 使用 ls 配合通配符检查文件（抑制错误，比 find 更快）
      # 检查是否存在任何 .odex 或 .vdex 文件
      odex_files=$(ls "$oat_dir"/*/*.odex 2>/dev/null | head -1)
      vdex_files=$(ls "$oat_dir"/*/*.vdex 2>/dev/null | head -1)

      if [ -n "$odex_files" ] || [ -n "$vdex_files" ]; then
        is_compiled="true"
        current_mode="speed"  # 简化检测（准确检测需要 oatdump，较慢）
      fi
    fi
  fi

  # 输出 JSON 条目
  if [ "$FIRST" = "true" ]; then
    FIRST=false
  else
    echo ","
  fi

  printf '{"packageName":"%s","label":"%s","isSystem":%s,"compileMode":"%s","desiredMode":"%s","isCompiled":%s,"needsRecompile":%s,"compileTime":"%s"}' \
    "$package" "$label" "$is_system" "$current_mode" "$desired_mode" "$is_compiled" "$needs_recompile" "$compile_time"
done

echo ']}'
