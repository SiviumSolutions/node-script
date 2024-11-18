#!/bin/bash

# ============================================
# SIVIUM SCRIPTS - Server Environment Setup
# ============================================
# This script automates the setup and deployment
# of your server environment with various options
# for customization.
# ============================================

# --------------------------------------------
# ANSI Color Codes for Styled Output
# --------------------------------------------
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
LIGHTBLUE='\033[1;34m'
NC='\033[0m' # No Color

# --------------------------------------------
# Initialize Variables with Default Values
# --------------------------------------------
PORT=""                        # Required
AUTO_UPDATE="1"                # Default: 1 (enabled)
TARGET_BRANCH="main"           # Default: main
PRJ_TYPE=""                    # Required
PKG_MANAGER=""                 # Required
BUILD_BEFORE_START="1"         # Default: 1 (enabled)
REINSTALL_MODULES="0"          # Default: 0 (disabled)
FORCE_REBUILD="0"              # Default: 0 (disabled)

LOCK_FILES=("package-lock.json" "yarn.lock" "pnpm-lock.yaml" "bun.lockb")
SKIP_UPDATE=false

# --------------------------------------------
# Function: Display Usage Instructions
# --------------------------------------------
usage() {
  echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Usage:${NC} $0 --port <port> --prjtype <backend|frontend|api|microservice> --pm <bun|pnpm|yarn|npm> [options]"
  echo -e ""
  echo -e "Required arguments:"
  echo -e "  --port <port>                          Set the application port (1-65535)."
  echo -e "  --prjtype <type>                       Project type: backend, frontend, api, or microservice."
  echo -e "  --pm <package_manager>                 Package manager: bun, pnpm, yarn, or npm."
  echo -e ""
  echo -e "Optional arguments (default values shown in parentheses):"
  echo -e "  --autoupdate <1|0>                     Enable auto-update (1)."
  echo -e "  --branch <branch_name>                 Target Git branch (main)."
  echo -e "  --build-before-start <1|0>             Enable build before starting (1)."
  echo -e "  --reinstall-modules <1|0>              Reinstall node modules on startup (0)."
  echo -e "  --force-rebuild <1|0>                  Force the application to rebuild on startup (0)."
  echo -e "  --help, -h                             Display this help message."
  echo -e ""
  echo -e "Example:"
  echo -e "  $0 --port 3000 --prjtype frontend --pm yarn --autoupdate 1 --branch develop"
  exit 1
}

# --------------------------------------------
# Function: Display Error Messages
# --------------------------------------------
error() {
  echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Error:${NC} $1"
  usage
}

# --------------------------------------------
# Parse Command-Line Arguments
# --------------------------------------------
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

# --------------------------------------------
# Validate Required Arguments
# --------------------------------------------
if [[ -z "$PORT" ]]; then
  error "--port argument is required."
fi

if [[ -z "$PRJ_TYPE" ]]; then
  error "--prjtype argument is required."
fi

if [[ -z "$PKG_MANAGER" ]]; then
  error "--pm (package manager) argument is required."
fi

# --------------------------------------------
# Validate PORT Argument (1-65535)
# --------------------------------------------
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  error "--port must be a number between 1 and 65535."
fi

# --------------------------------------------
# Validate AUTO_UPDATE Argument (1 or 0)
# --------------------------------------------
if [[ "$AUTO_UPDATE" != "1" && "$AUTO_UPDATE" != "0" ]]; then
  error "--autoupdate must be '1' or '0'."
fi

# --------------------------------------------
# Validate TARGET_BRANCH Argument (Git Branch Naming)
# --------------------------------------------
if ! [[ "$TARGET_BRANCH" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
  error "--branch contains invalid characters."
fi

# --------------------------------------------
# Validate PRJ_TYPE Argument
# --------------------------------------------
ALLOWED_PRJ_TYPES=("backend" "frontend" "api" "microservice")
if [[ ! " ${ALLOWED_PRJ_TYPES[@]} " =~ " $PRJ_TYPE " ]]; then
  error "--prjtype must be one of: ${ALLOWED_PRJ_TYPES[*]}"
fi

# --------------------------------------------
# Validate PKG_MANAGER Argument
# --------------------------------------------
ALLOWED_PKG_MANAGERS=("bun" "pnpm" "yarn" "npm")
if [[ ! " ${ALLOWED_PKG_MANAGERS[@]} " =~ " $PKG_MANAGER " ]]; then
  error "--pm must be one of: ${ALLOWED_PKG_MANAGERS[*]}"
fi

# --------------------------------------------
# Validate Optional Boolean Arguments (1 or 0)
# --------------------------------------------
validate_boolean_option() {
  local var_value="$1"
  local var_name="$2"
  if [[ "$var_value" != "1" && "$var_value" != "0" ]]; then
    error "--$var_name must be '1' or '0'."
  fi
}

validate_boolean_option "$BUILD_BEFORE_START" "build-before-start"
validate_boolean_option "$REINSTALL_MODULES" "reinstall-modules"
validate_boolean_option "$FORCE_REBUILD" "force-rebuild"

# --------------------------------------------
# Display Initialization Message
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Installing server environment...${NC}"

# --------------------------------------------
# Export Environment Variables
# --------------------------------------------
export PORT="$PORT"
export CLUSTER_PORT=$((PORT + 1))

# --------------------------------------------
# Determine Command Prefix Based on Package Manager
# --------------------------------------------
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

# --------------------------------------------
# Display Configuration Summary
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} Configuration:${NC}"
echo -e "${YELLOW}  PORT: $PORT${NC}"
echo -e "${YELLOW}  CLUSTER_PORT: $CLUSTER_PORT${NC}"
echo -e "${YELLOW}  AUTO_UPDATE: $AUTO_UPDATE${NC}"
echo -e "${YELLOW}  BUILD_BEFORE_START: $BUILD_BEFORE_START${NC}"
echo -e "${YELLOW}  REINSTALL_MODULES: $REINSTALL_MODULES${NC}"
echo -e "${YELLOW}  FORCE_REBUILD: $FORCE_REBUILD${NC}"
echo -e "${YELLOW}  TARGET_BRANCH: $TARGET_BRANCH${NC}"
echo -e "${YELLOW}  PRJ_TYPE: $PRJ_TYPE${NC}"
echo -e "${YELLOW}  PACKAGE_MANAGER: $PKG_MANAGER${NC}"
echo ""

# --------------------------------------------
# Display Current Git Branch and Commit
# --------------------------------------------
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null)

if [[ -n "$CURRENT_BRANCH" && -n "$CURRENT_COMMIT" ]]; then
  echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} Current branch: ${YELLOW}$CURRENT_BRANCH${NC}"
  echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} Current commit: ${YELLOW}$CURRENT_COMMIT${NC}"
else
  echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Error: Not a Git repository or Git is not installed.${NC}"
  exit 1
fi

# --------------------------------------------
# Function: Check if Directory Exists
# --------------------------------------------
directory_exists() {
  [ -d "$1" ]
}

# --------------------------------------------
# Switch to Target Branch if Different
# --------------------------------------------
if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
  if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS |${YELLOW} Switching to branch $TARGET_BRANCH...${NC}"
    git checkout "$TARGET_BRANCH" || { echo -e "${RED}Failed to checkout branch $TARGET_BRANCH.${NC}"; exit 1; }
    echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Switch complete, verifying current branch...${NC}"
    SW_CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    SW_CURRENT_COMMIT=$(git rev-parse HEAD)
    echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} Current branch: ${YELLOW}$SW_CURRENT_BRANCH${NC}"
    echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} Current commit: ${YELLOW}$SW_CURRENT_COMMIT${NC}"
  fi
else
  echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Branch '$TARGET_BRANCH' does not exist. Staying on '$CURRENT_BRANCH'.${NC}"
fi

# --------------------------------------------
# Function: Check if Git Repository is Up to Date
# --------------------------------------------
is_git_up_to_date() {
  git remote update &>/dev/null
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse @{u} 2>/dev/null)
  BASE=$(git merge-base @ @{u})

  if [ "$LOCAL" = "$REMOTE" ]; then
    return 0    # Up to date
  elif [ "$LOCAL" = "$BASE" ]; then
    return 1    # Needs to pull
  else
    return 2    # Diverged
  fi
}

# --------------------------------------------
# Set File Permissions for Auxiliary Scripts
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${YELLOW} Setting file permissions...${NC}"
chmod +x ./check.sh || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to set execute permission on check.sh.${NC}"; exit 1; }
chmod +x ./sentry.sh || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to set execute permission on sentry.sh.${NC}"; exit 1; }
chmod +x ./nginx.sh || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to set execute permission on nginx.sh.${NC}"; exit 1; }

# --------------------------------------------
# Check Project Dependencies
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Checking project dependencies...${NC}"
./check.sh --silent || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Dependency check failed.${NC}"; exit 1; }

# --------------------------------------------
# Git Actions: Reset and Pull if Needed
# --------------------------------------------
if [[ -d .git && "$AUTO_UPDATE" -eq 1 ]]; then
  if is_git_up_to_date; then
    echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} Project core is already up to date.${NC}"
    echo -e "${ORANGE}SIVIUM SCRIPTS |${YELLOW} Skipping update.${NC}"
    SKIP_UPDATE=true
  else
    echo -e "${ORANGE}SIVIUM SCRIPTS |${YELLOW} Updating project core from repository...${NC}"
    git reset --hard || { echo -e "${RED}Git reset failed.${NC}"; exit 1; }
    git pull || { echo -e "${RED}Git pull failed.${NC}"; exit 1; }
    UPDATED_COMMIT=$(git rev-parse HEAD)
    echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} Updated commit: ${YELLOW}$UPDATED_COMMIT${NC}"
    # --------------------------------------------
    # Check for Changes in Lock Files
    # --------------------------------------------
    echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Checking for changes in lock files...${NC}"
    for lock_file in "${LOCK_FILES[@]}"; do
      if [ -f "$lock_file" ]; then
        LOCAL_LOCK_HASH=$(git rev-parse HEAD:"$lock_file" 2>/dev/null || echo "")
        REMOTE_LOCK_HASH=$(git rev-parse origin/"$CURRENT_BRANCH":"$lock_file" 2>/dev/null || echo "")
        if [ "$LOCAL_LOCK_HASH" != "$REMOTE_LOCK_HASH" ]; then
          CHANGED_LOCK_FILES+="$lock_file"$'\n'
        fi
      fi
    done

    # --------------------------------------------
    # Check for Changes in TypeScript Files as per tsconfig.json
    # --------------------------------------------
    echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Checking for changes in TypeScript files...${NC}"
    if [ -f "tsconfig.json" ]; then
      INCLUDE_PATTERNS=$(jq -r '.include[]' tsconfig.json)
      EXCLUDE_PATTERNS=$(jq -r '.exclude[]' tsconfig.json)

      # Prepare git diff command between local and remote
      GIT_DIFF_CMD="git diff --name-only origin/$CURRENT_BRANCH...HEAD"

      for pattern in $INCLUDE_PATTERNS; do
        GIT_DIFF_CMD+=" -- '$pattern'"
      done

      for pattern in $EXCLUDE_PATTERNS; do
        GIT_DIFF_CMD+=" -- ':(exclude)$pattern'"
      done

      CHANGED_TS_FILES=$(eval "$GIT_DIFF_CMD")
    else
      echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Error: tsconfig.json not found.${NC}"
    fi
  fi
fi

# --------------------------------------------
# Load Environment Variables from .env
# --------------------------------------------
if [ -f ".env" ]; then
  echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} .env file found. Loading environment variables...${NC}"
  export $(grep -v '^#' .env | xargs) || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to load environment variables from .env.${NC}"; exit 1; }
else
  echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} .env file not found. Proceeding without environment variables from .env.${NC}"
  exit 1
fi

# --------------------------------------------
# Handle Node Modules Installation and Updates
# --------------------------------------------
if [[ "$SKIP_UPDATE" = false || "$REINSTALL_MODULES" == "1" ]]; then
  # Reinstall node modules if requested
  if [[ "$REINSTALL_MODULES" == "1" ]]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Reinstalling node modules...${NC}"
    rm -rf node_modules || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to remove node_modules.${NC}"; exit 1; }
  fi

  # Determine Lock File Based on Package Manager
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

  # Install Dependencies if Lock File Does Not Exist
  if [ ! -f "$LOCK_FILE" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS |${YELLOW} $LOCK_FILE does not exist. Creating...${NC}"
    $PKG_MANAGER install 2> >(grep -v warning >&2) | while IFS= read -r line; do
      echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
    done || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to install dependencies.${NC}"; exit 1; }
  fi

  # Handle Changes in Lock Files
  if [ -n "$CHANGED_LOCK_FILES" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS |${YELLOW} Changes detected in lock files between local and remote:${NC}"
    echo "$CHANGED_LOCK_FILES"
    echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Installing updated packages...${NC}"
    echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Preparing dependencies...${NC}"
    case "$PKG_MANAGER" in
      npm)
        $PKG_MANAGER ci 2> >(grep -v warning >&2) | while IFS= read -r line; do
          echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
        done
        ;;
      pnpm)
        $PKG_MANAGER install --frozen-lockfile 2> >(grep -v warning >&2) | while IFS= read -r line; do
          echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
        done
        ;;
      yarn)
        $PKG_MANAGER install --frozen-lockfile 2> >(grep -v warning >&2) | while IFS= read -r line; do
          echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
        done
        ;;
      bun)
        $PKG_MANAGER install 2> >(grep -v warning >&2) | while IFS= read -r line; do
          echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
        done
        ;;
    esac
  else
    echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} No changes detected in lock files between local and remote.${NC}"
  fi

  # --------------------------------------------
  # Handle Build Before Start
  # --------------------------------------------
  if [[ "$BUILD_BEFORE_START" == "1" && "$FORCE_REBUILD" != "1" ]]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Checking current build...${NC}"

    if [ -n "$CHANGED_TS_FILES" ]; then
      echo -e "${ORANGE}SIVIUM SCRIPTS |${YELLOW} Changes detected in TypeScript files as per tsconfig.json:${NC}"
      echo "$CHANGED_TS_FILES"
      echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Rebuilding application...${NC}"
      NODE_ENV=production $CMD_PREFIX build 2> >(grep -v warning >&2) | while IFS= read -r line; do
        echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
      done || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Build failed.${NC}"; exit 1; }
    else
      echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} No changes detected in TypeScript files as per tsconfig.json.${NC}"
    fi
  else
    if [[ "$FORCE_REBUILD" != "1" ]]; then
      echo -e "${ORANGE}SIVIUM SCRIPTS |${YELLOW} Auto build before start is disabled.${NC}"
    fi
  fi
fi

# --------------------------------------------
# Handle Force Rebuild
# --------------------------------------------
if [[ "$FORCE_REBUILD" == "1" ]]; then
  echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Force building project from source...${NC}"
  NODE_ENV=production $CMD_PREFIX build 2> >(grep -v warning >&2) | while IFS= read -r line; do
    echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
  done || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Force build failed.${NC}"; exit 1; }
fi

# --------------------------------------------
# Ensure Node Modules are Installed
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Checking node modules...${NC}"
if ! directory_exists "node_modules"; then
  echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Installing node modules...${NC}"
  $PKG_MANAGER install 2> >(grep -v warning >&2) | while IFS= read -r line; do
    echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
  done || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to install node modules.${NC}"; exit 1; }
fi

# --------------------------------------------
# Handle Project Type Specific Builds
# --------------------------------------------
if [[ "$BUILD_BEFORE_START" == "1" ]]; then
  echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Checking build artifacts...${NC}"
  case "$PRJ_TYPE" in
    backend)
      if ! directory_exists "dist"; then
        echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Building backend from source...${NC}"
        NODE_ENV=production $CMD_PREFIX build > /dev/null 2>&1 || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Backend build failed.${NC}"; exit 1; }
      fi
      ;;
    frontend)
      if ! directory_exists ".next"; then
        echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Building frontend from source...${NC}"
        NODE_ENV=production $CMD_PREFIX build > /dev/null 2>&1 || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Frontend build failed.${NC}"; exit 1; }
      fi
      ;;
    api|microservice)
      # Add specific build steps if needed
      echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} No specific build steps for project type '${PRJ_TYPE}'.${NC}"
      ;;
    *)
      echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Unknown project type: $PRJ_TYPE${NC}"
      ;;
  esac
fi

# --------------------------------------------
# Setup Sentry Release
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Checking Sentry release...${NC}"
./sentry.sh || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Sentry setup failed.${NC}"; exit 1; }

# --------------------------------------------
# Setup Nginx
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Setting up Nginx...${NC}"
./nginx.sh || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Nginx setup failed.${NC}"; exit 1; }

# --------------------------------------------
# Start Production Server
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Starting production server...${NC}"
# Run production build
NODE_ENV=production $CMD_PREFIX production > /dev/null 2>&1 || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to start production server.${NC}"; exit 1; }

# --------------------------------------------
# Monitor with PM2
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${PURPLE} Starting log service...${NC}"
echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} Process started. Monitoring with PM2.${NC}"
$CMD_PREFIX monit || { echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to start PM2 monitoring.${NC}"; exit 1; }

# --------------------------------------------
# Script Completion
# --------------------------------------------
echo -e "${ORANGE}SIVIUM SCRIPTS |${GREEN} Deployment completed successfully.${NC}"
