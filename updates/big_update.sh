#!/bin/bash
# update_v1.0.3.sh - Complete update to v1.0.3

echo "Updating to MPU6050 Monitor v1.0.3..."

# Backup the original files
echo "Creating backups..."
mkdir -p backups/v1.0.3
cp mpu6050_monitor.py backups/v1.0.3/
cp -r templates backups/v1.0.3/

# 1. Create updated mpu6050_monitor.py
echo "Creating updated main script..."
cat > mpu6050_monitor.py << 'EOF'
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

def run_console_mode(mpu, config):
    """Run in console mode showing sensor data"""
    global running
    
    # Prepare for non-blocking key input
    import tty
    import termios
    import select
    import sys
    
    # Save terminal settings
    old_settings = termios.tcgetattr(sys.stdin)
    try:
        # Set terminal to raw mode
        tty.setraw(sys.stdin.fileno())
        
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
            print("╔══════════════════════════════════════════════════════╗")
            print("║               MPU6050 MONITOR v1.0.3                 ║")
            print("╠══════════════════════════════════════════════════════╣")
            
            # One line status display
            print(f"║ Acc(m/s²) X:{ax:7.2f}{acc_x_arrow} Y:{ay:7.2f}{acc_y_arrow} Z:{az:7.2f}{acc_z_arrow} | ", end='')
            print(f"Gyro X:{gx:6.2f}{gyro_x_arrow} Y:{gy:6.2f}{gyro_y_arrow} Z:{gz:6.2f}{gyro_z_arrow} | ", end='')
            print(f"T:{temp:5.1f}°C/{temp_f:5.1f}°F ║")
            
            # Additional info
            print("╠══════════════════════════════════════════════════════╣")
            print(f"║ Direction: {overall_direction}                             ║")
            print(f"║ Web Interface: http://localhost:5000             ║")
            print(f"║ API: http://localhost:5000/api/v1/data           ║")
            print("╠══════════════════════════════════════════════════════╣")
            print("║ [c] Calibrate  [q] Quit              ║")
            print("╚══════════════════════════════════════════════════════╝")
            
            # Check for keypresses with timeout
            if select.select([sys.stdin], [], [], 0.1)[0]:  # 100ms timeout
                key = sys.stdin.read(1)
                if key.lower() == 'q':
                    running = False
                    break
                elif key.lower() == 'c':
                    # Reset terminal settings before calibrating
                    termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
                    calibrate_sensor(mpu)
                    # Set terminal back to raw mode
                    tty.setraw(sys.stdin.fileno())
            
            time.sleep(0.2)  # Slower refresh rate to reduce flicker
            
    finally:
        # Restore terminal settings
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
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

def start_web_server():
    """Start the Flask web server"""
    # Configure logging to file only for werkzeug
    log = logging.getLogger('werkzeug')
    log.setLevel(logging.ERROR)  # Only log errors
    file_handler = logging.FileHandler('web_server.log')
    file_handler.setLevel(logging.ERROR)
    log.addHandler(file_handler)
    log.disabled = True  # Disable console output
    
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
EOF

# 2. Create updated template file
echo "Updating web interface..."
cat > templates/index.html << 'EOF'
<!-- templates/index.html - v1.0.3 -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MPU6050 Monitor</title>
    <script src="https://cdn.jsdelivr.net/npm/three@0.132.2/build/three.min.js"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f0f0f0;
        }
        .container {
            display: flex;
            flex-direction: column;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .main-panel {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            margin: 10px;
            padding: 15px;
            width: calc(100% - 50px);
        }
        .visualization-container {
            width: 100%;
            height: 400px;
            position: relative;
        }
        #visualization {
            width: 100%;
            height: 100%;
        }
        .status-panel {
            width: 100%;
            padding: 10px;
            margin-top: 10px;
            background-color: #333;
            color: white;
            border-radius: 5px;
            font-family: monospace;
            font-size: 14px;
            overflow-x: auto;
            white-space: nowrap;
            box-sizing: border-box;
        }
        .status-value {
            display: inline-block;
            min-width: 50px;
            text-align: right;
        }
        .status-label {
            font-weight: bold;
            color: #aaa;
        }
        .status-section {
            margin: 0 15px;
            display: inline-block;
        }
        .status-section:first-child {
            margin-left: 0;
        }
        .arrow {
            font-weight: bold;
            color: #4CAF50;
        }
        h1, h2 {
            margin-top: 0;
            color: #333;
        }
        h1 {
            font-size: 1.5em;
        }
        h2 {
            font-size: 1.2em;
            margin-top: 20px;
        }
        .button {
            background-color: #4CAF50;
            border: none;
            color: white;
            padding: 8px 16px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 14px;
            margin: 8px 4px;
            cursor: pointer;
            border-radius: 4px;
        }
        .button:hover {
            background-color: #45a049;
        }
        .actions {
            text-align: center;
            margin-top: 10px;
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            margin: 10px;
            padding: 15px;
        }
        .debug-info {
            margin-top: 10px;
            padding: 10px;
            background-color: #f8f8f8;
            border-radius: 5px;
            font-family: monospace;
            font-size: 12px;
            display: none;
        }
        code {
            font-family: monospace;
            background-color: #f5f5f5;
            padding: 2px 5px;
            border-radius: 3px;
            font-size: 0.9em;
        }
        .api-section {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            margin: 10px;
            padding: 15px;
            width: calc(100% - 50px);
            display: none;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        th, td {
            padding: 8px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f2f2f2;
        }
        pre {
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="main-panel">
            <h1>MPU6050 3D Orientation</h1>
            <div class="visualization-container">
                <div id="visualization"></div>
            </div>
            
            <div class="status-panel" id="status-bar">
                <span class="status-section">
                    <span class="status-label">Acceleration (m/s²)</span>
                    X: <span class="status-value" id="acc-x">0.00</span> <span class="arrow" id="acc-x-arrow">&lt;</span>
                    Y: <span class="status-value" id="acc-y">0.00</span> <span class="arrow" id="acc-y-arrow">^</span>
                    Z: <span class="status-value" id="acc-z">0.00</span> <span class="arrow" id="acc-z-arrow">&gt;</span>
                </span>
                <span class="status-section">|</span>
                <span class="status-section">
                    <span class="status-label">Gyroscope (rad/s)</span>
                    X: <span class="status-value" id="gyro-x">0.00</span> <span class="arrow" id="gyro-x-arrow">v</span>
                    Y: <span class="status-value" id="gyro-y">0.00</span> <span class="arrow" id="gyro-y-arrow">^</span>
                    Z: <span class="status-value" id="gyro-z">0.00</span> <span class="arrow" id="gyro-z-arrow">&gt;</span>
                </span>
                <span class="status-section">|</span>
                <span class="status-section">
                    <span class="status-label">Temperature</span>
                    <span class="status-value" id="temp">0.0</span> °C / <span class="status-value" id="temp-f">32.0</span> °F
                </span>
            </div>
            
            <div class="debug-info" id="debug-info">
                Raw data: <span id="raw-data"></span>
            </div>
        </div>
        
        <div class="actions">
            <a href="/download" class="button">Download Log Data</a>
            <button id="toggle-debug" class="button" style="background-color: #888;">Show Debug Info</button>
            <button id="toggle-api" class="button" style="background-color: #007BFF;">API Documentation</button>
        </div>
        
        <div class="api-section" id="api-docs">
            <h1>API Documentation</h1>
            <p>The MPU6050 Monitor provides a RESTful API for accessing sensor data programmatically.</p>
            
            <h2>API Endpoints</h2>
            <table>
                <tr>
                    <th>Endpoint</th>
                    <th>Method</th>
                    <th>Description</th>
                </tr>
                <tr>
                    <td><code>/api/v1/data</code></td>
                    <td>GET</td>
                    <td>Get current sensor data</td>
                </tr>
                <tr>
                    <td><code>/api/v1/status</code></td>
                    <td>GET</td>
                    <td>Get system status information</td>
                </tr>
                <tr>
                    <td><code>/api/v1/log</code></td>
                    <td>GET</td>
                    <td>Get all logged data</td>
                </tr>
                <tr>
                    <td><code>/api/v1/calibrate</code></td>
                    <td>POST</td>
                    <td>Get current calibration values</td>
                </tr>
            </table>
            
            <h2>Example Usage</h2>
            <p>Using curl to get current sensor data:</p>
            <pre>curl http://localhost:5000/api/v1/data</pre>
            
            <p>Sample response:</p>
            <pre>{
  "version": "1.0.3",
  "timestamp": "2025-04-06T18:45:30.123456",
  "data": {
    "acceleration": {
      "x": 0.12,
      "y": 9.8,
      "z": 0.05
    },
    "gyro": {
      "x": 0.01,
      "y": 0.02,
      "z": 0.01
    },
    "temperature": 28.5
  }
}</pre>
        </div>
    </div>

    <script>
        // Initialize Three.js scene
        const scene = new THREE.Scene();
        const camera = new THREE.PerspectiveCamera(75, 1, 0.1, 1000);
        const container = document.getElementById('visualization');
        const renderer = new THREE.WebGLRenderer({ antialias: true });
        renderer.setSize(container.clientWidth, container.clientHeight);
        container.appendChild(renderer.domElement);

        // Create coordinate axes
        const axesHelper = new THREE.AxesHelper(1.5);
        scene.add(axesHelper);

        // Create sensor board model
        const boardGeometry = new THREE.BoxGeometry(0.8, 0.1, 1.2);
        const boardMaterial = new THREE.MeshBasicMaterial({ 
            color: 0x00aa00,
            wireframe: false,
            transparent: true,
            opacity: 0.7
        });
        const board = new THREE.Mesh(boardGeometry, boardMaterial);
        scene.add(board);

        // Add chip
        const chipGeometry = new THREE.BoxGeometry(0.3, 0.1, 0.3);
        const chipMaterial = new THREE.MeshBasicMaterial({ color: 0x333333 });
        const chip = new THREE.Mesh(chipGeometry, chipMaterial);
        chip.position.y = 0.1;
        board.add(chip);

        // Add text for direction indicators
        const createLabel = (text, position) => {
            const canvas = document.createElement('canvas');
            canvas.width = 100;
            canvas.height = 50;
            const context = canvas.getContext('2d');
            context.fillStyle = 'white';
            context.font = '40px Arial';
            context.fillText(text, 40, 40);
            
            const texture = new THREE.CanvasTexture(canvas);
            const material = new THREE.SpriteMaterial({ map: texture });
            const sprite = new THREE.Sprite(material);
            sprite.position.copy(position);
            sprite.scale.set(0.5, 0.25, 1);
            return sprite;
        };

        const xLabel = createLabel('X', new THREE.Vector3(2, 0, 0));
        const yLabel = createLabel('Y', new THREE.Vector3(0, 2, 0));
        const zLabel = createLabel('Z', new THREE.Vector3(0, 0, 2));
        scene.add(xLabel);
        scene.add(yLabel);
        scene.add(zLabel);

        // Position camera
        camera.position.set(2, 2, 2);
        camera.lookAt(0, 0, 0);

        // Add ambient light
        const light = new THREE.AmbientLight(0xffffff, 0.5);
        scene.add(light);

        // Initialize quaternion for rotation
        const sensorQuaternion = new THREE.Quaternion();
        
        // Complementary filter variables
        const gyroData = { x: 0, y: 0, z: 0 };
        const accelData = { x: 0, y: 0, z: 0 };
        let lastTimestamp = null;
        
        // Helper function to determine arrow direction
        function getArrow(value, threshold = 0.3) {
            if (value > threshold) return '&gt;'; // >
            if (value < -threshold) return '&lt;'; // 
            return '•';
        }
        
        function getVerticalArrow(value, threshold = 0.3) {
            if (value > threshold) return '^';
            if (value < -threshold) return 'v';
            return '•';
        }
        
        // Data update function
        function updateData() {
            fetch('/data')
                .then(response => response.json())
                .then(data => {
                    // For debugging
                    document.getElementById('raw-data').textContent = JSON.stringify(data);
                    
                    // Check if data has all required fields
                    if (!data.acceleration || !data.gyro || data.temperature === undefined) {
                        console.error("Incomplete data received:", data);
                        return;
                    }
                    
                    // Update displayed values
                    document.getElementById('acc-x').textContent = data.acceleration.x.toFixed(2);
                    document.getElementById('acc-y').textContent = data.acceleration.y.toFixed(2);
                    document.getElementById('acc-z').textContent = data.acceleration.z.toFixed(2);
                    document.getElementById('gyro-x').textContent = data.gyro.x.toFixed(2);
                    document.getElementById('gyro-y').textContent = data.gyro.y.toFixed(2);
                    document.getElementById('gyro-z').textContent = data.gyro.z.toFixed(2);
                    document.getElementById('temp').textContent = data.temperature.toFixed(1);

                    // Calculate Fahrenheit temperature
                    const fahrenheit = (data.temperature * 9/5) + 32;
                    document.getElementById('temp-f').textContent = fahrenheit.toFixed(1);

                    // Update arrows
                    document.getElementById('acc-x-arrow').innerHTML = getArrow(data.acceleration.x);
                    document.getElementById('acc-y-arrow').innerHTML = getVerticalArrow(data.acceleration.y);
                    document.getElementById('acc-z-arrow').innerHTML = getArrow(data.acceleration.z);
                    document.getElementById('gyro-x-arrow').innerHTML = getVerticalArrow(data.gyro.x);
                    document.getElementById('gyro-y-arrow').innerHTML = getVerticalArrow(data.gyro.y);
                    document.getElementById('gyro-z-arrow').innerHTML = getArrow(data.gyro.z);

                    // Update sensor data for 3D model orientation
                    gyroData.x = data.gyro.x;
                    gyroData.y = data.gyro.y;
                    gyroData.z = data.gyro.z;

                    accelData.x = data.acceleration.x;
                    accelData.y = data.acceleration.y;
                    accelData.z = data.acceleration.z;

                    // Calculate orientation
                    updateOrientation();
                })
                .catch(error => console.error('Error fetching data:', error));
        }

        // Update 3D model orientation using complementary filter
        function updateOrientation() {
            // Get current time
            const now = Date.now();
            if (!lastTimestamp) {
                lastTimestamp = now;
                return;
            }

            // Calculate time delta in seconds
            const dt = (now - lastTimestamp) / 1000;
            lastTimestamp = now;

            // Calculate accel-based orientation (gravity direction)
            const accelVector = new THREE.Vector3(
                accelData.x,
                accelData.y,
                accelData.z
            ).normalize();

            // Use cross product with world up vector to get rotation axis
            const up = new THREE.Vector3(0, 1, 0);
            const rotationAxis = new THREE.Vector3().crossVectors(up, accelVector);

            // Calculate rotation angle
            const rotationAngle = Math.acos(up.dot(accelVector));

            // Create quaternion from axis-angle
            const accelQuat = new THREE.Quaternion().setFromAxisAngle(
                rotationAxis.normalize(),
                rotationAngle
            );

            // Create quaternion from gyro data
            const gyroQuat = new THREE.Quaternion().setFromEuler(
                new THREE.Euler(
                    gyroData.x * dt,
                    gyroData.y * dt,
                    gyroData.z * dt,
                    'XYZ'
                )
            );

            // Apply gyro rotation to current orientation
            sensorQuaternion.multiply(gyroQuat);

            // Complementary filter - blend between gyro and accel
            // (90% gyro, 10% accel)
            sensorQuaternion.slerp(accelQuat, 0.1);

            // Apply to 3D model
            board.quaternion.copy(sensorQuaternion);
        }

        // Animation/render loop
        function animate() {
            requestAnimationFrame(animate);
            renderer.render(scene, camera);
        }

        // Handle window resize
        function onResize() {
            camera.aspect = container.clientWidth / container.clientHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(container.clientWidth, container.clientHeight);
        }
        window.addEventListener('resize', onResize);

        // Toggle debug info
        document.getElementById('toggle-debug').addEventListener('click', function() {
            const debugInfo = document.getElementById('debug-info');
            const isHidden = debugInfo.style.display === 'none' || debugInfo.style.display === '';
            debugInfo.style.display = isHidden ? 'block' : 'none';
            this.textContent = isHidden ? 'Hide Debug Info' : 'Show Debug Info';
        });

        // Toggle API documentation
        document.getElementById('toggle-api').addEventListener('click', function() {
            const apiDocs = document.getElementById('api-docs');
            const isHidden = apiDocs.style.display === 'none' || apiDocs.style.display === '';
            apiDocs.style.display = isHidden ? 'block' : 'none';
            this.textContent = isHidden ? 'Hide API Docs' : 'API Documentation';
        });

        // Start everything
        animate();
        setInterval(updateData, 100); // Update data 10 times per second
    </script>
</body>
</html>
EOF

# 3. Update README
echo "Updating README.md..."
cat > readme.md << 'EOF'
# MPU6050 Monitor System v1.0.3

A comprehensive monitoring system for the MPU6050 accelerometer/gyroscope on Raspberry Pi Zero 2.

## Features

- Console interface with real-time sensor data display
- Web interface with 3D visualization
- RESTful API for data access
- Sensor calibration capability
- Data logging to JSON file
- Multiple run modes (console+web, web-only, console-only)

## Installation

1. Clone this repository:
   git clone https://github.com/yourusername/mpu6050-monitor
   cd mpu6050-monitor

2. Run the setup script:
   chmod +x setup.sh
   ./setup.sh

3. Connect your MPU6050 to the Raspberry Pi:
   - VCC → 3.3V
   - GND → GND
   - SCL → GPIO 3 (SCL)
   - SDA → GPIO 2 (SDA)
   - XDA → Not connected
   - XCL → Not connected
   - ADO → Not connected
   - INT → Not connected

4. Check if the sensor is detected:
   sudo i2cdetect -y 1
   You should see a device at address 0x68 (the default for MPU6050).

## Usage

### Starting the Application

Run the restart script and select your preferred mode:
./restart.sh

Options:
- Console + Web: Run both console interface and web server
- Web only: Run only the web server (good for headless operation)
- Console only: Run only the console interface (no web server)

### Console Interface

The console interface displays:
- Real-time sensor data in a single-line format
- Direction indicator
- Temperature in both Celsius and Fahrenheit
- Web interface URL information
- API information

Controls:
- c: Calibrate the sensor
- q: Quit the application

### Web Interface

Access the web interface at:
http://[your-pi-ip-address]:5000

Features:
- Real-time 3D visualization of sensor orientation
- Live sensor data display with directional indicators
- Download logged data as JSON
- API documentation

### API

The system provides a RESTful API for programmatic access to sensor data:

Endpoint: /api/v1/data
Method: GET
Description: Get current sensor data

Endpoint: /api/v1/status
Method: GET
Description: Get system status information

Endpoint: /api/v1/log
Method: GET
Description: Get all logged data

Endpoint: /api/v1/calibrate
Method: POST
Description: Get current calibration values

Example usage with curl:
curl http://[your-pi-ip-address]:5000/api/v1/data

## Data Logging

Sensor data is logged to a JSON file (default: sensor_data.json) in the following format:
{
  "readings": [
    {
      "timestamp": "2025-04-06T18:30:45.123456",
      "acceleration": { "x": 0.1, "y": 9.8, "z": 0.2 },
      "gyro": { "x": 0.01, "y": 0.0, "z": 0.02 },
      "temperature": 25.5
    },
    ...
  ]
}

## Version History

- v1.0.0: Initial release with basic console and web interfaces
- v1.0.1: Added arrow indicators and Fahrenheit temperature display
- v1.0.2: Improved layout, reduced 3D model size, console mode improvements
- v1.0.3: Added API interface, fixed console key handling, improved data logging

## License

This project is licensed under the MIT License - see the LICENSE file for details.
EOF

# 4. Create improved restart script
echo "Creating improved restart script..."
cat > restart.sh << 'EOF'
#!/bin/bash
# restart.sh - Restart MPU6050 Monitor

# Kill any existing instances
pkill -f "python3 mpu6050_monitor.py" || true
echo "Killed existing processes"

# Wait a moment
sleep 1

# Start the application in the desired mode
echo "Starting MPU6050 Monitor..."

# Choose the mode
PS3="Select mode: "
options=("Console + Web" "Web only" "Console only" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Console + Web")
            echo "Starting in combined mode..."
            python3 mpu6050_monitor.py
            break
            ;;
        "Web only")
            echo "Starting in web-only mode..."
            python3 mpu6050_monitor.py --web-only &
            echo "Web server running at http://localhost:5000"
            break
            ;;
        "Console only")
            echo "Starting in console-only mode..."
            python3 mpu6050_monitor.py --console-only
            break
            ;;
        "Cancel")
            echo "Startup cancelled"
            break
            ;;
        *)
            echo "Invalid option $REPLY"
            ;;
    esac
done
EOF

chmod +x restart.sh

# Make the script executable
echo "Making files executable..."
chmod +x mpu6050_monitor.py
chmod +x restart.sh

echo "Update to v1.0.3 complete!"
echo ""
echo "Changes in v1.0.3:"
echo "- Added RESTful API for programmatic data access"
echo "- Fixed console keyboard handling (calibrate and quit)"
echo "- Improved data logging to JSON file"
echo "- Added API documentation to web interface"
echo "- Optimized console refresh rate to reduce flicker"
echo "- Fixed temperature display issues"
echo ""
echo "To start the application:"
echo "  ./restart.sh"
