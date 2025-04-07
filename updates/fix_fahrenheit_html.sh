#!/bin/bash
# Fix the Fahrenheit temperature display in HTML

# Find the Temperature section in the HTML
TEMP_LINE=$(grep -n "<span class=\"status-label\">Temperature</span>" templates/index.html | cut -d: -f1)

if [ ! -z "$TEMP_LINE" ]; then
  # Check the current format
  NEXT_LINE=$((TEMP_LINE + 1))
  CURRENT_FORMAT=$(sed -n "${NEXT_LINE}p" templates/index.html)
  
  echo "Current temperature format: $CURRENT_FORMAT"
  
  # Update with the correct format
  sed -i "${NEXT_LINE}c\\                <span class=\"status-value\" id=\"temp\">0.0</span> °C / <span class=\"status-value\" id=\"temp-f\">32.0</span> °F" templates/index.html
  
  echo "Updated temperature display format"
else
  echo "Could not find temperature label"
fi
