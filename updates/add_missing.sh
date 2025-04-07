cat << 'EOF' > add_sensor_functions.sh
#!/bin/bash
# Add missing sensor functions to web_server.py

# Find where to insert init_sensor function
app_line=$(grep -n "app = Flask" web_server.py | cut -d: -f1)
if [ ! -z "$app_line" ]; then
  insert_line=$((app_line + 2))
  
  # Create functions to insert
  cat > temp_functions.txt << 'EOT'

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

# Read sensor with calibration
def read_sensor(mpu, config):
    ax, ay, az = mpu.acceleration
    gx, gy, gz = mpu.gyro
    temp = mpu.temperature
    
    # Apply calibration if available
    if config["calibration"]["calibrated"]:
        ax += config["calibration"]["x_offset"]
        ay += config["calibration"]["y_offset"]
        az += config["calibration"]["z_offset"]
    
    return {
        "acceleration": {"x": ax, "y": ay, "z": az},
        "gyro": {"x": gx, "y": gy, "z": gz},
        "temperature": temp
    }

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

  # Insert functions at the specified line
  sed -i "${insert_line}r temp_functions.txt" web_server.py
  rm temp_functions.txt
  echo "Added sensor functions to web_server.py"
else
  echo "Could not find app = Flask line"
fi
EOF

chmod +x add_sensor_functions.sh
./add_sensor_functions.sh
