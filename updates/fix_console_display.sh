#!/bin/bash
# Fix console display width issues

# Find the line with the single-line status display
grep -n "print(f\"║ Accel" mpu6050_monitor.py > /dev/null
if [ $? -eq 0 ]; then
    # Reduce width by adjusting the box
    sed -i 's/╔════════════════════════════════════════════════════════════╗/╔══════════════════════════════════════════════════════╗/g' mpu6050_monitor.py
    sed -i 's/║               MPU6050 MONITOR v1.0.2                       ║/║               MPU6050 MONITOR v1.0.2                 ║/g' mpu6050_monitor.py
    sed -i 's/╠════════════════════════════════════════════════════════════╣/╠══════════════════════════════════════════════════════╣/g' mpu6050_monitor.py
    sed -i 's/║ Direction: .*/║ Direction: .*                                   ║/║ Direction: .*                             ║/g' mpu6050_monitor.py
    sed -i 's/║ Web Interface: http:\/\/localhost:5000                       ║/║ Web Interface: http:\/\/localhost:5000             ║/g' mpu6050_monitor.py
    sed -i 's/║ \[c\] Calibrate  \[q\] Quit                                    ║/║ \[c\] Calibrate  \[q\] Quit              ║/g' mpu6050_monitor.py
    sed -i 's/╚════════════════════════════════════════════════════════════╝/╚══════════════════════════════════════════════════════╝/g' mpu6050_monitor.py
fi

echo "Fixed console display width"
