#!/bin/bash

# ANSI color codes
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Перевірка, що скрипт працює на Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  echo -e "${RED}Error: This script only supports Linux.${NC}"
  exit 1
fi

# Перевірка наявності package.json
if [ ! -f package.json ]; then
  echo -e "${RED}Error: package.json file not found!${NC}"
  exit 1
fi

# Функція для отримання версії з package.json
get_version() {
  # Для Linux використовуємо Bash-команди
  VERSION=$(grep '"version"' package.json | sed 's/.*"version": "\(.*\)",/\1/')
  echo "$VERSION"
}

# Отримання версії з package.json
VERSION=$(get_version)

# Перевірка, чи версія отримана
if [ -z "$VERSION" ]; then
  echo -e "${RED}Failed to retrieve the version from package.json${NC}"
  exit 1
fi

# Перевірка наявності випуску з цією версією
if sentry-cli releases list | grep -q "$VERSION"; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Release with version $VERSION already exists.${NC}"
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Creating a new release for version $VERSION...${NC}"

  # Створення випуску в Sentry
  sentry-cli releases new "$VERSION"
  
  # Встановлення комітів для випуску
  sentry-cli releases set-commits "$VERSION" --auto
  
  # Завершення випуску
  sentry-cli releases finalize "$VERSION"
  
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Release $VERSION created and finalized successfully.${NC}"
fi