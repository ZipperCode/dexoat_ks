#!/system/bin/sh
# Compile a single app with specified dex2oat mode
# Usage: compile_app.sh <package_name> <mode>
# Modes: speed, verify, speed-profile

PACKAGE=$1
MODE=$2

# Source logger and config manager
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
. "$SCRIPT_DIR/logger.sh"

if [ -z "$PACKAGE" ] || [ -z "$MODE" ]; then
  log_error "Usage: compile_app.sh <package_name> <mode>"
  exit 1
fi

log_info "Compiling $PACKAGE with mode: $MODE"

# Validate package exists
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
    log_error "Invalid compilation mode: $MODE (valid: speed, verify, speed-profile)"
    exit 1
    ;;
esac

# Execute compilation
log_debug "Executing: cmd package compile $COMPILE_MODE $PACKAGE"
cmd package compile $COMPILE_MODE $PACKAGE 2>&1 | while read -r line; do
  log_debug "$line"
done

# Check exit code
if [ $? -eq 0 ]; then
  log_info "Compilation started successfully for $PACKAGE"
  echo "{\"success\": true, \"package\": \"$PACKAGE\", \"mode\": \"$MODE\"}"
else
  log_error "Compilation failed for $PACKAGE"
  echo "{\"success\": false, \"package\": \"$PACKAGE\", \"error\": \"Compilation command failed\"}"
  exit 1
fi
