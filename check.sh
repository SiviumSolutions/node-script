#!/bin/bash

# ============================================
# SIVIUM SCRIPTS - Dependency Checker
# ============================================
# This script verifies the installation of essential
# tools and scripts required for the project.
# ============================================

# --------------------------------------------
# ANSI Color Codes for Styled Output
# --------------------------------------------
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --------------------------------------------
# Function: Display an error message and exit
# --------------------------------------------
error_exit() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: $1${NC}"
  exit 1
}

# --------------------------------------------
# Function: Display a success message
# --------------------------------------------
success_message() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}$1${NC}"
}

# --------------------------------------------
# Function: Display an informational message
# --------------------------------------------
info_message() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}$1${NC}"
}

# --------------------------------------------
# Function: Check if a command exists
# --------------------------------------------
check_command() {
  local cmd="$1"
  local name="$2"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    error_exit "$name not found. Please install $name before running this script."
  else
    success_message "$name is already installed."
  fi
}

# --------------------------------------------
# Function: Check if a file exists and is executable
# --------------------------------------------
check_file() {
  local file_path="$1"
  local name="$2"

  if [ ! -f "$file_path" ]; then
    error_exit "$name not found at $file_path. Please ensure it exists and is executable."
  elif [ ! -x "$file_path" ]; then
    error_exit "$name at $file_path is not executable. Please modify its permissions."
  else
    success_message "$name is already installed and executable."
  fi
}

# --------------------------------------------
# Parse Command-Line Arguments
# --------------------------------------------
SILENT_MODE=false

# Check if the first argument is --silent
if [[ "$1" == "--silent" ]]; then
  SILENT_MODE=true
fi

# --------------------------------------------
# Dependency Checks
# --------------------------------------------

# Check for 'wrangler' command
check_command "wrangler" "Wrangler"

# Check for 'jq' command
check_command "jq" "Jq"

# Check for '.acme/acme.sh' script
ACME_SCRIPT_PATH="./.acme/acme.sh"
check_file "$ACME_SCRIPT_PATH" "Acme.sh"

# Check for 'pm2' command
check_command "pm2" "Pm2"

# Check for 'bun' command
check_command "bun" "Bun"

# Check for 'sentry-cli' command
check_command "sentry-cli" "Sentry-cli"

# --------------------------------------------
# Handle Silent Mode
# --------------------------------------------
if $SILENT_MODE; then
  exit 0
fi

# --------------------------------------------
# Final Message and Wait for User Input
# --------------------------------------------
info_message "All dependencies are verified. Press any key to exit..."
read -n 1 -s
echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Exiting.${NC}"
