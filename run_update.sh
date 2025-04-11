#!/bin/bash
# fix_mpu6050.sh - Script to patch MPU6050 Monitor issues

echo "Applying patches to mpu6050_monitor.py..."

# Backup the original file first
cp mpu6050_monitor.py mpu6050_monitor.py.old

# Fix the duplicate 'else' statement in main() function that might be causing issues
sed -i '/else:/N;/else:\n\s*# Both console and web server/!b;N;N;N;N;N;N;N;d' mpu6050_monitor.py.bak

# Fix the text console alignment by modifying the formatting in run_text_console_mode
sed -i 's/print(f"Acceleration (m\/s²): X: {ax:6.2f}{acc_x_arrow} Y: {ay:6.2f}{acc_y_arrow} Z: {az:6.2f}{acc_z_arrow}")/print(f"Acceleration (m\/s²): X: {ax:7.2f} {acc_x_arrow} Y: {ay:7.2f} {acc_y_arrow} Z: {az:7.2f} {acc_z_arrow}")/' mpu6050_monitor.py
sed -i 's/print(f"Gyroscope (rad\/s):   X: {gx:6.2f}{gyro_x_arrow} Y: {gy:6.2f}{gyro_y_arrow} Z: {gz:6.2f}{gyro_z_arrow}")/print(f"Gyroscope (rad\/s):   X: {gx:7.2f} {gyro_x_arrow} Y: {gy:7.2f} {gyro_y_arrow} Z: {gz:7.2f} {gyro_z_arrow}")/' mpu6050_monitor.py

# Fix API issues by ensuring error handling in the log endpoint
cat > api_fix.patch << 'EOF'
--- mpu6050_monitor.py    2025-04-10 12:00:00.000000000 +0000
+++ mpu6050_monitor.py.new    2025-04-10 12:00:00.000000000 +0000
@@ -517,16 +517,21 @@
 @app.route('/api/v1/log')
 def api_get_log():
     """API endpoint to get logged data"""
+    logger.info("API call: /api/v1/log")
     config = load_config()
     try:
-        with open(config["data_file"], "r") as f:
-            content = f.read().strip()
-            if content:
-                return jsonify(json.loads(content))
-            else:
-                return jsonify({"readings": []})
-    except (FileNotFoundError, json.JSONDecodeError):
-        return jsonify({"readings": []})
+        # Check if file exists before trying to open it
+        if os.path.exists(config["data_file"]):
+            with open(config["data_file"], "r") as f:
+                content = f.read().strip()
+                if content:
+                    return jsonify(json.loads(content))
+                else:
+                    return jsonify({"readings": []})
+        else:
+            return jsonify({"readings": [], "status": "no_data_file"})
+    except Exception as e:
+        logger.error(f"Error in API /api/v1/log: {e}")
+        return jsonify({"readings": [], "error": str(e), "status": "error"})
EOF

# Apply the API fix patch
patch mpu6050_monitor.py -i api_fix.patch

# Fix the web interface status panel layout issues
cat > web_interface_fix.patch << 'EOF'
--- templates/index.html    2025-04-10 12:00:00.000000000 +0000
+++ templates/index.html.new    2025-04-10 12:00:00.000000000 +0000
@@ -56,7 +56,7 @@
             width: 100%;
             padding: 15px;
             margin-top: 10px;
-            background-color: var(--status-bg);
+            background-color: var(--status-bg); 
             color: var(--status-text);
             border-radius: 5px;
             font-family: monospace;
@@ -68,12 +68,14 @@
             min-width: 50px;
             text-align: right;
         }
-        .status-label {
+        .status-label { 
             font-weight: bold;
             color: #aaa;
             width: 150px;
             display: inline-block;
             margin-right: 10px;
+            white-space: nowrap;
+            vertical-align: middle;
         }
         .status-section {
             margin: 5px 0;
EOF

# Apply the web interface fix patch
patch templates/index.html -i web_interface_fix.patch

# Create a simple script to check API and console status
cat > check_mpu6050.sh << 'EOF'
#!/bin/bash
# check_mpu6050.sh - Check MPU6050 Monitor health

echo "Checking MPU6050 Monitor health..."

# Check I2C connection
echo "Checking I2C connection to MPU6050..."
if which i2cdetect >/dev/null; then
    i2cdetect -y 1 | grep -q "68" && echo "MPU6050 found on I2C bus" || echo "WARNING: MPU6050 not detected on I2C bus"
else
    echo "i2cdetect not found, skipping I2C check"
fi

# Check if web server is running
echo "Checking web server..."
curl -s http://localhost:5000 > /dev/null && echo "Web server is running" || echo "WARNING: Web server is not responding"

# Check API endpoint
echo "Checking API endpoints..."
curl -s http://localhost:5000/api/v1/data > /dev/null && echo "API /data endpoint is responding" || echo "WARNING: API /data endpoint is not responding"
curl -s http://localhost:5000/api/v1/log > /dev/null && echo "API /log endpoint is responding" || echo "WARNING: API /log endpoint is not responding"

# Check log file
echo "Checking log file..."
if [ -f "web_server.log" ]; then
    tail -5 web_server.log
    grep -q "ERROR" web_server.log && echo "WARNING: Errors found in log file" || echo "No recent errors in log file"
else
    echo "WARNING: web_server.log not found"
fi

echo "Health check complete"
EOF

chmod +x check_mpu6050.sh

echo "Patches applied successfully!"
echo "Run './check_mpu6050.sh' to verify system health"