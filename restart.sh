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
options=("Console + Web" "Console(text) + Web" "Web only" "Console only" "Console(text) only" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Console + Web")
            echo "Starting in combined mode..."
            python3 mpu6050_monitor.py
            break
            ;;
        "Console(text) + Web")
            echo "Starting in text console with web mode..."
            python3 mpu6050_monitor.py --text-console
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
        "Console(text) only")
            echo "Starting in text-only console mode..."
            python3 mpu6050_monitor.py --text-only
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
