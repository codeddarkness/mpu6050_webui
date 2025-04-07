#!/bin/bash
# Backup the current script
cp mpu6050_monitor.py mpu6050_monitor.py.bak

# Run the Python indentation fixer
python3 fix_indentation.py

# Check if the fix was successful
if [ $? -eq 0 ]; then
    echo "Indentation fixed successfully. Original script backed up as mpu6050_monitor.py.bak"
else
    echo "Failed to fix indentation. Restoring backup."
    mv mpu6050_monitor.py.bak mpu6050_monitor.py
fi
