#!/system/bin/sh
# List all apps with compilation status - SIMPLIFIED & OPTIMIZED
# Output: JSON format

CONFIG_FILE="/data/adb/modules/dexoat_ks/configs/dexoat.conf"

# Get settings
DEFAULT_MODE=$(grep "^default_mode=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
[ -z "$DEFAULT_MODE" ] && DEFAULT_MODE="speed"

# Start JSON
echo '{"apps":['

# Get only user apps (faster)
FIRST=true
pm list packages -3 2>/dev/null | while read -r package_line; do
  package=$(echo "$package_line" | sed 's/package://')
  [ -z "$package" ] && continue

  # Default values
  is_system="false"
  label="$package"
  current_mode="none"
  is_compiled="false"
  desired_mode="$DEFAULT_MODE"
  needs_recompile="false"
  compile_time=""

  # Quick check: does package have odex files?
  # Use pm path to get APK location
  apk_path=$(pm path "$package" 2>/dev/null | head -1 | cut -d: -f2)

  if [ -n "$apk_path" ]; then
    # Check for oat directory (contains compiled code)
    oat_dir="${apk_path%/*}/oat"

    if [ -d "$oat_dir" ]; then
      # Check if any odex/vdex files exist
      if ls "$oat_dir"/*/*.odex >/dev/null 2>&1 || ls "$oat_dir"/*/*.vdex >/dev/null 2>&1; then
        is_compiled="true"
        # Assume speed mode if compiled
        current_mode="speed"
      fi
    fi
  fi

  # Output JSON entry
  if [ "$FIRST" = "true" ]; then
    FIRST=false
  else
    echo ","
  fi

  printf '{"packageName":"%s","label":"%s","isSystem":%s,"compileMode":"%s","desiredMode":"%s","isCompiled":%s,"needsRecompile":%s,"compileTime":"%s"}' \
    "$package" "$label" "$is_system" "$current_mode" "$desired_mode" "$is_compiled" "$needs_recompile" "$compile_time"
done

echo ']}'
