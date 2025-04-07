#!/bin/bash
# fix_all_issues.sh - Manual fixes for remaining v1.0.1 issues

echo "Applying manual fixes for remaining issues..."

# === 1. Fix web server background launch ===
echo "1. Fixing web server background launch..."
grep -n "os.system(\"python3 web_server.py\")" mpu6050_monitor.py > /dev/null
if [ $? -eq 0 ]; then
  # Create a temporary file
  cat mpu6050_monitor.py > temp_file.py
  # Use awk for more precise replacement
  awk '{gsub(/os\.system\("python3 web_server\.py"\)/, "print(\"Starting web server in background...\"); os.system(\"python3 web_server.py \&\")")}1' temp_file.py > mpu6050_monitor.py
  rm temp_file.py
  echo "  Web server launch fixed"
else
  echo "  Web server launch line not found. Skipping."
fi

# === 2. Fix Fahrenheit temperature display ===
echo "2. Fixing Fahrenheit temperature display..."
# Create a new temporary file with all needed changes
cat > temp_html_fixes.txt << 'EOT'
                    document.getElementById('temp').textContent = data.temperature.toFixed(1);
                    
                    // Calculate Fahrenheit temperature
                    const fahrenheit = (data.temperature * 9/5) + 32;
                    document.getElementById('temp-f').textContent = fahrenheit.toFixed(1);
EOT

# Find the line with temperature display and replace related code
grep -n "document.getElementById('temp').textContent" templates/index.html > /dev/null
if [ $? -eq 0 ]; then
  # Create a temporary file
  cat templates/index.html > temp_file.html
  # Replace the temperature display code
  awk '
  /document\.getElementById\('"'"'temp'"'"'\)\.textContent =/ {
    print "                    document.getElementById('"'"'temp'"'"').textContent = data.temperature.toFixed(1);";
    print "";
    print "                    // Calculate Fahrenheit temperature";
    print "                    const fahrenheit = (data.temperature * 9/5) + 32;";
    print "                    document.getElementById('"'"'temp-f'"'"').textContent = fahrenheit.toFixed(1);";
    next;
  }
  /Temperature.*°C/ {
    gsub(/>([0-9\.]+)<\/span> °C/, ">0.0</span> °C / <span class=\"status-value\" id=\"temp-f\">32.0</span> °F");
  }
  {print}
  ' temp_file.html > templates/index.html
  rm temp_file.html
  echo "  Fahrenheit display fixed"
else
  echo "  Temperature display code not found. Skipping."
fi

# === 3. Fix sensor error handling ===
echo "3. Fixing sensor error handling..."
# Create the improved init_sensor function
cat > temp_init_sensor.py << 'EOT'
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

# Create the improved sensor_thread function
cat > temp_sensor_thread.py << 'EOT'
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

# Create a new web_server.py file with all the changes
cat web_server.py > web_server_new.py
# Find and replace the init_sensor function
line_num=$(grep -n "def init_sensor" web_server_new.py | cut -d: -f1)
if [ ! -z "$line_num" ]; then
  # Extract start line number
  start=$line_num
  # Find end of the function (next function or end of file)
  end=$(tail -n +$start web_server_new.py | grep -n "^def " | head -1 | cut -d: -f1)
  if [ ! -z "$end" ]; then
    end=$((start + end - 1))
    # Delete the old function and insert the new one
    sed -i "${start},${end}d" web_server_new.py
    sed -i "${start}i$(cat temp_init_sensor.py)" web_server_new.py
    echo "  init_sensor function updated"
  else
    echo "  init_sensor function end not found. Skipping."
  fi
else
  echo "  init_sensor function not found. Skipping."
fi

# Now do the same for sensor_thread
line_num=$(grep -n "def sensor_thread" web_server_new.py | cut -d: -f1)
if [ ! -z "$line_num" ]; then
  # Extract start line number
  start=$line_num
  # Find end of the function (next function or end of file)
  end=$(tail -n +$start web_server_new.py | grep -n "^def " | head -1 | cut -d: -f1)
  if [ ! -z "$end" ]; then
    end=$((start + end - 1))
    # Delete the old function and insert the new one
    sed -i "${start},${end}d" web_server_new.py
    sed -i "${start}i$(cat temp_sensor_thread.py)" web_server_new.py
    echo "  sensor_thread function updated"
  else
    echo "  sensor_thread function end not found. Skipping."
  fi
else
  echo "  sensor_thread function not found. Skipping."
fi

# If successful, replace the original file
if [ -f "web_server_new.py" ]; then
  mv web_server_new.py web_server.py
  echo "  web_server.py updated"
fi

# Clean up
rm -f temp_init_sensor.py temp_sensor_thread.py

echo "All fixes applied. Running validation..."
./validate_updates.sh
