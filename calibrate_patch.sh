#!/bin/bash
# fix_calibration_api.sh - Script to patch MPU6050 Monitor API calibration

echo "Applying API calibration patch to mpu6050_monitor.py..."

# Backup the original file first (if not already backed up)
if [ ! -f mpu6050_monitor.py.old ]; then
  cp mpu6050_monitor.py mpu6050_monitor.py.old
fi

# Create the calibration API patch
cat > calibration_api_fix.patch << 'EOF'
--- mpu6050_monitor.py    2025-04-10 14:00:00.000000000 +0000
+++ mpu6050_monitor.py.new    2025-04-10 14:00:00.000000000 +0000
@@ -124,6 +124,29 @@
     print("\nCalibration complete!")
     return config
 
+def api_calibrate_sensor():
+    """Perform calibration via API without requiring console input"""
+    global sensor_data
+    
+    logger.info("API-triggered calibration started")
+    
+    # Store 100 samples for calibration
+    x_vals, y_vals, z_vals = [], [], []
+    
+    # Collect acceleration samples (non-blocking)
+    for i in range(100):
+        data = sensor_data.copy()  # Use the current sensor data
+        x_vals.append(data["acceleration"]["x"])
+        y_vals.append(data["acceleration"]["y"])
+        z_vals.append(data["acceleration"]["z"] - 9.8)  # Subtract gravity from z axis
+        time.sleep(0.01)
+    
+    # Calculate and apply calibration
+    config = load_config()
+    config["calibration"]["x_offset"] = -sum(x_vals) / len(x_vals)
+    config["calibration"]["y_offset"] = -sum(y_vals) / len(y_vals)
+    config["calibration"]["z_offset"] = -sum(z_vals) / len(z_vals)
+    config["calibration"]["calibrated"] = True
+    save_config(config)
+    return config
+
 def sensor_thread():
     """Background thread to continuously read sensor data"""
     global sensor_data, running
@@ -531,16 +554,32 @@
         logger.error(f"Error in API /api/v1/log: {e}")
         return jsonify({"readings": [], "error": str(e), "status": "error"})
 
-@app.route('/api/v1/calibrate', methods=['POST'])
+@app.route('/api/v1/calibrate', methods=['GET', 'POST'])
 def api_calibrate():
     """API endpoint to trigger calibration"""
-    global sensor_data
+    logger.info(f"API call: /api/v1/calibrate with method {request.method}")
     
-    # We can't directly calibrate the sensor here as it requires console input
-    # So just return the current calibration values
-    config = load_config()
+    if request.method == 'GET':
+        # Return current calibration values for GET requests
+        config = load_config()
+        return jsonify({
+            "status": "success",
+            "calibration": config["calibration"]
+        })
     
-    return jsonify({
-        "status": "success",
-        "message": "Current calibration values returned. Use console mode for full calibration.",
-        "calibration": config["calibration"]
-    })
+    if request.method == 'POST':
+        try:
+            # Perform calibration for POST requests
+            config = api_calibrate_sensor()
+            return jsonify({
+                "status": "success",
+                "message": "Calibration completed successfully.",
+                "calibration": config["calibration"]
+            })
+        except Exception as e:
+            logger.error(f"Error during API calibration: {e}")
+            return jsonify({
+                "status": "error",
+                "message": f"Error during calibration: {e}",
+                "calibration": load_config()["calibration"]
+            }), 500
EOF

# Fix the Flask import to include request
sed -i "1,/from flask import/s/from flask import \([^,]*\)/from flask import \1, request/" mpu6050_monitor.py

# Apply the calibration API patch
patch mpu6050_monitor.py -i calibration_api_fix.patch

# Create a calibration test script
cat > test_calibration_api.sh << 'EOF'
#!/bin/bash
# test_calibration_api.sh - Test the calibration API

echo "Testing MPU6050 calibration API..."

# Get current calibration values (GET request)
echo "Getting current calibration values..."
curl -s http://localhost:5000/api/v1/calibrate | python3 -m json.tool

# Trigger calibration (POST request)
echo -e "\nTriggering calibration..."
echo "Please keep the sensor level and still during calibration..."
curl -s -X POST http://localhost:5000/api/v1/calibrate | python3 -m json.tool

echo -e "\nCalibration test complete"
EOF

chmod +x test_calibration_api.sh

echo "API calibration patch applied successfully!"
echo "Run './test_calibration_api.sh' to test the calibration API"