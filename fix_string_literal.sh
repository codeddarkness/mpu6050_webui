#!/bin/bash
# Fix specific string literal issue in mpu6050_monitor.py

# Backup the current script
cp mpu6050_monitor.py mpu6050_monitor.py.bak

# Use sed to remove the problematic line and replace with correct print statement
sed -i '/Exiting.../c\        print("Exiting...")' mpu6050_monitor.py

# Verify the change
if [ $? -eq 0 ]; then
    echo "String literal fixed successfully. Original script backed up as mpu6050_monitor.py.bak"
else
    echo "Failed to fix string literal. Restoring backup."
    mv mpu6050_monitor.py.bak mpu6050_monitor.py
fi
