#!/bin/bash
# add_api_v1.0.3.sh - Add API interface

echo "Adding API interface..."

# Create API routes to add to mpu6050_monitor.py
cat > api_routes.py << 'EOT'
# API Routes
@app.route('/api/v1/data')
def api_get_data():
    """API endpoint to get current sensor data"""
    return jsonify({
        "version": "1.0.3",
        "timestamp": datetime.now().isoformat(),
        "data": sensor_data
    })

@app.route('/api/v1/status')
def api_get_status():
    """API endpoint to get system status"""
    config = load_config()
    return jsonify({
        "version": "1.0.3",
        "uptime": time.time() - start_time,
        "calibrated": config["calibration"]["calibrated"],
        "sample_rate": config["sample_rate"],
        "data_file": config["data_file"]
    })

@app.route('/api/v1/log')
def api_get_log():
    """API endpoint to get logged data"""
    config = load_config()
    try:
        with open(config["data_file"], "r") as f:
            content = f.read().strip()
            if content:
                return jsonify(json.loads(content))
            else:
                return jsonify({"readings": []})
    except (FileNotFoundError, json.JSONDecodeError):
        return jsonify({"readings": []})

@app.route('/api/v1/calibrate', methods=['POST'])
def api_calibrate():
    """API endpoint to trigger calibration"""
    global sensor_data
    
    # We can't directly calibrate the sensor here as it requires console input
    # So just return the current calibration values
    config = load_config()
    
    return jsonify({
        "status": "success",
        "message": "Current calibration values returned. Use console mode for full calibration.",
        "calibration": config["calibration"]
    })
EOT

# Add global start_time variable at the top of the file
sed -i '/^# Global flag to control the main loop/i # Global start time for uptime tracking\nstart_time = time.time()\n' mpu6050_monitor.py

# Add API routes before the main function
sed -i '/^def main/i'"$(cat api_routes.py)" mpu6050_monitor.py

# Fix web server logging to not flood console
cat > logging_fix.py << 'EOT'
    # Configure logging to file only for werkzeug
    log = logging.getLogger('werkzeug')
    log.setLevel(logging.ERROR)  # Only log errors
    file_handler = logging.FileHandler('web_server.log')
    file_handler.setLevel(logging.ERROR)
    log.addHandler(file_handler)
    log.disabled = True  # Disable console output
    
    # Start the server
    logger.info("Starting web server at http://0.0.0.0:5000")
EOT

# Replace the appropriate section in start_web_server function
sed -i '/    # Redirect Flask logs to file/,/    app.logger.setLevel(logging.INFO)/c\'"$(cat logging_fix.py)" mpu6050_monitor.py

rm api_routes.py logging_fix.py
echo "Added API interface"
