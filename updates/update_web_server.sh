#!/bin/bash
# update_web_server.sh - Creates backup and updates web_server.py

# Create backup
cp web_server.py web_server.py.bak

# Update version number
sed -i '2s/v1.0.0/v1.0.1/' web_server.py

# Update Flask app name to avoid confusion
sed -i 's/app = Flask(__name__)/app = Flask("mpu6050_web_server")/' web_server.py

# Fix the sensor initialization function
cat <<'EOT' > temp_code.py
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

# Find the old function and replace it
START_LINE=$(grep -n "def init_sensor" web_server.py | cut -d: -f1)
END_LINE=$(grep -n "return mpu, config" web_server.py | cut -d: -f1)
if [ ! -z "$START_LINE" ] && [ ! -z "$END_LINE" ]; then
    sed -i "${START_LINE},${END_LINE}d" web_server.py
    sed -i "${START_LINE}i$(cat temp_code.py)" web_server.py
fi
rm temp_code.py

# Update the sensor thread function
cat <<'EOT' > temp_code.py
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

# Find the old function and replace it
START_LINE=$(grep -n "def sensor_thread" web_server.py | cut -d: -f1)
END_LINE=$(grep -n "    while True:" web_server.py | cut -d: -f1)
if [ ! -z "$START_LINE" ] && [ ! -z "$END_LINE" ]; then
    sed -i "${START_LINE},${END_LINE}d" web_server.py
    sed -i "${START_LINE}i$(cat temp_code.py)" web_server.py
fi
rm temp_code.py

echo "web_server.py updated to v1.0.1"
