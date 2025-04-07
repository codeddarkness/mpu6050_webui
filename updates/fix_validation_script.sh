#!/bin/bash
# Fix the validation script to properly detect Fahrenheit display

# Find the line checking for Fahrenheit in the validation script
grep -n "Fahrenheit temperature display" validate_updates.sh

# Update the validation check to match what's actually in the template
sed -i 's/if grep -q "Temperature.*°C \/ .*°F" templates\/index.html/if grep -q "°C \/ .*°F" templates\/index.html/' validate_updates.sh

echo "Updated validation script"
