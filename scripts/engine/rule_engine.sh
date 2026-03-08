#!/system/bin/sh
# Deterministic rule decision with strict precedence.
# Usage:
#   rule_decide <global_enabled> <app_type> <scope_enabled> <excluded> <forced_mode> <default_mode>
# Returns:
#   SKIP_GLOBAL_DISABLED | SKIP_EXCLUDED | SKIP_SCOPE_DISABLED | EXECUTE:<mode>

rule_decide() {
  global_enabled="$1"
  app_type="$2"
  scope_enabled="$3"
  excluded="$4"
  forced_mode="$5"
  default_mode="$6"

  if [ "$global_enabled" != "true" ]; then
    echo "SKIP_GLOBAL_DISABLED"
    return 0
  fi

  if [ "$excluded" = "true" ]; then
    echo "SKIP_EXCLUDED"
    return 0
  fi

  if [ "$scope_enabled" != "true" ]; then
    echo "SKIP_SCOPE_DISABLED"
    return 0
  fi

  if [ -n "$forced_mode" ]; then
    echo "EXECUTE:$forced_mode"
    return 0
  fi

  echo "EXECUTE:$default_mode"
  return 0
}
