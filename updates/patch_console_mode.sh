#!/bin/bash
# patch_console_mode.sh - Patch the console mode function

# Check if console_mode_update.py exists
if [ ! -f "console_mode_update.py" ]; then
    echo "Error: console_mode_update.py not found!"
    exit 1
fi

# Create a backup of the current script
cp mpu6050_monitor.py mpu6050_monitor.py.bak

# Extract the run_console_mode function from the update file
# Using a heredoc to carefully extract just the function
python3 -c "
import re

with open('console_mode_update.py', 'r') as f:
    content = f.read()

# Extract the function using regex
match = re.search(r'def run_console_mode\(.*?:\n(.*?)(?=\n\n|\n\w+|\Z)', content, re.DOTALL)

if match:
    function_body = match.group(0)
    
    # Read the existing script
    with open('mpu6050_monitor.py', 'r') as script:
        script_content = script.read()
    
    # Replace the existing run_console_mode function
    import re
    new_script_content = re.sub(
        r'def run_console_mode\(.*?:\n(.*?)(?=\n\n|\n\w+|\Z)', 
        function_body, 
        script_content, 
        flags=re.DOTALL
    )
    
    # Write back to the script
    with open('mpu6050_monitor.py', 'w') as script:
        script.write(new_script_content)
    
    print('Console mode function successfully updated.')
else:
    print('Error: Could not extract run_console_mode function.')
"

# Check if the update was successful
if [ $? -eq 0 ]; then
    echo "Patch applied successfully. The original script is backed up as mpu6050_monitor.py.bak"
else
    echo "Patch failed. Restoring original script."
    mv mpu6050_monitor.py.bak mpu6050_monitor.py
fi
