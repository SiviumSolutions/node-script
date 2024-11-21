#!/bin/bash

# --------------------------------------------
# ANSI Color Codes for Styled Output
# --------------------------------------------
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --------------------------------------------
# Function: Display Success Message
# --------------------------------------------
success_message() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}$1${NC}"
}

# --------------------------------------------
# Function: Display Error Message and Exit
# --------------------------------------------
error_exit() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: $1${NC}"
  exit 1
}

# --------------------------------------------
# Function: Display an informational message
# --------------------------------------------
info_message() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}$1${NC}"
}

# --------------------------------------------
# URLs for Additional Scripts
# --------------------------------------------
SCRIPT_URLS=(
  "https://raw.githubusercontent.com/SiviumSolutions/node-script/main/sentry.sh"
  "https://raw.githubusercontent.com/SiviumSolutions/node-script/main/start.sh"
  "https://raw.githubusercontent.com/SiviumSolutions/node-script/main/check.sh"
  "https://raw.githubusercontent.com/SiviumSolutions/node-script/main/nginx.sh"
)
SCRIPT_NAMES=("sentry.sh" "start.sh" "check.sh" "nginx.sh")

# --------------------------------------------
# Download and Set Permissions
# --------------------------------------------
success_message "Starting Sivium installer v0.2.4..."
info_message "Powered by Sivium Solutions 2024"
info_message "Downloading additional scripts..."
for i in "${!SCRIPT_URLS[@]}"; do
  curl -o "${SCRIPT_NAMES[i]}" "${SCRIPT_URLS[i]}" || error_exit "Failed to download ${SCRIPT_NAMES[i]}"
done

# Set executable permissions
info_message "Setting execute permissions..."
chmod +x "${SCRIPT_NAMES[@]}" || error_exit "Failed to set permissions for scripts"

# --------------------------------------------
# Start Main Script
# --------------------------------------------
success_message "Scripts downloaded and permissions set successfully."
info_message "Starting the main script..."
./start.sh || error_exit "Failed to execute start.sh"
