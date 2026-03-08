#!/system/bin/sh
# Migrate legacy key=value config into new API config store.

MODULE_DIR="${DEXOAT_MODULE_DIR:-/data/adb/modules/dexoat_ks}"
SCRIPT_DIR="$MODULE_DIR/scripts"
LEGACY_CONF="$MODULE_DIR/configs/dexoat.conf"

if [ ! -f "$LEGACY_CONF" ]; then
  echo '{"success":false,"code":"NO_LEGACY_CONFIG","message":"legacy config not found","data":{}}'
  exit 1
fi

migrated=0
while IFS='=' read -r key value; do
  case "$key" in
    ''|\#*)
      continue
      ;;
  esac

  sh "$SCRIPT_DIR/api.sh" set_config --key "$key" --value "$value" >/dev/null 2>&1 || true
  migrated=$((migrated + 1))
done < "$LEGACY_CONF"

printf '{"success":true,"code":"OK","message":"legacy config migrated","data":{"count":%s}}\n' "$migrated"
