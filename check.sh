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
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: Wrangler not found...${NC}"
  exit 0
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Wrangler is already installed.${NC}"
fi

if command -v jq >/dev/null 2>&1; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: Jq not found...${NC}"
  exit 0
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Jq is already installed.${NC}"
fi


if ! command -v .acme/acme.sh &> /dev/null; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: Acme sh not found...${NC}"
  exit 0
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Acme is already installed.${NC}"
fi

if ! command -v pm2 &> /dev/null; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: Pm2 sh not found...${NC}"
  exit 0
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Pm2 is already installed.${NC}"
fi

# Check if .bun folder does not exist, then install bun
if ! command -v bun &> /dev/null; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: Bun not found...${NC}"
  exit 0
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Bun is already installed.${NC}"
fi

# Check if sentry-cli is installed
if ! command -v sentry-cli &> /dev/null; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: Sentry-cli not found...${NC}"
  exit 0
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Sentry-cli is already installed.${NC}"
fi

# If --silent flag is passed, terminate without any further interaction
if $SILENT_MODE; then
  exit 0
fi

# Prevent terminal from closing after the script finishes if not in silent mode
echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}All installations are complete. Press any key to exit...${NC}"
read -n 1 -s