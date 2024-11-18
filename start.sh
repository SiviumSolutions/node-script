#!/bin/bash

# ANSI color codes
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
LIGHTBLUE='\033[1;34m'
NC='\033[0m' # No Color

# Initialize variables
PORT=""
AUTO_UPDATE=""
TARGET_BRANCH=""
PRJ_TYPE=""
PKG_MANAGER=""
BUILD_BEFORE_START=""
REINSTALL_MODULES=""
FORCE_REBUILD=""

# Function to display usage instructions
usage() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Usage: $0 --port <port> --autoupdate <1|0> --branch <branch_name> --prjtype <backend|frontend|api|microservice> --pm <bun|pnpm|yarn|npm> [options]${NC}"
  echo -e "Additional options:"
  echo -e "  --build-before-start <1|0> Enable build commands before starting your app."
  echo -e "  --reinstall-modules <1|0>  Reinstall node modules on startup."
  echo -e "  --force-rebuild <1|0>      Force the application to rebuild on startup."
  exit 1
}

# Function to display error messages
error() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: $1${NC}"
  usage
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    --port)
      PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --autoupdate)
      AUTO_UPDATE="$2"
      shift
      shift
      ;;
    --branch)
      TARGET_BRANCH="$2"
      shift
      shift
      ;;
    --prjtype)
      PRJ_TYPE="$2"
      shift
      shift
      ;;
    --pm)
      PKG_MANAGER="$2"
      shift
      shift
      ;;
    --build-before-start)
      BUILD_BEFORE_START="$2"
      shift
      shift
      ;;
    --reinstall-modules)
      REINSTALL_MODULES="$2"
      shift
      shift
      ;;
    --force-rebuild)
      FORCE_REBUILD="$2"
      shift
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done

# Check for required arguments
if [[ -z "$PORT" ]]; then
  error "--port argument is required."
fi

if [[ -z "$AUTO_UPDATE" ]]; then
  error "--autoupdate argument is required."
fi

if [[ -z "$TARGET_BRANCH" ]]; then
  error "--branch argument is required."
fi

if [[ -z "$PRJ_TYPE" ]]; then
  error "--prjtype argument is required."
fi

if [[ -z "$PKG_MANAGER" ]]; then
  error "--pm (package manager) argument is required."
fi

# Validate PORT argument (must be a number between 1 and 65535)
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  error "--port must be a number between 1 and 65535."
fi

# Validate AUTO_UPDATE argument (must be 1 or 0)
if [[ "$AUTO_UPDATE" != "1" && "$AUTO_UPDATE" != "0" ]]; then
  error "--autoupdate must be '1' or '0'."
fi

# Validate TARGET_BRANCH argument (allowed characters in Git branch names)
if ! [[ "$TARGET_BRANCH" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
  error "--branch contains invalid characters."
fi

# Validate PRJ_TYPE argument (allowed types)
ALLOWED_PRJ_TYPES=("backend" "frontend" "api" "microservice")
if [[ ! " ${ALLOWED_PRJ_TYPES[@]} " =~ " $PRJ_TYPE " ]]; then
  error "--prjtype must be one of: ${ALLOWED_PRJ_TYPES[*]}"
fi

# Validate PKG_MANAGER argument (must be bun, pnpm, yarn, or npm)
ALLOWED_PKG_MANAGERS=("bun" "pnpm" "yarn" "npm")
if [[ ! " ${ALLOWED_PKG_MANAGERS[@]} " =~ " $PKG_MANAGER " ]]; then
  error "--pm must be one of: ${ALLOWED_PKG_MANAGERS[*]}"
fi

# Validate BUILD_BEFORE_START (must be 1 or 0)
if [[ "$BUILD_BEFORE_START" != "1" && "$BUILD_BEFORE_START" != "0" ]]; then
  error "--build-before-start must be '1' or '0'."
fi

# Validate REINSTALL_MODULES (must be 1 or 0)
if [[ "$REINSTALL_MODULES" != "1" && "$REINSTALL_MODULES" != "0" ]]; then
  error "--reinstall-modules must be '1' or '0'."
fi

# Validate FORCE_REBUILD (must be 1 or 0)
if [[ "$FORCE_REBUILD" != "1" && "$FORCE_REBUILD" != "0" ]]; then
  error "--force-rebuild must be '1' or '0'."
fi

echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Installing server environment...${NC}"
export PORT="$PORT"
export CLUSTER_PORT=$((PORT + 1))

# Determine the command prefix based on the package manager
case "$PKG_MANAGER" in
  npm|pnpm)
    CMD_PREFIX="$PKG_MANAGER run"
    ;;
  yarn|bun)
    CMD_PREFIX="$PKG_MANAGER"
    ;;
  *)
    error "Unsupported package manager: $PKG_MANAGER"
    ;;
esac

# Display the configuration
echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Configuration:${NC}"
echo -e "${YELLOW}  PORT: $PORT${NC}"
echo -e "${YELLOW}  CLUSTER_PORT: $CLUSTER_PORT${NC}"
echo -e "${YELLOW}  AUTO_UPDATE: $AUTO_UPDATE${NC}"
echo -e "${YELLOW}  BUILD_BEFORE_START: $BUILD_BEFORE_START${NC}"
echo -e "${YELLOW}  REINSTALL_MODULES: $REINSTALL_MODULES${NC}"
echo -e "${YELLOW}  FORCE_REBUILD: $FORCE_REBUILD${NC}"
echo -e "${YELLOW}  TARGET_BRANCH: $TARGET_BRANCH${NC}"
echo -e "${YELLOW}  PRJ_TYPE: $PRJ_TYPE${NC}"
echo -e "${YELLOW}  PACKAGE_MANAGER: $PKG_MANAGER${NC}"


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

if [ -f "package.json" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Found package.json. Checking caniuse-lite...${NC}"
    if npx browserslist@latest --update-db | grep -q "caniuse-lite is outdated"; then
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}caniuse-lite is outdated. Updating...${NC}"
        npx browserslist@latest --update-db > /dev/null 2>&1
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}caniuse-lite has been updated.${NC}"
    else
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}caniuse-lite is up to date.${NC}"
    fi
else
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}package.json not found in the current directory. Cannot update caniuse-lite.${NC}"
fi

# Function to check if the Git repository is up to date
is_git_up_to_date() {
  git remote update &>/dev/null
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse @{u})
  BASE=$(git merge-base @ @{u})

  if [ "$LOCAL" = "$REMOTE" ]; then
    return 0
  elif [ "$LOCAL" = "$BASE" ]; then
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
chmod +x ./nginx.sh

echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Check project dependencies...${NC}"
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
if [[ -z "$SKIP_UPDATE" || "$REINSTALL_MODULES" == "1" ]]; then
  # Check if lock file does not exist, then create it
  if [[ "$REINSTALL_MODULES" == "1" ]]; then
      echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Reinstalling node modules...${NC}"
      rm -rf node_modules
  fi
  LOCK_FILE=""
  case "$PKG_MANAGER" in
    yarn)
      LOCK_FILE="yarn.lock"
      ;;
    npm)
      LOCK_FILE="package-lock.json"
      ;;
    pnpm)
      LOCK_FILE="pnpm-lock.yaml"
      ;;
    bun)
      LOCK_FILE="bun.lockb"
      ;;
  esac

  if [ ! -f "$LOCK_FILE" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}$LOCK_FILE does not exist. Creating...${NC}"
    $PKG_MANAGER install 2> >(grep -v warning 1>&2) | while IFS= read -r line; do
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${LIGHTBLUE}${line}${NC}"
    done
  fi

  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Preparing dependencies...${NC}"
  case "$PKG_MANAGER" in
    npm)
      $PKG_MANAGER ci 2> >(grep -v warning 1>&2) | while IFS= read -r line; do
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${LIGHTBLUE}${line}${NC}"
    done
      ;;
    pnpm)
      $PKG_MANAGER install --frozen-lockfile 2> >(grep -v warning 1>&2) | while IFS= read -r line; do
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${LIGHTBLUE}${line}${NC}"
    done
      ;;
    yarn)
      $PKG_MANAGER --frozen-lockfile 2> >(grep -v warning 1>&2) | while IFS= read -r line; do
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${LIGHTBLUE}${line}${NC}"
    done
      ;;
    bun)
      $PKG_MANAGER install 2> >(grep -v warning 1>&2) | while IFS= read -r line; do
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${LIGHTBLUE}${line}${NC}"
    done
      ;;
  esac

  if [[ "$BUILD_BEFORE_START" == "1" && "$FORCE_REBUILD" != "1" ]]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Building project...${NC}"
    NODE_ENV=production $CMD_PREFIX build 2> >(grep -v warning 1>&2) | while IFS= read -r line; do
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${LIGHTBLUE}${line}${NC}"
    done
  else
    if [[  "$FORCE_REBUILD" != "1" ]]; then
      echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Auto build before start is dissabled...${NC}"
    fi
  fi
fi

if [[ "$FORCE_REBUILD" == "1" ]]; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Force building project from src...${NC}"
  NODE_ENV=production $CMD_PREFIX build 2> >(grep -v warning 1>&2) | while IFS= read -r line; do
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${LIGHTBLUE}${line}${NC}"
    done
fi
echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Check modules...${NC}"
if ! directory_exists "node_modules"; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Installing node modules...${NC}"
  $PKG_MANAGER install 2> >(grep -v warning 1>&2) | while IFS= read -r line; do
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${LIGHTBLUE}${line}${NC}"
    done
fi
if [[ "$BUILD_BEFORE_START" == "1" ]]; then
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Check files...${NC}"
  if [ "$PRJ_TYPE" = "backend" ]; then
    if ! directory_exists "dist"; then
      echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Building backend from src...${NC}"
      NODE_ENV=production $CMD_PREFIX build > /dev/null 2>&1
    fi
  elif [ "$PRJ_TYPE" = "frontend" ]; then
    if ! directory_exists ".next"; then
      echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Building frontend from src...${NC}"
      NODE_ENV=production $CMD_PREFIX build > /dev/null 2>&1
    fi
  fi
fi


echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Check Sentry release...${NC}"
./sentry.sh

echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Setup nginx...${NC}"
./nginx.sh

echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Starting production server...${NC}"
# Run production build
NODE_ENV=production $CMD_PREFIX production > /dev/null 2>&1

# Monitor with pm2
echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}Starting log service...${NC}"
echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Process started. Monitoring with PM2.${NC}"
$CMD_PREFIX monit
