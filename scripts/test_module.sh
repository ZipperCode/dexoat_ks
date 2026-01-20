#!/system/bin/sh
# Test script to verify module functionality

echo "=== Dex2Oat Manager Test Script ==="
echo ""

MODULE_DIR="/data/adb/modules/dexoat_ks"

echo "1. Checking module installation..."
if [ -d "$MODULE_DIR" ]; then
  echo "   ✓ Module directory exists"
  ls -la "$MODULE_DIR"
else
  echo "   ✗ Module directory NOT found"
  exit 1
fi

echo ""
echo "2. Checking scripts..."
for script in compile_app.sh get_apps.sh compile_all.sh logger.sh config_manager.sh; do
  if [ -f "$MODULE_DIR/scripts/$script" ]; then
    echo "   ✓ $script exists"
  else
    echo "   ✗ $script NOT found"
  fi
done

echo ""
echo "3. Checking configuration..."
if [ -f "$MODULE_DIR/configs/dexoat.conf" ]; then
  echo "   ✓ Config file exists"
  cat "$MODULE_DIR/configs/dexoat.conf"
else
  echo "   ✗ Config file NOT found"
fi

echo ""
echo "4. Testing get_apps.sh..."
echo "   Running: sh $MODULE_DIR/scripts/get_apps.sh"
echo ""
sh "$MODULE_DIR/scripts/get_apps.sh" | head -c 500
echo ""
echo "..."
echo ""

echo "5. Checking logs directory..."
if [ -d "$MODULE_DIR/logs" ]; then
  echo "   ✓ Logs directory exists"
  ls -la "$MODULE_DIR/logs"
else
  echo "   ✗ Logs directory NOT found"
fi

echo ""
echo "6. Testing logger.sh..."
if [ -f "$MODULE_DIR/scripts/logger.sh" ]; then
  . "$MODULE_DIR/scripts/logger.sh"
  log_info "Test log entry"
  echo "   ✓ Logger working"
fi

echo ""
echo "7. Checking WebUI..."
if [ -f "$MODULE_DIR/webroot/index.html" ]; then
  echo "   ✓ WebUI index.html exists"
else
  echo "   ✗ WebUI index.html NOT found"
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "If all tests passed, the module is properly installed."
echo "Check the logs above for any errors."
