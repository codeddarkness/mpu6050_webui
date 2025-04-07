#!/bin/bash
# fix_background_launch.sh

echo "Fixing web server background launch..."
# Use a different pattern to find and replace the line
sed -i 's/os.system("python3 web_server.py")/print("Starting web server in background..."); os.system("python3 web_server.py \&")/' mpu6050_monitor.py

# Verify the change
if grep -q "web_server.py &" mpu6050_monitor.py; then
  echo "✓ Fixed: Web server will now run in background"
else
  echo "✗ Failed to fix web server background launch"
  echo "Manual fix needed: Change 'os.system(\"python3 web_server.py\")' to 'print(\"Starting web server in background...\"); os.system(\"python3 web_server.py &\")'"
fi
