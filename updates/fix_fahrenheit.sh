#!/bin/bash
# Fix duplicated Fahrenheit calculation

# Create a temporary file with the JavaScript section fixed
cat > temp_js_fix.html << 'EOT'
                    document.getElementById('temp').textContent = data.temperature.toFixed(1);
                    
                    // Calculate Fahrenheit temperature
                    const fahrenheit = (data.temperature * 9/5) + 32;
                    document.getElementById('temp-f').textContent = fahrenheit.toFixed(1);
EOT

# Find the line with the first Fahrenheit calculation
line_num=$(grep -n "Calculate Fahrenheit temperature" templates/index.html | head -1 | cut -d: -f1)

if [ ! -z "$line_num" ]; then
  # Calculate end line (3 lines after the first match)
  end_line=$((line_num + 2))
  
  # Delete all instances of Fahrenheit calculation
  sed -i '/Calculate Fahrenheit temperature/,+2d' templates/index.html
  
  # Insert the correct code at the right position
  temp_line=$(grep -n "document.getElementById('temp').textContent" templates/index.html | head -1 | cut -d: -f1)
  if [ ! -z "$temp_line" ]; then
    # Insert the fixed code after the temperature line
    next_line=$((temp_line + 1))
    sed -i "${temp_line}r temp_js_fix.html" templates/index.html
    # Remove the existing temperature line to avoid duplication
    sed -i "${temp_line}d" templates/index.html
  else
    echo "Could not find temperature update line"
  fi
else
  echo "Could not find Fahrenheit calculation"
fi

rm temp_js_fix.html
echo "Fixed Fahrenheit temperature calculation"
