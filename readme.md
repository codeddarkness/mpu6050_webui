# MPU6050 Monitor System v1.0.4

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
- v1.0.4: Added API interface, fixed console key handling, improved data logging

## License

This project is licensed under the MIT License - see the LICENSE file for details.
