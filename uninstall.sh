#!/system/bin/sh
# Cleanup script for Dex2Oat Manager module uninstall

MODULE_DIR="/data/adb/modules/dexoat_ks"

echo "Dex2Oat Manager - Uninstall Script"
echo "=================================="
echo ""

# Kill any running daemon processes
echo "Stopping any running daemon processes..."
pkill -f dexoat_ks 2>/dev/null
pkill -f compile_all.sh 2>/dev/null

# Remove log files
echo "Removing log files..."
if [ -d "$MODULE_DIR/logs" ]; then
  rm -rf "$MODULE_DIR/logs"
  echo "  ✓ Logs removed"
fi

# Remove configuration files
echo "Removing configuration files..."
if [ -d "$MODULE_DIR/configs" ]; then
  rm -rf "$MODULE_DIR/configs"
  echo "  ✓ Configs removed"
fi

# Remove data directory
echo "Removing data files..."
if [ -d "$MODULE_DIR/data" ]; then
  rm -rf "$MODULE_DIR/data"
  echo "  ✓ Data removed"
fi

echo ""
echo "Dex2Oat Manager uninstalled successfully"
echo ""
echo "Note: Any compiled apps will remain compiled."
echo "To remove all compilations, run un_compile_all.sh before uninstalling."
