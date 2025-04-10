#!/usr/bin/env python3
# mpu6050_monitor.py - v1.0.3
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

# Global start time for uptime tracking
start_time = time.time()

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
                content = f.read().strip()
                if content:
                    existing_data = json.loads(content)
                else:
                    existing_data = {"readings": []}
        except (json.JSONDecodeError, FileNotFoundError):
            existing_data = {"readings": []}
    else:
        existing_data = {"readings": []}
    
    # Add new data and save
    if "readings" not in existing_data:
        existing_data["readings"] = []
    
    existing_data["readings"].append(data)
    
    # Save with proper formatting
    with open(config["data_file"], "w") as f:
        json.dump(existing_data, f, indent=2)

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

#######################################
