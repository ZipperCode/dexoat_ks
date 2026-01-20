#!/system/bin/sh
# Remove all dex2oat compilations and reset apps to default state

# Source dependencies
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
. "$SCRIPT_DIR/logger.sh"

log_info "Starting un-compilation of all apps"

# Check if running interactively
confirm_or_exit() {
  if [ -t 0 ]; then
    echo ""
    echo "⚠️  WARNING: This will remove all dex2oat compilations."
    echo "Apps will run slower until they are recompiled."
    echo ""
    echo -n "Type 'yes' to continue: "
    read -r response
    if [ "$response" != "yes" ]; then
      log_info "Un-compilation cancelled by user"
      echo "Un-compilation cancelled"
      exit 0
    fi
  fi
}

confirm_or_exit

# Get list of compiled apps
log_debug "Finding compiled apps"
compiled_apps=$(pm list packages 2>/dev/null | sed 's/package://')

count=0
failed=0

for package in $compiled_apps; do
  # Check if package is actually compiled
  app_path=$(pm path "$package" 2>/dev/null | cut -d: -f2 | head -1)
  if [ -n "$app_path" ]; then
    odex_count=$(find "$app_path" -name "*.odex" 2>/dev/null | wc -l)
    if [ "$odex_count" -gt 0 ]; then
      log_info "Removing compilation for $package"

      # Force re-opt with verify mode (lightest compilation)
      if cmd package compile -m verify --reset "$package" >/dev/null 2>&1; then
        log_info "Successfully un-compiled $package"
        count=$((count + 1))
      else
        log_error "Failed to un-compile $package"
        failed=$((failed + 1))
      fi
    fi
  fi
done

log_info "Un-compilation complete: $count apps processed, $failed failed"

# Clear ART cache
log_info "Clearing ART cache"
if [ -d /data/dalvik-cache ]; then
  rm -rf /data/dalvik-cache/* 2>/dev/null
  log_info "ART cache cleared"
fi

log_info "Reboot recommended for changes to take full effect"

# Output result
echo "{"
echo "  \"success\": true,"
echo "  \"processed\": $count,"
echo "  \"failed\": $failed"
echo "}"

echo ""
echo "Un-compilation complete!"
echo "Processed: $count apps"
echo "Failed: $failed apps"
echo "Reboot recommended for changes to take full effect"
