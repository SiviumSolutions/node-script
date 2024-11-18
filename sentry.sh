#!/bin/bash

# ============================================
# SIVIUM SCRIPTS - Create Sentry Release
# ============================================
# This script automates the creation of a new release in Sentry
# based on the version specified in package.json.
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
# Function: Get version from package.json using jq
# --------------------------------------------
get_version() {
  if command -v jq >/dev/null 2>&1; then
    VERSION=$(jq -r '.version' package.json)
  else
    # Fallback to grep and sed if jq is not installed
    VERSION=$(grep '"version"' package.json | sed 's/.*"version": "\(.*\)",/\1/')
  fi
  echo "$VERSION"
}

# --------------------------------------------
# Check if the script is running on Linux
# --------------------------------------------
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  error_exit "This script only supports Linux."
fi

# --------------------------------------------
# Check for the existence of package.json
# --------------------------------------------
if [ ! -f package.json ]; then
  error_exit "package.json file not found!"
fi

# --------------------------------------------
# Retrieve the version from package.json
# --------------------------------------------
VERSION=$(get_version)

# --------------------------------------------
# Validate that the version was successfully retrieved
# --------------------------------------------
if [ -z "$VERSION" ] || [ "$VERSION" == "null" ]; then
  error_exit "Failed to retrieve the version from package.json."
fi

# --------------------------------------------
# Check if sentry-cli is installed
# --------------------------------------------
if ! command -v sentry-cli >/dev/null 2>&1; then
  error_exit "sentry-cli is not installed. Please install sentry-cli before running this script."
fi

# --------------------------------------------
# Optional: Define Sentry organization and project
# --------------------------------------------
# You can set these as environment variables or modify the script to accept them as arguments
# SENTRY_ORG="your-sentry-organization"
# SENTRY_PROJECT="your-sentry-project"

# --------------------------------------------
# Check if a release with the specified version already exists in Sentry
# --------------------------------------------
if sentry-cli releases list | grep -q "$VERSION"; then
  success_message "Release with version $VERSION already exists."
  exit 0
else
  info_message "Creating a new release for version $VERSION...${NC}"
  
  # --------------------------------------------
  # Create a new release in Sentry
  # -------------------------------------------
  sentry-cli releases new "$VERSION" || error_exit "Failed to create the release in Sentry."

  # --------------------------------------------
  # Associate commits with the release
  # --------------------------------------------
  sentry-cli releases set-commits --auto "$VERSION" || error_exit "Failed to set commits for the release."

  # --------------------------------------------
  # Finalize the release in Sentry
  # --------------------------------------------
  sentry-cli releases finalize "$VERSION" || error_exit "Failed to finalize the release."

  success_message "Release $VERSION created and finalized successfully."
fi
