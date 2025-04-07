#!/bin/bash
# Add web server launch command back to mpu6050_monitor.py

# Find the show_menu function
menu_line=$(grep -n "def show_menu" mpu6050_monitor.py | cut -d: -f1)

if [ ! -z "$menu_line" ]; then
  # Look for the line with "[4] Start Web Server"
  webserver_line=$(tail -n +$menu_line mpu6050_monitor.py | grep -n "Start Web Server" | head -1 | cut -d: -f1)
  if [ ! -z "$webserver_line" ]; then
    actual_line=$((menu_line + webserver_line + 2))
    sed -i "${actual_line}i\                print(\"Starting web server in background...\")\n                os.system(\"python3 web_server.py \&\")" mpu6050_monitor.py
    echo "Added web server launch command"
  else
    echo "Could not find 'Start Web Server' menu option"
  fi
else
  echo "Could not find show_menu function"
fi
