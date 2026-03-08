#!/system/bin/sh
# Legacy shim: queue-centric view via unified API.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

exec sh "$SCRIPT_DIR/api.sh" queue_status
