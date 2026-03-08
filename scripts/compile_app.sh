#!/system/bin/sh
# Legacy shim: redirect single-app compile request to unified API.

PACKAGE="$1"
MODE="${2:-speed}"
SOURCE="${3:-manual}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if [ -z "$PACKAGE" ]; then
  echo '{"success":false,"code":"INVALID_ARGS","message":"compile_app.sh requires package","data":{}}'
  exit 1
fi

# Keep compatibility for mode input by updating per-app rule first.
sh "$SCRIPT_DIR/api.sh" upsert_rule --package "$PACKAGE" --mode "$MODE" --enabled true >/dev/null 2>&1 || true

exec sh "$SCRIPT_DIR/api.sh" enqueue --package "$PACKAGE" --source "$SOURCE"
