#!/bin/bash
# Fix the HTML template - remove duplicates

# Create a clean version of the temperature display section
cat > temp_html_fix.txt << 'EOT'
            <span class="status-section">
                <span class="status-label">Temperature</span>
                <span class="status-value" id="temp">0.0</span> °C / <span class="status-value" id="temp-f">32.0</span> °F
            </span>
EOT

# Create a clean version of the Fahrenheit calculation
cat > temp_js_fix.txt << 'EOT'
                    // Calculate Fahrenheit temperature
                    const fahrenheit = (data.temperature * 9/5) + 32;
                    document.getElementById('temp-f').textContent = fahrenheit.toFixed(1);
EOT

# Find and replace the temperature section in HTML
temp_section_line=$(grep -n "<span class=\"status-label\">Temperature</span>" templates/index.html | cut -d: -f1)
if [ ! -z "$temp_section_line" ]; then
  # Calculate the block to replace (4 lines)
  start_line=$((temp_section_line - 1))
  end_line=$((start_line + 4))
  sed -i "${start_line},${end_line}c\\$(cat temp_html_fix.txt)" templates/index.html
  echo "Fixed HTML temperature display"
fi

# Find and fix the Fahrenheit calculation in JavaScript
temp_calc_line=$(grep -n "Calculate Fahrenheit temperature" templates/index.html | head -1 | cut -d: -f1)
if [ ! -z "$temp_calc_line" ]; then
  # Remove all Fahrenheit calculation blocks (find a better pattern)
  sed -i '/Calculate Fahrenheit temperature/,+2d' templates/index.html
  # Find temp display line
  display_line=$(grep -n "document.getElementById('temp').textContent" templates/index.html | cut -d: -f1)
  if [ ! -z "$display_line" ]; then
    # Insert after this line
    sed -i "${display_line}r temp_js_fix.txt" templates/index.html
    echo "Fixed JavaScript Fahrenheit calculation"
  fi
fi

rm temp_html_fix.txt temp_js_fix.txt
echo "Template fixes applied"
