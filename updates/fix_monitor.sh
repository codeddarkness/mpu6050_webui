cat << 'EOF' > check_sensor.sh
#!/bin/bash
# Check and fix sensor initialization issues

echo "Checking sensor initialization in mpu6050_monitor.py..."

# 1. Check if sensor thread is being created
grep -n "thread = threading.Thread" mpu6050_monitor.py
# 2. Check sensor initialization function
grep -n "def init_sensor" mpu6050_monitor.py
# 3. Check sensor data handling
grep -n "data = read_sensor" mpu6050_monitor.py
# 4. Check error handling
grep -n "except Exception" mpu6050_monitor.py

echo "----------"
echo "Checking Flask routes..."
# 5. Check data endpoint
grep -n "@app.route('/data')" mpu6050_monitor.py
grep -n "def get_data" mpu6050_monitor.py
EOF

chmod +x check_sensor.sh
./check_sensor.sh
