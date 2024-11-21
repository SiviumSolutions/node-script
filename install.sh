#!/bin/bash

# --------------------------------------------
# ANSI Color Codes for Styled Output
# --------------------------------------------
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
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
# Function: Display an Informational Message
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
# Parse Arguments
# --------------------------------------------
WITH_UPDATE=false
for arg in "$@"; do
  if [[ "$arg" == "--withUpdate" ]]; then
    WITH_UPDATE=true
  fi
done

# --------------------------------------------
# Update Scripts if --withUpdate is Provided
# --------------------------------------------
if [ "$WITH_UPDATE" = true ]; then
  success_message "Starting Sivium installer v0.2.4 with updates..."
  info_message "Powered by Sivium Solutions 2024"
  info_message "Downloading additional scripts..."

  for i in "${!SCRIPT_URLS[@]}"; do
    curl -o "${SCRIPT_NAMES[i]}" "${SCRIPT_URLS[i]}" || error_exit "Failed to download ${SCRIPT_NAMES[i]}"
  done

  # Set executable permissions
  info_message "Setting execute permissions..."
  chmod +x "${SCRIPT_NAMES[@]}" || error_exit "Failed to set permissions for scripts"
else
  info_message "Skipping script updates (no --withUpdate flag provided)."
fi

# --------------------------------------------
# Load Environment Variables from .env
# --------------------------------------------
if [ -f ".env" ]; then
  info_message "Loading environment variables from .env..."
  export $(grep -v '^#' .env | xargs) || error_exit "Failed to load environment variables from .env"
else
  error_exit "Environment file (.env) not found. Please ensure it exists."
fi

# --------------------------------------------
# Start Main Script
# --------------------------------------------
success_message "Scripts prepared successfully."
info_message "Starting the main script..."

./start.sh --port "$SERVER_PORT" \
           --autoupdate "$AUTO_UPDATE" \
           --branch "$BRANCH" \
           --prjtype "$PRJ_TYPE" \
           --pm "$PKG_MANAGER" \
           --build-before-start "$BUILD_BEFORE_START" \
           --reinstall-modules "$REINSTALL_MODULES" \
           --force-rebuild "$FORCE_REBUILD" || error_exit "Failed to execute start.sh"
