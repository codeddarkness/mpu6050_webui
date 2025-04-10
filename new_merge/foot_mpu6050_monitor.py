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
    print("\nExiting MPU6050 Monitor...")

if __name__ == "__main__":
    main()
