#!/system/bin/sh
# Dex2Oat Manager Service Script
# Runs on module boot to initialize logging, scheduling, and optional boot compilation

MODULE_DIR="/data/adb/modules/dexoat_ks"
SCRIPT_DIR="$MODULE_DIR/scripts"
CONFIG_FILE="$MODULE_DIR/configs/dexoat.conf"
PID_FILE="$MODULE_DIR/data/scheduler.pid"

# Source dependencies
. "$SCRIPT_DIR/logger.sh"
. "$SCRIPT_DIR/config_manager.sh"

# Ensure directories exist
mkdir -p "$MODULE_DIR/logs"
mkdir -p "$MODULE_DIR/data"

# Wait for system to be fully booted
wait_for_boot_complete() {
  # Wait for boot to complete (max 5 minutes)
  for i in $(seq 1 60); do
    if [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ]; then
      log_info "System boot completed"
      return 0
    fi
    log_debug "Waiting for boot to complete... ($i/60)"
    sleep 5
  done

  log_warn "Boot completion timeout, proceeding anyway"
}

# Rotate logs if they get too large
rotate_logs() {
  LOG_FILE="$MODULE_DIR/logs/dexoat.log"

  if [ ! -f "$LOG_FILE" ]; then
    return
  fi

  size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)

  # Rotate if size exceeds 5MB
  if [ "$size" -gt 5242880 ]; then
    log_info "Rotating logs (size: $size bytes)"

    # Keep 5 rotated logs
    for i in 4 3 2 1; do
      if [ -f "$LOG_FILE.$i" ]; then
        mv "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))" 2>/dev/null
      fi
    done

    mv "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null
  fi
}

# Parse cron schedule and check if should run now
should_run_now() {
  schedule="$1"

  # Parse schedule: minute hour day month weekday
  minute=$(echo "$schedule" | awk '{print $1}')
  hour=$(echo "$schedule" | awk '{print $2}')
  day=$(echo "$schedule" | awk '{print $3}')
  month=$(echo "$schedule" | awk '{print $4}')
  weekday=$(echo "$schedule" | awk '{print $5}')

  # Get current time
  current_minute=$(date '+%M')
  current_hour=$(date '+%H')
  current_day=$(date '+%d')
  current_month=$(date '+%m')
  current_weekday=$(date '+%u')  # 1-7 (Mon-Sun)

  # Check each field (support wildcards *)
  check_field() {
    field_value=$1
    current=$2

    # Wildcard matches everything
    if [ "$field_value" = "*" ]; then
      return 0
    fi

    # Exact match
    if [ "$field_value" = "$current" ]; then
      return 0
    fi

    # Range match (e.g., 1-5)
    if echo "$field_value" | grep -qE '^[0-9]+-[0-9]+$'; then
      start=$(echo "$field_value" | cut -d- -f1)
      end=$(echo "$field_value" | cut -d- -f2)
      if [ "$current" -ge "$start" ] && [ "$current" -le "$end" ]; then
        return 0
      fi
    fi

    return 1
  }

  # Check all fields
  if check_field "$minute" "$current_minute" && \
     check_field "$hour" "$current_hour" && \
     check_field "$day" "$current_day" && \
     check_field "$month" "$current_month" && \
     check_field "$weekday" "$current_weekday"; then
    return 0
  fi

  return 1
}

# Perform boot compilation
boot_compile() {
  log_info "Starting boot compilation"

  # Wait a bit for system to stabilize
  sleep 30

  # Run compilation in background
  sh "$SCRIPT_DIR/compile_all.sh" boot >> "$MODULE_DIR/logs/boot_compile.log" 2>&1 &

  log_info "Boot compilation started in background (PID: $!)"
}

# Scheduler daemon
scheduler_daemon() {
  log_info "Starting scheduler daemon"

  # Main loop
  last_run_day=0

  while true; do
    # Check if scheduling is enabled
    schedule_enabled=$(get_config schedule_enabled)

    if [ "$schedule_enabled" = "true" ]; then
      schedule=$(get_config schedule)

      # Check if we should run now
      if should_run_now "$schedule"; then
        current_day=$(date '+%d')

        # Only run once per day (unless different schedule)
        if [ "$current_day" -ne "$last_run_day" ]; then
          log_info "Scheduled compilation triggered"
          sh "$SCRIPT_DIR/compile_all.sh" scheduled
          last_run_day=$current_day
        fi
      fi
    fi

    # Sleep for 1 minute before checking again
    sleep 60
  done
}

# Main execution
log_info "Dex2Oat Manager service starting"

# Rotate logs on startup
rotate_logs

# Wait for system to be fully booted
wait_for_boot_complete

# Check if boot compilation is enabled
compile_on_boot=$(get_config compile_on_boot)

if [ "$compile_on_boot" = "true" ]; then
  log_info "Boot compilation is enabled"

  # Check if we've already compiled on this boot
  BOOT_MARKER="$MODULE_DIR/data/boot_compiled_$(date '+%Y%m%d')"

  if [ ! -f "$BOOT_MARKER" ]; then
    boot_compile
    touch "$BOOT_MARKER"
  else
    log_info "Already compiled on this boot, skipping"
  fi
else
  log_info "Boot compilation is disabled (enable with compile_on_boot=true in config)"
fi

# Check if already running
if [ -f "$PID_FILE" ]; then
  old_pid=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    log_info "Scheduler already running (PID: $old_pid)"
    exit 0
  fi
fi

# Start scheduler daemon in background
scheduler_daemon &
DAEMON_PID=$!

# Save PID
echo "$DAEMON_PID" > "$PID_FILE"

log_info "Dex2Oat Manager service initialized (Scheduler PID: $DAEMON_PID)"

# Detach from parent process
disown "$DAEMON_PID" 2>/dev/null

exit 0
