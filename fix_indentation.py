#!/usr/bin/env python3
import re
import io

def fix_indentation(filename):
    # Read the file
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    # Process lines
    fixed_lines = []
    current_indent = 0
    in_multiline_string = False
    in_function = False
    
    for line in lines:
        # Strip trailing whitespace
        stripped_line = line.rstrip()
        
        # Skip completely empty lines
        if not stripped_line:
            fixed_lines.append('\n')
            continue
        
        # Check for multiline string start/end
        if '"""' in stripped_line or "'''" in stripped_line:
            in_multiline_string = not in_multiline_string
        
        # If in multiline string, preserve original indentation
        if in_multiline_string:
            fixed_lines.append(line)
            continue
        
        # Remove leading whitespace
        line_without_indent = stripped_line.lstrip()
        
        # Detect function and class definitions
        if line_without_indent.startswith(('def ', 'class ')):
            current_indent = len(stripped_line) - len(line_without_indent)
            in_function = True
            fixed_lines.append(stripped_line + '\n')
            continue
        
        # Detect end of function or block
        if in_function and line_without_indent and not line_without_indent.startswith(' '):
            in_function = False
        
        # Add appropriate indentation
        if in_function:
            # If the line is not empty and doesn't start with current indent, add 4 spaces
            if line_without_indent and len(stripped_line) - len(line_without_indent) < current_indent:
                fixed_line = ' ' * (current_indent + 4) + line_without_indent + '\n'
            else:
                fixed_line = stripped_line + '\n'
        else:
            # For lines outside of functions, remove extra indentation
            fixed_line = line_without_indent + '\n'
        
        fixed_lines.append(fixed_line)
    
    # Write back to file
    with open(filename, 'w') as f:
        f.writelines(fixed_lines)
    
    print("Indentation and whitespace cleaned up.")

# Specify the file to fix
fix_indentation('mpu6050_monitor.py')
