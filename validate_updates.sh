#!/bin/bash
# validate_v1.0.3.sh - Validation script for MPU6050 Monitor v1.0.3

echo "Validating MPU6050 Monitor v1.0.3..."
echo "=================================="

# Check required files exist
echo -n "Checking core files: "
CORE_FILES=("mpu6050_monitor.py" "restart.sh" "templates/index.html" "config.json")
MISSING=0
for file in "${CORE_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo -e "\n ✗ Missing file: $file"
    MISSING=1
  fi
done
if [ $MISSING -eq 0 ]; then
  echo "✓ All core files present"
fi

# Check script permissions
echo -n "Checking script permissions: "
if [ -x "mpu6050_monitor.py" ] && [ -x "restart.sh" ]; then
  echo "✓ Script permissions OK"
else
  echo "✗ Script permissions incorrect"
  echo "  Run: chmod +x mpu6050_monitor.py restart.sh"
fi

# Fixed version of the version check
echo -n "Checking version numbers: "
VERSION_PY=$(grep -c "v1.0.3" mpu6050_monitor.py)
VERSION_HTML=$(grep -c "v1.0.3" templates/index.html)
if [ $VERSION_PY -ge 1 ] && [ $VERSION_HTML -ge 1 ]; then
  echo "✓ Version numbers OK"
else
  echo "✗ Version number mismatch (Python: $VERSION_PY, HTML: $VERSION_HTML)"
fi

########################################
# Check version numbers
#echo -n "Checking version numbers: "
#VERSION_CHECK=$(grep -c "v1.0.3" mpu6050_monitor.py templates/index.html)
#if [ $VERSION_CHECK -eq 2 ]; then
#  echo "✓ Version numbers OK"
#else
#  echo "✗ Version number mismatch"
#fi
########################################

# Check API endpoints
echo -n "Checking API endpoints: "
API_COUNT=$(grep -c "/api/v1/" mpu6050_monitor.py)
if [ $API_COUNT -ge 4 ]; then
  echo "✓ API endpoints present"
else
  echo "✗ API endpoints missing"
fi

# Check console mode
echo -n "Checking console mode: "
if grep -q "def run_console_mode" mpu6050_monitor.py && grep -q "time.sleep(0.2)" mpu6050_monitor.py; then
  echo "✓ Console mode OK"
else
  echo "✗ Console mode issues detected"
fi

# Check JSON data saving
echo -n "Checking JSON data saving: "
if grep -q "json.dump(existing_data, f, indent=2)" mpu6050_monitor.py; then
  echo "✓ JSON formatting OK"
else
  echo "✗ JSON formatting issues"
fi

# Test if the script can run
echo -n "Testing script execution: "
if python3 -c "import sys; sys.path.append('.'); import mpu6050_monitor" 2>/dev/null; then
  echo "✓ Script syntax OK"
else
  echo "✗ Script has syntax errors"
fi

# Final assessment
echo "=================================="
echo "Validation complete."
echo "If all checks passed, the system is ready to run."
echo "Start the application with: ./restart.sh"
