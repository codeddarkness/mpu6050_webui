# MPU6050 Monitor System v1.0.0

A comprehensive monitoring system for the MPU6050 accelerometer/gyroscope on Raspberry Pi Zero 2.

## Features

- Console interface with real-time sensor data display
- Sensor calibration capability
- Data logging to JSON file
- Web interface with 3D visualization
- Download logged data via web interface

## Installation

1. Clone this repository:
git clone https://github.com/yourusername/mpu6050-monitor
cd mpu6050-monitor
Copy
2. Run the setup script:
chmod +x setup.sh
./setup.sh
Copy
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
CopyYou should see a device at address 0x68 (the default for MPU6050).

## Usage

### Console Interface

Run the console interface with:
source venv/bin/activate
python3 mpu6050_monitor.py
Copy
The interface offers:
- Real-time sensor data display
- Direction indicator
- Calibration option
- Menu to access other features

### Web Interface

Start the web server with:
source venv/bin/activate
python3 web_server.py
Copy
Then access the web interface at:
`http://[your-pi-ip-address]:5000`

Features:
- Real-time sensor data
- 3D visualization of sensor orientation
- Download logged data as JSON

## Automatic Startup

To configure the system to start automatically at boot:
sudo cp mpu6050monitor.service /etc/systemd/system/
sudo systemctl enable mpu6050monitor.service
sudo systemctl start mpu6050monitor.service
Copy
## Files

- `mpu6050_monitor.py`: Console monitoring interface
- `web_server.py`: Flask web server
- `templates/index.html`: Web interface
- `setup.sh`: Installation script
- `config.json`: Configuration file (created on first run)
- `sensor_data.json`: Logged sensor data (created on first run)

## Versioning

- v1.0.0: Initial release with console and web interfaces

## License

This project is licensed under the MIT License - see the LICENSE file for details.
