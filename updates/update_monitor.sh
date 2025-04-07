#!/bin/bash
# update_monitor.sh - Creates backup and updates mpu6050_monitor.py

# Create backup
cp mpu6050_monitor.py mpu6050_monitor.py.bak

# Update version number
sed -i '2s/web_server.py - v1.0.0/mpu6050_monitor.py - v1.0.1/' mpu6050_monitor.py

# Fix web server launch command to run in background
sed -i 's/os.system("python3 web_server.py")/print("Starting web server in background..."); os.system("python3 web_server.py \&")/' mpu6050_monitor.py

# Make script executable
chmod +x mpu6050_monitor.py

echo "mpu6050_monitor.py updated to v1.0.1"
