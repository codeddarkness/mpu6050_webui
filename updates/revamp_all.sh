#!/bin/bash
# fix_all_issues.sh - Comprehensive fix for MPU6050 Monitor v1.0.1

echo "Creating comprehensive fix for MPU6050 Monitor..."

# 1. Fix mpu6050_monitor.py - Clean up duplications
cat > mpu6050_monitor.py << 'EOT'
#!/usr/bin/env python3
# mpu6050_monitor.py - v1.0.1
# Flask web server for MPU6050 sensor visualization

from flask import Flask, render_template, jsonify, send_file, Response
import json
import os
import threading
import time
import board
import busio
import adafruit_mpu6050

app = Flask("mpu6050_web_server")

# Global sensor data (updated by background thread)
sensor_data = {
    "acceleration": {"x": 0, "y": 0, "z": 0},
    "gyro": {"x": 0, "y": 0, "z": 0},
    "temperature": 0
}

# Load configuration
def load_config():
    if os.path.exists("config.json"):
        with open("config.json", "r") as f:
            return json.load(f)
    return {
        "data_file": "sensor_data.json",
        "sample_rate": 0.1,
        "calibration": {
            "x_offset": 0,
            "y_offset": 0,
            "z_offset": 0,
            "calibrated": False
        }
    }

# Initialize sensor
def init_sensor():
    config = load_config()
    try:
        i2c = busio.I2C(board.SCL, board.SDA)
        mpu = adafruit_mpu6050.MPU6050(i2c)
        print("MPU6050 sensor initialized successfully")
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
        # Return dummy data for testing
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

# Routes
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

if __name__ == '__main__':
    # Start sensor reading in background thread
    thread = threading.Thread(target=sensor_thread, daemon=True)
    thread.start()
    
    # Start Flask server
    print("Starting web server at http://0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
EOT

echo "Fixed mpu6050_monitor.py"

# 2. Fix index.html - Clean up duplications
cat > templates/index.html << 'EOT'
<!-- templates/index.html - v1.0.1 -->
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
        .panel {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            margin: 10px;
            padding: 15px;
        }
        .visualization-panel {
            width: 100%;
            height: 400px;
            position: relative;
        }
        #visualization {
            width: 100%;
            height: 100%;
        }
        .status-panel {
            width: calc(100% - 20px);
            padding: 10px;
            margin: 10px;
            background-color: #333;
            color: white;
            border-radius: 5px;
            font-family: monospace;
            font-size: 14px;
            overflow-x: auto;
            white-space: nowrap;
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
        h1 {
            margin-top: 0;
            color: #333;
            font-size: 1.5em;
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
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="panel visualization-panel">
            <h1>MPU6050 3D Orientation</h1>
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
        
        <div class="actions">
            <a href="/download" class="button">Download Log Data</a>
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
        const boardGeometry = new THREE.BoxGeometry(1, 0.1, 1.5);
        const boardMaterial = new THREE.MeshBasicMaterial({ 
            color: 0x00aa00,
            wireframe: false,
            transparent: true,
            opacity: 0.7
        });
        const board = new THREE.Mesh(boardGeometry, boardMaterial);
        scene.add(board);

        // Add chip
        const chipGeometry = new THREE.BoxGeometry(0.4, 0.1, 0.4);
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
        camera.position.set(3, 3, 3);
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
        
        // Start everything
        animate();
        setInterval(updateData, 100); // Update data 10 times per second
    </script>
</body>
</html>
EOT

echo "Fixed templates/index.html"

# Remove web_server.py since it's now merged with mpu6050_monitor.py
echo "Moving web_server.py to backups/web_server.py.bak"
mkdir -p backups
mv web_server.py backups/web_server.py.bak

# Create a restart script
cat > restart.sh << 'EOT'
#!/bin/bash
# Restart the MPU6050 Monitor application

# Kill any existing instances
pkill -f "python3 mpu6050_monitor.py" || true
echo "Killed existing processes"

# Wait a moment
sleep 1

# Start the application
echo "Starting MPU6050 Monitor..."
python3 mpu6050_monitor.py

echo "Application restarted!"
EOT

chmod +x restart.sh
echo "Created restart script"

echo "All fixes applied. Run './restart.sh' to restart the application."
