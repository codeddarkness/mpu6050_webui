#!/bin/bash
# setup.sh - v1.0.0
# Setup script for MPU6050 Monitor

echo "Setting up MPU6050 Monitor v1.0.0..."

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv i2c-tools

# Enable I2C if not already enabled
if ! grep -q "^dtparam=i2c_arm=on" /boot/config.txt; then
    echo "Enabling I2C interface..."
    sudo bash -c 'echo "dtparam=i2c_arm=on" >> /boot/config.txt'
    echo "I2C interface enabled. The system will need to be rebooted."
else
    echo "I2C interface is already enabled."
fi

# Create and activate virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
pip install adafruit-circuitpython-mpu6050 flask

# Create service file for autostart (optional)
echo "Creating systemd service file..."
cat > mpu6050monitor.service << EOL
[Unit]
Description=MPU6050 Monitor Service
After=network.target

[Service]
ExecStart=/bin/bash -c 'cd $(pwd) && source venv/bin/activate && python3 web_server.py'
WorkingDirectory=$(pwd)
StandardOutput=inherit
StandardError=inherit
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOL

echo "Installation complete!"
echo ""
echo "To start the service manually:"
echo "  source venv/bin/activate"
echo "  python3 mpu6050_monitor.py"
echo ""
echo "To start the web interface:"
echo "  source venv/bin/activate"
echo "  python3 web_server.py"
echo ""
echo "To install as a system service (start automatically at boot):"
echo "  sudo cp mpu6050monitor.service /etc/systemd/system/"
echo "  sudo systemctl enable mpu6050monitor.service"
echo "  sudo systemctl start mpu6050monitor.service"
echo ""
echo "To check I2C connection:"
echo "  sudo i2cdetect -y 1"
echo ""
echo "If the system needs to be rebooted to enable I2C, please run:"
echo "  sudo reboot"
