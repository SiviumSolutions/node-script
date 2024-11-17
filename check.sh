#!/bin/bash

# ANSI color codes
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Check if the script is run with --silent flag
SILENT_MODE=false
if [[ "$1" == "--silent" ]]; then
  SILENT_MODE=true
fi

# Check if .pm2 folder does not exist, then install pm2
if ! command -v wrangler &> /dev/null; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Installing wrangler...${NC}"
  yarn global add wrangler
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}wrangler installed successfully.${NC}"
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}wrangler is already installed.${NC}"
fi

if ! command -v /usr/local/bin/acme.sh/acme.sh &> /dev/null; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Acme sh not found...${NC}"
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}acme is already installed.${NC}"
fi

if ! command -v pm2 &> /dev/null; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Installing pm2...${NC}"
  yarn global add pm2
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}pm2 installed successfully.${NC}"
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}pm2 is already installed.${NC}"
fi

# Check if .bun folder does not exist, then install bun
if ! command -v bun &> /dev/null; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Installing bun...${NC}"
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="$HOME/.bun" 
  export PATH="$BUN_INSTALL/bin:$PATH" 
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}bun installed successfully.${NC}"
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}bun is already installed.${NC}"
fi

# Check if sentry-cli is installed
if ! command -v sentry-cli &> /dev/null; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Installing sentry-cli...${NC}"
  yarn global add @sentry/cli
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}sentry-cli installed successfully.${NC}"
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}sentry-cli is already installed.${NC}"
fi

# If --silent flag is passed, terminate without any further interaction
if $SILENT_MODE; then
  exit 0
fi

# Prevent terminal from closing after the script finishes if not in silent mode
echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}All installations are complete. Press any key to exit...${NC}"
read -n 1 -s