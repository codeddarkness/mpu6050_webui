#!/bin/bash
# fix_sensor_error.sh

echo "Fixing sensor error handling..."

# Create new init_sensor function with error handling
cat << 'EOT' > temp_init_sensor.txt
# Initialize sensor
def init_sensor():
    config = load_config()
    try:
        i2c = busio.I2C(board.SCL, board.SDA)
        mpu = adafruit_mpu6050.MPU6050(i2c)
        return mpu, config
    except Exception as e:
        print(f"Error initializing sensor: {e}")
        print("Check I2C connections and make sure MPU6050 is properly connected.")
        return None, config
EOT

# Create new sensor_thread function with error handling
cat << 'EOT' > temp_sensor_thread.txt
# Background thread to continuously read sensor
def sensor_thread():
    global sensor_data
    mpu, config = init_sensor()
    
    if mpu is None:
        print("WARNING: Sensor initialization failed. Using dummy data.")
        # Just return dummy data for testing
        while True:
            sensor_data = {
                "acceleration": {"x": 0, "y": 0, "z": 9.8},
                "gyro": {"x": 0, "y": 0, "z": 0},
                "temperature": 25
            }
            time.sleep(0.1)
    
    while True:
        try:
            sensor_data = read_sensor(mpu, config)
            time.sleep(0.1)  # 10 Hz update rate
        except Exception as e:
            print(f"Error reading sensor: {e}")
            time.sleep(1)  # Retry after a longer delay
EOT

# Replace the functions in web_server.py
INIT_START=$(grep -n "def init_sensor" web_server.py | cut -d: -f1)
if [ ! -z "$INIT_START" ]; then
  # Find the end of the init_sensor function
  INIT_END=$(tail -n +$INIT_START web_server.py | grep -n "^def " | head -1 | cut -d: -f1)
  if [ ! -z "$INIT_END" ]; then
    INIT_END=$((INIT_START + INIT_END - 1))
    # Delete the old function and insert the new one
    sed -i "${INIT_START},${INIT_END}d" web_server.py
    sed -i "${INIT_START}i$(cat temp_init_sensor.txt)" web_server.py
    echo "✓ Fixed: Added sensor initialization error handling"
  else
    echo "✗ Failed to find end of init_sensor function"
  fi
else
  echo "✗ Failed to find init_sensor function"
fi

# Now do the same for sensor_thread
THREAD_START=$(grep -n "def sensor_thread" web_server.py | cut -d: -f1)
if [ ! -z "$THREAD_START" ]; then
  # Find the end of the sensor_thread function
  THREAD_END=$(tail -n +$THREAD_START web_server.py | grep -n "^def " | head -1 | cut -d: -f1)
  if [ ! -z "$THREAD_END" ]; then
    THREAD_END=$((THREAD_START + THREAD_END - 1))
    # Delete the old function and insert the new one
    sed -i "${THREAD_START},${THREAD_END}d" web_server.py
    sed -i "${THREAD_START}i$(cat temp_sensor_thread.txt)" web_server.py
    echo "✓ Fixed: Added sensor thread error handling"
  else
    echo "✗ Failed to find end of sensor_thread function"
  fi
else
  echo "✗ Failed to find sensor_thread function"
fi

# Clean up
rm temp_init_sensor.txt temp_sensor_thread.txt
