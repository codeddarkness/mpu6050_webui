#!/bin/bash
# fix_print_statement.sh - Fix the incomplete print statement in mpu6050_monitor.py

# Backup the current script
cp mpu6050_monitor.py mpu6050_monitor.py.bak

# Use sed to replace the problematic lines
sed -i '/print("/c\        print("\\nExiting...")' mpu6050_monitor.py

# Verify the change
if [ $? -eq 0 ]; then
    echo "Print statement fixed successfully. Original script backed up as mpu6050_monitor.py.bak"
else
    echo "Failed to fix print statement. Restoring backup."
    mv mpu6050_monitor.py.bak mpu6050_monitor.py
fi
