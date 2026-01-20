#!/system/bin/sh
# Batch compilation with smart detection
# Usage: compile_all.sh [manual|scheduled]

TRIGGER=${1:-manual}

# Source dependencies
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
. "$SCRIPT_DIR/logger.sh"
. "$SCRIPT_DIR/config_manager.sh"

log_info "Starting batch compilation (trigger: $TRIGGER)"

# Get configuration
SKIP_COMPILED=$(get_config skip_compiled)
[ -z "$SKIP_COMPILED" ] && SKIP_COMPILED="true"

PARALLEL_JOBS=$(get_config parallel_jobs)
[ -z "$PARALLEL_JOBS" ] && PARALLEL_JOBS=2

STORAGE_THRESHOLD=$(get_config storage_threshold)
[ -z "$STORAGE_THRESHOLD" ] && STORAGE_THRESHOLD=500

# Check available storage
free_space=$(df /data 2>/dev/null | tail -1 | awk '{print $4}')
if [ -n "$free_space" ]; then
  free_space_mb=$((free_space / 1024))

  if [ "$free_space_mb" -lt "$STORAGE_THRESHOLD" ]; then
    log_error "Insufficient storage: ${free_space_mb}MB available, ${STORAGE_THRESHOLD}MB required"
    echo "{\"success\": false, \"error\": \"Insufficient storage: ${free_space_mb}MB available, ${STORAGE_THRESHOLD}MB required\"}"
    exit 1
  fi
fi

# Get app list with status
log_debug "Fetching app list with compilation status"
APPS_JSON=$(sh "$SCRIPT_DIR/get_apps.sh" 2>/dev/null)

# Check if we got valid JSON
if ! echo "$APPS_JSON" | grep -q '"apps"'; then
  log_error "Failed to get app list"
  echo "{\"success\": false, \"error\": \"Failed to get app list\"}"
  exit 1
fi

# Count apps
apps_count=$(echo "$APPS_JSON" | grep -o '"packageName"' | wc -l)
log_info "Total apps: $apps_count"

# Process apps
compiled_count=0
skipped_count=0
failed_count=0

# Use a temp file to track progress
PROGRESS_FILE="/data/adb/modules/dexoat_ks/data/compile_progress.json"
mkdir -p "$(dirname "$PROGRESS_FILE")"
echo "{\"compiled\": [], \"skipped\": [], \"failed\": []}" > "$PROGRESS_FILE"

# Process each app from JSON
echo "$APPS_JSON" | sed 's/^{.*"apps": \[//' | sed 's/\]}$//' | \
  sed 's/},{/}\n{/g' | while IFS= read -r app_json; do

  # Skip empty lines
  [ -z "$app_json" ] && continue

  # Parse JSON manually (simplified)
  package=$(echo "$app_json" | grep -o '"packageName": *"[^"]*"' | cut -d'"' -f4)
  is_compiled=$(echo "$app_json" | grep -o '"isCompiled": *[^,}]*' | cut -d: -f2 | tr -d ' ')
  needs_recompile=$(echo "$app_json" | grep -o '"needsRecompile": *[^,}]*' | cut -d: -f2 | tr -d ' ')
  desired_mode=$(echo "$app_json" | grep -o '"desiredMode": *"[^"]*"' | cut -d'"' -f4)

  # Skip if package is empty
  [ -z "$package" ] && continue

  # Skip if already compiled and skip_compiled is enabled
  if [ "$SKIP_COMPILED" = "true" ] && [ "$is_compiled" = "true" ] && [ "$needs_recompile" = "false" ]; then
    log_debug "Skipping $package (already compiled with correct mode)"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  # Compile app
  log_info "Compiling $package with mode: $desired_mode"

  if sh "$SCRIPT_DIR/compile_app.sh" "$package" "$desired_mode" >/dev/null 2>&1; then
    log_info "Successfully compiled $package"
    compiled_count=$((compiled_count + 1))
  else
    log_error "Failed to compile $package"
    failed_count=$((failed_count + 1))
  fi

  # Respect parallel job limit - wait a bit after each compilation
  sleep 2
done

log_info "Batch compilation complete: compiled=$compiled_count, skipped=$skipped_count, failed=$failed_count"

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
