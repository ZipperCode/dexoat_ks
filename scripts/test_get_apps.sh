#!/system/bin/sh
# Test script to verify get_apps.sh output
# Usage: sh scripts/test_get_apps.sh

echo "Testing get_apps.sh..."
echo "========================================="

# Run the script
OUTPUT=$(sh /data/adb/modules/dexoat_ks/scripts/get_apps.sh 2>&1)

# Check exit code
EXIT_CODE=$?

echo "Exit code: $EXIT_CODE"
echo ""

# Show first 500 characters
echo "First 500 characters of output:"
echo "$OUTPUT" | head -c 500
echo ""
echo "========================================="
echo ""

# Validate JSON
echo "Validating JSON..."
echo "$OUTPUT" | head -c 100 | grep -q '{"apps":\['
if [ $? -eq 0 ]; then
  echo "✓ JSON structure looks good"
else
  echo "✗ JSON structure invalid"
fi

echo ""
echo "Full output saved to /tmp/get_apps_test.txt"
echo "$OUTPUT" > /tmp/get_apps_test.txt

# Count apps
APP_COUNT=$(echo "$OUTPUT" | grep -o '"packageName"' | wc -l)
echo "Found $APP_COUNT apps"
