#!/bin/bash
# Restart the MPU6050 Monitor application

# Kill any existing instances
pkill -f "python3 mpu6050_monitor.py" || true
echo "Killed existing processes"

# Wait a moment
sleep 1

# Start the application
echo "Starting MPU6050 Monitor..."
python3 mpu6050_monitor.py

echo "Application restarted!"
