#!/bin/bash
# Fix duplicate Fahrenheit temperature calculation

# Create a temporary file
cat templates/index.html > temp_index.html

# Remove any duplicate lines
awk '!/ Calculate Fahrenheit temperature/ || !seen[$0]++' temp_index.html | 
awk '!/ document.getElementById(.temp-f.)/ || !seen[$0]++' > templates/index.html

rm temp_index.html
echo "Fixed duplicate Fahrenheit calculation lines"
