#!/bin/bash

# ANSI color codes
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if a port argument is provided
if [ -z "$1" ]; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}No port argument provided. Usage: $0 <port> <auto_update> <branch>${NC}"
  exit 1
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Installing server environment...${NC}"
  export PORT=$1
  export CLUSTER_PORT=$(($1 + 1))
fi

# Check for auto-update and branch arguments
AUTO_UPDATE=$2
TARGET_BRANCH=$3

# Display current branch and commit
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURRENT_COMMIT=$(git rev-parse HEAD)
echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Current branch: ${YELLOW}$CURRENT_BRANCH${NC}"
echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Current commit: ${YELLOW}$CURRENT_COMMIT${NC}"

# Define directory_exists function
directory_exists() {
  [ -d "$1" ]
}

# Check if the target branch exists before switching
if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
  if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}Switching to branch $TARGET_BRANCH...${NC}"
    git checkout "$TARGET_BRANCH"
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Switch complete, checking current...${NC}"
    SW_CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    SW_CURRENT_COMMIT=$(git rev-parse HEAD)
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Current branch: ${YELLOW}$SW_CURRENT_BRANCH${NC}"
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Current commit: ${YELLOW}$SW_CURRENT_COMMIT${NC}"
  fi
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Branch $TARGET_BRANCH does not exist. Staying on $CURRENT_BRANCH.${NC}"
fi

# Function to check if the Git repository is up to date
is_git_up_to_date() {
  git remote update &>/dev/null
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse @{u})
  BASE=$(git merge-base @ @{u})

  if [ $LOCAL = $REMOTE ]; then
    return 0
  elif [ $LOCAL = $BASE ]; then
    return 1
  else
    return 2
  fi
}

# Git actions: reset and pull if the directory is a git repository and auto-update is enabled
if [[ -d .git && "$AUTO_UPDATE" -eq 1 ]]; then
  if is_git_up_to_date; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Project core is already up to date.${NC}"
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}Skipping update.${NC}"
    SKIP_UPDATE=true
  else
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}Updating project core from repo...${NC}"
    git reset --hard
    git pull
    UPDATED_COMMIT=$(git rev-parse HEAD)
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Updated commit: ${YELLOW}$UPDATED_COMMIT${NC}"
  fi
fi

echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}Install file permissions...${NC}"
chmod +x ./check.sh 
chmod +x ./sentry.sh

echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}Check project deps...${NC}"
./check.sh --silent
# Check if .env file exists

if [ -f ".env" ]; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}.env file found. Loading environment variables...${NC}"
  export $(grep -v '^#' .env | xargs)
else
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}.env file not found. Proceeding without environment variables from .env.${NC}"
  exit 1
fi
# Run subsequent steps if not skipped
if [[ -z "$SKIP_UPDATE" ]]; then
  # Check if yarn.lock does not exist, then create it
  if [ ! -f "yarn.lock" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}yarn.lock does not exist. Creating...${NC}"
    yarn install 2> >(grep -v warning 1>&2)
  fi

  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Preparing dependencies...${NC}"
  yarn --frozen-lockfile 2> >(grep -v warning 1>&2)

  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Building files...${NC}"
  NODE_ENV=production yarn build
fi

echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Check modules...${NC}"
if ! directory_exists "$HOME/node_modules"; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Install node modules...${NC}"
  yarn --frozen-lockfile 2> >(grep -v warning 1>&2)
fi

echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Check files...${NC}"
if ! directory_exists "$HOME/dist"; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Building from src...${NC}"
  NODE_ENV=production yarn build > /dev/null 2>&1
fi

echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Check sentry release...${NC}"
./sentry.sh

echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Starting stapi server...${NC}"
# Run production build
yarn production > /dev/null 2>&1

# Monitor with pm2
echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Monitoring with PM2...${NC}"
echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Process started. Monitoring with PM2.${NC}"
yarn monit
