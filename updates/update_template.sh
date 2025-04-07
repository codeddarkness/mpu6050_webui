#!/bin/bash
# update_template.sh - Creates backup and updates index.html

# Create backup
cp templates/index.html templates/index.html.bak

# Update version in comment
sed -i '1s/v1.0.0/v1.0.1/' templates/index.html

# Create a new template file
cat > templates/new_index.html << 'EOT'
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
                <span class="status-value" id="temp">0.0</span> °C /
                <span class="status-value" id="temp-f">32.0</span> °F
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

# Replace the template file
mv templates/new_index.html templates/index.html

echo "templates/index.html updated to v1.0.1"
