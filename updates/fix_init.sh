cat << 'EOF' > fix_sensor_init.sh
#!/bin/bash
# Fix the sensor initialization issues

# Backup the file
cp mpu6050_monitor.py mpu6050_monitor.py.backup

# Update the init_sensor function with better error handling
sed -i '/def init_sensor/,/return mpu, config/c\
def init_sensor():\
    config = load_config()\
    try:\
        i2c = busio.I2C(board.SCL, board.SDA)\
        mpu = adafruit_mpu6050.MPU6050(i2c)\
        print("MPU6050 sensor initialized successfully")\
        return mpu, config\
    except Exception as e:\
        print(f"Error initializing sensor: {e}")\
        print("Check I2C connections and make sure MPU6050 is properly connected.")\
        return None, config' mpu6050_monitor.py

# Update the sensor_thread function with better error handling
sed -i '/def sensor_thread/,/        time.sleep(0.1)/c\
def sensor_thread():\
    global sensor_data\
    mpu, config = init_sensor()\
    \
    if mpu is None:\
        print("WARNING: Sensor initialization failed. Using dummy data.")\
        # Return dummy data for testing\
        while True:\
            sensor_data = {\
                "acceleration": {"x": 0, "y": 0, "z": 9.8},\
                "gyro": {"x": 0, "y": 0, "z": 0},\
                "temperature": 25\
            }\
            time.sleep(0.1)\
    \
    while True:\
        try:\
            sensor_data = read_sensor(mpu, config)\
            time.sleep(0.1)  # 10 Hz update rate\
        except Exception as e:\
            print(f"Error reading sensor: {e}")\
            time.sleep(1)  # Retry after a longer delay' mpu6050_monitor.py

echo "Fixed sensor initialization"
EOF

chmod +x fix_sensor_init.sh
./fix_sensor_init.sh
