#!/system/bin/sh
# Legacy shim: redirect batch compile request to unified API.

TRIGGER="${1:-manual}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

exec sh "$SCRIPT_DIR/api.sh" enqueue --package "__ALL__" --source "$TRIGGER"
