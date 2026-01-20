#!/system/bin/sh
# Centralized logging utility for Dex2Oat Manager
# Usage: source this script and call log_info, log_error, log_warn, log_debug

MODULE_DIR="/data/adb/modules/dexoat_ks"
LOG_FILE="$MODULE_DIR/logs/dexoat.log"
LOG_LEVEL_CONFIG="$MODULE_DIR/configs/dexoat.conf"

# Ensure log directory exists
mkdir -p "$MODULE_DIR/logs"

# Get log level from config, default to INFO
get_log_level() {
  if [ -f "$LOG_LEVEL_CONFIG" ]; then
    level=$(grep "^log_level=" "$LOG_LEVEL_CONFIG" 2>/dev/null | cut -d'=' -f2)
    echo "${level:-INFO}"
  else
    echo "INFO"
  fi
}

# Log level priority (lower number = higher priority)
# DEBUG=0, INFO=1, WARN=2, ERROR=3
get_level_priority() {
  case "$1" in
    DEBUG) echo 0 ;;
    INFO)  echo 1 ;;
    WARN)  echo 2 ;;
    ERROR) echo 3 ;;
    *)     echo 1 ;;  # Default to INFO
  esac
}

# Check if a message should be logged based on level
should_log() {
  message_level=$1
  config_level=$(get_log_level)

  message_priority=$(get_level_priority "$message_level")
  config_priority=$(get_level_priority "$config_level")

  [ "$message_priority" -ge "$config_priority" ]
}

# Main logging function
log() {
  level=$1
  shift
  message="$@"
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  if should_log "$level"; then
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
  fi

  # Also output to stdout for WebUI consumption
  echo "[$timestamp] [$level] $message"
}

# Convenience functions
log_info() {
  log "INFO" "$@"
}

log_error() {
  log "ERROR" "$@"
}

log_warn() {
  log "WARN" "$@"
}

log_debug() {
  log "DEBUG" "$@"
}
