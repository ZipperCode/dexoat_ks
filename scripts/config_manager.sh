#!/system/bin/sh
# Configuration management utility for Dex2Oat Manager
# Usage: source this script and call get_config, set_config

MODULE_DIR="/data/adb/modules/dexoat_ks"
CONFIG_DIR="$MODULE_DIR/configs"
CONFIG_FILE="$CONFIG_DIR/dexoat.conf"
APP_RULES_FILE="$CONFIG_DIR/app_rules.conf"

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# Read config value
get_config() {
  key=$1
  if [ -f "$CONFIG_FILE" ]; then
    grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-
  fi
}

# Set config value
set_config() {
  key=$1
  value=$2

  # Create config file if it doesn't exist
  if [ ! -f "$CONFIG_FILE" ]; then
    touch "$CONFIG_FILE"
  fi

  # Update or add the key-value pair
  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    # Key exists, replace it
    temp_file="${CONFIG_FILE}.tmp"
    sed "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE" > "$temp_file"
    mv "$temp_file" "$CONFIG_FILE"
  else
    # Key doesn't exist, append it
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

# Validate config value
validate_config_key() {
  key=$1
  value=$2

  case "$key" in
    default_mode)
      if echo "$value" | grep -qE '^(speed|verify|speed-profile)$'; then
        return 0
      fi
      return 1
      ;;
    skip_compiled|detect_mode_reset|schedule_enabled|compile_system_apps|compile_user_apps)
      if echo "$value" | grep -qE '^(true|false)$'; then
        return 0
      fi
      return 1
      ;;
    log_level)
      if echo "$value" | grep -qE '^(DEBUG|INFO|WARN|ERROR)$'; then
        return 0
      fi
      return 1
      ;;
    parallel_jobs|storage_threshold)
      if echo "$value" | grep -qE '^[0-9]+$'; then
        return 0
      fi
      return 1
      ;;
    *)
      return 0  # Unknown keys are valid by default
      ;;
  esac
}

# Get app-specific rule
get_app_rule() {
  package=$1
  field=$2

  if [ -f "$APP_RULES_FILE" ]; then
    # Extract the field for the specific package
    result=$(grep "\"$package\"" "$APP_RULES_FILE" -A 10 | grep "\"$field\"" | cut -d'"' -f4)
    echo "$result"
  fi
}

# Set app-specific rule
set_app_rule() {
  package=$1
  mode=$2
  enabled=$3
  priority=$4

  # Initialize app_rules.conf if it doesn't exist
  if [ ! -f "$APP_RULES_FILE" ]; then
    cat > "$APP_RULES_FILE" << 'EOF'
{
  "rules": {}
}
EOF
  fi

  # Use jq to update the rules (if available), otherwise append manually
  if command -v jq >/dev/null 2>&1; then
    temp_file="${APP_RULES_FILE}.tmp"
    jq --arg pkg "$package" \
       --arg mode "$mode" \
       --argjson enabled "$enabled" \
       --argjson priority "$priority" \
       '.rules[$pkg] = {"mode": $mode, "enabled": $enabled, "priority": $priority}' \
       "$APP_RULES_FILE" > "$temp_file"
    mv "$temp_file" "$APP_RULES_FILE"
  else
    # Fallback: append manually (less safe but works without jq)
    log_warn "jq not available, manual rule update not implemented"
  fi
}
