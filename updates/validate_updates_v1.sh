#!/bin/bash
# validate_v1.0.1.sh - Validates that v1.0.1 patches were applied correctly

echo "Validating v1.0.1 updates..."
echo "--------------------------"

# Check version numbers
echo "Checking version numbers:"
grep "v1.0.1" mpu6050_monitor.py web_server.py templates/index.html
if [ $? -eq 0 ]; then
  echo "✓ Version numbers updated correctly"
else
  echo "✗ Version numbers not updated correctly"
fi

# Check Flask app name change
echo -e "\nChecking Flask app name:"
if grep -q "Flask(\"mpu6050_web_server\")" web_server.py; then
  echo "✓ Flask app name updated correctly"
else
  echo "✗ Flask app name not updated"
fi

# Check background web server launch
echo -e "\nChecking web server background launch:"
if grep -q "python3 web_server.py &" mpu6050_monitor.py; then
  echo "✓ Web server launch in background configured correctly"
else 
  echo "✗ Web server background launch not configured"
fi

# Check HTML template updates
echo -e "\nChecking HTML template updates:"
if grep -q "status-panel" templates/index.html && grep -q "Acceleration (m/s²)" templates/index.html; then
  echo "✓ Status panel added to HTML template"
else
  echo "✗ Status panel not found in HTML template"
fi

if grep -q "Temperature.*°C / .*°F" templates/index.html; then
  echo "✓ Fahrenheit temperature display added"
else
  echo "✗ Fahrenheit temperature display not found"
fi

if grep -q "acc-x-arrow" templates/index.html && grep -q "getArrow" templates/index.html; then
  echo "✓ Arrow indicators added to HTML template"
else
  echo "✗ Arrow indicators not found in HTML template"
fi

# Check for important functions
echo -e "\nChecking for sensor initialization error handling:"
if grep -q "Error initializing sensor" web_server.py; then
  echo "✓ Sensor error handling implemented"
else
  echo "✗ Sensor error handling not found"
fi

echo -e "\nValidation complete!"
