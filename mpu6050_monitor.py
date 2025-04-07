#!/usr/bin/env python3
# mpu6050_monitor.py - v1.0.2
# Console monitor for MPU6050 sensor with web interface

import time
import json
import os
import math
import argparse
import logging
import signal
import sys
import threading
import subprocess
from datetime import datetime
import board
import busio
import adafruit_mpu6050
from flask import Flask, render_template, jsonify, send_file, Response

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("web_server.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("mpu6050_monitor")

# Create Flask app for web server
app = Flask("mpu6050_web_server")
# Redirect Flask logging to file
app.logger.handlers = []
handler = logging.FileHandler('web_server.log')
handler.setLevel(logging.INFO)
app.logger.addHandler(handler)
app.logger.setLevel(logging.INFO)

# Global sensor data (updated by background thread)
sensor_data = {
    "acceleration": {"x": 0, "y": 0, "z": 0},
    "gyro": {"x": 0, "y": 0, "z": 0},
    "temperature": 0
}

# Global flag to control the main loop
running = True

# Configuration
CONFIG = {
    "data_file": "sensor_data.json",
    "sample_rate": 0.1,  # seconds
    "calibration": {
        "x_offset": 0,
        "y_offset": 0,
        "z_offset": 0,
        "calibrated": False
    }
}

def load_config():
    """Load config from file if exists"""
    if os.path.exists("config.json"):
        with open("config.json", "r") as f:
            return json.load(f)
    return CONFIG

def save_config(config):
    """Save config to file"""
    with open("config.json", "w") as f:
        json.dump(config, f, indent=4)

def init_sensor():
    """Initialize the MPU6050 sensor"""
    config = load_config()
    try:
        i2c = busio.I2C(board.SCL, board.SDA)
        mpu = adafruit_mpu6050.MPU6050(i2c)
        logger.info("MPU6050 sensor initialized successfully")
        return mpu, config
    except Exception as e:
        logger.error(f"Error initializing sensor: {e}")
        logger.error("Check I2C connections and make sure MPU6050 is properly connected.")
        return None, config

def read_sensor(mpu, config):
    """Read sensor data with calibration applied"""
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

def save_data(data, config):
    """Save data to JSON file"""
    # Load existing data if file exists
    if os.path.exists(config["data_file"]):
        try:
            with open(config["data_file"], "r") as f:
                existing_data = json.load(f)
        except json.JSONDecodeError:
            existing_data = {"readings": []}
    else:
        existing_data = {"readings": []}
    
    # Add new data and save
    existing_data["readings"].append(data)
    with open(config["data_file"], "w") as f:
        json.dump(existing_data, f)

def get_direction_arrow(ax, ay):
    """Return ASCII arrow indicating direction based on acceleration"""
    if abs(ax) < 0.3 and abs(ay) < 0.3:
        return "•"  # Neutral
    
    # Determine primary direction
    if abs(ax) > abs(ay):
        return "→" if ax > 0 else "←"
    else:
        return "↑" if ay > 0 else "↓"

def get_horizontal_arrow(value, threshold=0.3):
    """Get horizontal arrow for value"""
    if value > threshold:
        return "→"
    elif value < -threshold:
        return "←"
    return " "

def get_vertical_arrow(value, threshold=0.3):
    """Get vertical arrow for value"""
    if value > threshold:
        return "↑"
    elif value < -threshold:
        return "↓"
    return " "

def calibrate_sensor(mpu):
    """Calibrate by taking 100 readings and finding average offset"""
    print("Calibrating sensor. Please keep the sensor still and level...")
    x_vals, y_vals, z_vals = [], [], []
    
    # Collect samples
    for i in range(100):
        ax, ay, az = mpu.acceleration
        x_vals.append(ax)
        y_vals.append(ay)
        z_vals.append(az - 9.8)  # Subtract gravity from z axis
        time.sleep(0.01)
        print(f"Calibrating: {i+1}/100", end="\r")
    
    # Calculate offsets (ideal: x=0, y=0, z=0 after gravity compensation)
    config = load_config()
    config["calibration"]["x_offset"] = -sum(x_vals) / len(x_vals)
    config["calibration"]["y_offset"] = -sum(y_vals) / len(y_vals)
    config["calibration"]["z_offset"] = -sum(z_vals) / len(z_vals)
    config["calibration"]["calibrated"] = True
    
    save_config(config)
    print("\nCalibration complete!")
    return config

def sensor_thread():
    """Background thread to continuously read sensor data"""
    global sensor_data, running
    mpu, config = init_sensor()
    
    if mpu is None:
        logger.warning("Sensor initialization failed. Using dummy data.")
        # Return dummy data for testing
        while running:
            sensor_data = {
                "acceleration": {"x": 0, "y": 0, "z": 9.8},
                "gyro": {"x": 0, "y": 0, "z": 0},
                "temperature": 25
            }
            time.sleep(0.1)
        return
    
    # Buffer for data logging
    data_buffer = []
    
    while running:
        try:
            # Read sensor data
            data = read_sensor(mpu, config)
            sensor_data = data
            
            # Add to buffer
            data_with_timestamp = data.copy()
            data_with_timestamp["timestamp"] = datetime.now().isoformat()
            data_buffer.append(data_with_timestamp)
            
            # Save to file periodically (every 10 readings)
            if len(data_buffer) >= 10:
                for item in data_buffer:
                    save_data(item, config)
                data_buffer = []
                
            time.sleep(config["sample_rate"])
                
        except Exception as e:
            logger.error(f"Error reading sensor: {e}")
            time.sleep(1)  # Retry after a longer delay

def run_console_mode(mpu, config):
    """Run in console mode showing sensor data"""
    global running
    
    try:
        while running:
            # Get sensor data
            data = sensor_data
            
            # Get direction arrows
            ax = data["acceleration"]["x"]
            ay = data["acceleration"]["y"]
            az = data["acceleration"]["z"]
            
            gx = data["gyro"]["x"]
            gy = data["gyro"]["y"]
            gz = data["gyro"]["z"]
            
            temp = data["temperature"]
            temp_f = (temp * 9/5) + 32
            
            # Direction arrows
            acc_x_arrow = get_horizontal_arrow(ax)
            acc_y_arrow = get_vertical_arrow(ay)
            acc_z_arrow = get_horizontal_arrow(az)
            
            gyro_x_arrow = get_vertical_arrow(gx)
            gyro_y_arrow = get_vertical_arrow(gy)
            gyro_z_arrow = get_horizontal_arrow(gz)
            
            overall_direction = get_direction_arrow(ax, ay)
            
            # Clear screen
            os.system('clear')
            
            # Display header
            print("╔════════════════════════════════════════════════════════════╗")
            print("║               MPU6050 MONITOR v1.0.2                       ║")
            print("╠════════════════════════════════════════════════════════════╣")
            
            # One line status display as requested
            print(f"║ Accel(m/s²) X: {ax:6.2f}{acc_x_arrow} Y: {ay:6.2f}{acc_y_arrow} Z: {az:6.2f}{acc_z_arrow} | ", end='')
            print(f"Gyro(rad/s) X: {gx:6.2f}{gyro_x_arrow} Y: {gy:6.2f}{gyro_y_arrow} Z: {gz:6.2f}{gyro_z_arrow} | ", end='')
            print(f"Temp: {temp:5.1f}°C / {temp_f:5.1f}°F ║")
            
            # Additional info
            print("╠════════════════════════════════════════════════════════════╣")
            print(f"║ Direction: {overall_direction}                                               ║")
            print(f"║ Web Interface: http://localhost:5000                       ║")
            print("╠════════════════════════════════════════════════════════════╣")
            print("║ [c] Calibrate  [q] Quit                                    ║")
            print("╚════════════════════════════════════════════════════════════╝")
            
            # Wait for keypress with timeout
            import select
            import sys
            
            # Check for keypresses (non-blocking)
            if select.select([sys.stdin], [], [], 0) == ([sys.stdin], [], []):
                key = sys.stdin.read(1)
                if key.lower() == 'q':
                    running = False
                    break
                elif key.lower() == 'c':
                    calibrate_sensor(mpu)
            
            time.sleep(config["sample_rate"])
            
    except KeyboardInterrupt:
        running = False
        print("\nExiting...")

def signal_handler(sig, frame):
    """Handle Ctrl+C"""
    global running
    running = False
    print("\nShutting down...")
    sys.exit(0)

# Flask routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/data')
def get_data():
    return jsonify(sensor_data)

@app.route('/logdata')
def get_log_data():
    config = load_config()
    try:
        with open(config["data_file"], "r") as f:
            return jsonify(json.load(f))
    except (FileNotFoundError, json.JSONDecodeError):
        return jsonify({"readings": []})

@app.route('/download')
def download_data():
    config = load_config()
    return send_file(config["data_file"], as_attachment=True)

def start_web_server():
    """Start the Flask web server"""
    # Redirect Flask logs to file
    import logging
    from logging.handlers import RotatingFileHandler
    
    log_handler = RotatingFileHandler('web_server.log', maxBytes=10000, backupCount=1)
    log_handler.setLevel(logging.INFO)
    log_handler.setFormatter(logging.Formatter(
        '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
    ))
    app.logger.addHandler(log_handler)
    app.logger.setLevel(logging.INFO)
    
    # Start the server
    logger.info("Starting web server at http://0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)

def main():
    """Main function"""
    global running
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='MPU6050 Monitor')
    parser.add_argument('--web-only', action='store_true', help='Run in web mode only (no console)')
    parser.add_argument('--console-only', action='store_true', help='Run in console mode only (no web server)')
    args = parser.parse_args()
    
    # Set up signal handler for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    
    # Initialize sensor
    mpu, config = init_sensor()
    
    # Start sensor reading thread
    sensor_daemon = threading.Thread(target=sensor_thread, daemon=True)
    sensor_daemon.start()
    
    # Start based on mode
    if args.web_only:
        # Web server only
        start_web_server()
    elif args.console_only:
        # Console only
        run_console_mode(mpu, config)
    else:
        # Both console and web server
        web_thread = threading.Thread(target=start_web_server, daemon=True)
        web_thread.start()
        
        # Run console in main thread
        run_console_mode(mpu, config)
    
    # Cleanup
    running = False
    print("Exiting MPU6050 Monitor...")

if __name__ == "__main__":
    main()
