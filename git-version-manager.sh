#!/bin/bash
# Git Version Management Script

# Configuration
VERSION="1.0.4"
MAIN_BRANCH="main"
DEV_BRANCH="dev/bug_fixes_v${VERSION}"
ESSENTIAL_FILES=(
    "mpu6050_monitor.py"
    "templates/index.html"
    "readme.md"
    "setup.sh"
    "restart.sh"
)

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to update version in files
update_version_in_files() {
    local new_version=${1/^v/}
    
    # Update version in Python script
    sed -i "s/# Console monitor for MPU6050 sensor.*$/# Console monitor for MPU6050 sensor with web interface - v${new_version}/" mpu6050_monitor.py
    sed -i "s/MPU6050 MONITOR v[0-9.]\+/MPU6050 MONITOR v${new_version}/" mpu6050_monitor.py
    
    # Update version in HTML
    sed -i "s/templates\/index.html - v[0-9.]\+/templates\/index.html - v${new_version}/" templates/index.html
    
    # Update version in README
    sed -i "s/# MPU6050 Monitor System v[0-9.]\+/# MPU6050 Monitor System v${new_version}/" readme.md
    sed -i "s/- v[0-9.]\+:/-v${new_version}:/" readme.md
}

# Function to handle merge conflicts
handle_merge_conflicts() {
    local conflicting_files
    conflicting_files=$(git diff --name-only --diff-filter=U)
    
    if [ -n "$conflicting_files" ]; then
        echo -e "${YELLOW}Merge conflicts detected in:${NC}"
        echo "$conflicting_files"
        
        echo -e "${RED}Options:${NC}"
        echo "1. Manually resolve conflicts"
        echo "2. Stash and create a new branch"
        echo "3. Abort merge"
        
        read -p "Choose an option (1/2/3): " conflict_option
        
        case $conflict_option in
            1)
                echo "Please manually resolve conflicts in the mentioned files."
                ;;
            2)
                # Create a new branch with conflicting files
                timestamp=$(date +"%Y%m%d_%H%M%S")
                conflict_branch="conflict_resolution_${timestamp}"
                git checkout -b "$conflict_branch"
                git add $conflicting_filesgit commit -m "Stashed conflicting files from merge attempt"
                echo -e "${GREEN}Created new branch ${conflict_branch} with conflicting files.${NC}"
                ;;
            3)
                git merge --abort
                echo -e "${RED}Merge aborted.${NC}"
                ;;
            *)
                echo -e "${RED}Invalid option. Aborting.${NC}"
                git merge --abort
                ;;
        esac
    else
        echo -e "${GREEN}No merge conflicts detected.${NC}"
    fi
}

# Function to push essential files to main
push_essential_files_to_main() {
    # Ensure we're on the dev branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" != "$DEV_BRANCH" ]]; then
        echo -e "${RED}Error: Not on the development branch ${DEV_BRANCH}${NC}"
        exit 1
    fi
    
    # Create a temporary directory for essential files
    temp_dir=$(mktemp -d)
    
    # Copy essential files to temp directory
    for file in "${ESSENTIAL_FILES[@]}"; do
        if [ -f "$file" ]; then
            mkdir -p "${temp_dir}/$(dirname "$file")"
            cp "$file" "${temp_dir}/$file"
        else
            echo -e "${YELLOW}Warning: File $file not found${NC}"
        fi
    done
    
    # Checkout main branch
    git checkout "$MAIN_BRANCH"
    
    # Copy essential files back
    for file in "${ESSENTIAL_FILES[@]}"; do
        if [ -f "${temp_dir}/$file" ]; then
            mkdir -p "$(dirname "$file")"
            cp "${temp_dir}/$file" "$file"
        fi
    done
    
    # Stage, commit, and push
    git add "${ESSENTIAL_FILES[@]}"
    git commit -m "Update essential files to version ${VERSION}"
    git push origin "$MAIN_BRANCH"
    
    # Return to dev branch
    git checkout "$DEV_BRANCH"
    
    # Clean up temp directory
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}Essential files pushed to main branch${NC}"
}

# Main menu
show_menu() {
    echo "Git Version Management Script"
    echo "----------------------------"
    echo "1. Update version in files"
    echo "2. Push essential files to main branch"
    echo "3. Handle merge conflicts"
    echo "4. Exit"
}

# Main script logic
while true; do
    show_menu
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            read -p "Enter new version number: " new_version
            update_version_in_files "$new_version"
            echo -e "${GREEN}Version updated in files${NC}"
            ;;
        2)
            push_essential_files_to_main
            ;;
        3)
            handle_merge_conflicts
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo # New line for readability
done
