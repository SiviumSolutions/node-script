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
GREY='\033[1;30m'      # Added Grey Color
BOLD='\033[1m'         # Bold Text
UNDERLINE='\033[4m'    # Underlined Text
NC='\033[0m' # No Color

# --------------------------------------------
# Initialize Variables with Default Values
# --------------------------------------------
SERVER_PORT=""                 # Required
AUTO_UPDATE="1"                # Default: 1 (enabled)
BRANCH="main"           # Default: main
GIT_REPO_ADDRESS=""            # Default: empty -> skip Git steps if empty
PRJ_TYPE="microservice"        # Default: (microservice)
PKG_MANAGER="pnpm"             # Default: (pnpm)
BUILD_BEFORE_START="1"         # Default: 1 (enabled)
REINSTALL_MODULES="0"          # Default: 0 (disabled)
FORCE_REBUILD="0"              # Default: 0 (disabled)
ENABLE_SENTRY="0"              # Default: 0 (disabled)
ENABLE_NGINX="0"               # Default: 0 (disabled)
ENABLE_LOG_SERVICE="0"        # Default: 0 (disabled)
MODE="production"              # Default: production
CUSTOM_CMD_PROD="production"   # Default: production
CUSTOM_CMD_DEV="dev"           # Default: development

LOCK_FILES=("package-lock.json" "yarn.lock" "pnpm-lock.yaml" "bun.lockb")
SKIP_UPDATE=true
BUILD_REQUIRED=false



# --------------------------------------------
# Function: Display Usage Instructions
# --------------------------------------------
usage() {
  echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Usage:${NC} $0 --port <port> [options]"
  echo -e ""
  echo -e "Required arguments:"
  echo -e "  --port <port>                          Set the application port (1-65535)."
  echo -e ""
  echo -e "Optional arguments (default values shown in parentheses):"
  echo -e "  --prjtype <type>                       Project type: backend, frontend, api, or microservice."
  echo -e "  --pm <package_manager>                 Package manager: bun, pnpm, yarn, or npm."
  echo -e "  --autoupdate <1|0>                     Enable auto-update (1)."
  echo -e "  --branch <branch_name>                 Target Git branch (main)."
  echo -e "  --build-before-start <1|0>             Enable build before starting (1)."
  echo -e "  --reinstall-modules <1|0>              Reinstall node modules on startup (0)."
  echo -e "  --force-rebuild <1|0>                  Force the application to rebuild on startup (0)."
  echo -e "  --enable-sentry <1|0>                  Enable sentry plugin (0)."
  echo -e "  --enable-nginx <1|0>                   Enable Nginx steps entirely (0)."
  echo -e "  --mode <production|development>        Application mode to run (production)."
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
# Function: Display a warn message
# --------------------------------------------
warn_message() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}$1${NC}"
}
# --------------------------------------------
# Function: Display a debug message
# --------------------------------------------

debug_message() {
  echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREY}$1${NC}"
}
# --------------------------------------------
# Function: Validate Boolean Options (1 or 0)
# --------------------------------------------
validate_boolean_option() {
  local var_value="$1"
  local var_name="$2"
  if [[ "$var_value" != "1" && "$var_value" != "0" ]]; then
    error "--$var_name must be '1' or '0'."
  fi
}

# --------------------------------------------
# Function: Check if Directory Exists
# --------------------------------------------
directory_exists() {
  [ -d "$1" ]
}

# --------------------------------------------
# Parse Command-Line Arguments
# --------------------------------------------
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    --port)
      SERVER_PORT="$2"
      shift # past argument
      shift # past value
      ;;
    --autoupdate)
      AUTO_UPDATE="$2"
      shift
      shift
      ;;
    --branch)
      BRANCH="$2"
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
    --enable-sentry)
      ENABLE_SENTRY="$2"
      shift
      shift
      ;;
    --enable-nginx)
      ENABLE_NGINX="$2"
      shift
      shift
      ;;
    --repo)
      GIT_REPO_ADDRESS="$2"
      shift
      shift
      ;;
    --mode)
      MODE="$2"
      shift
      shift
      ;;
    --cmd-prod)
      CUSTOM_CMD_PROD="$2"
      shift
      shift
      ;;
    --cmd-dev)
      CUSTOM_CMD_DEV="$2"
      shift
      shift
      ;;
    --enable-log-service)
      ENABLE_LOG_SERVICE="$2"
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
if [[ -z "$SERVER_PORT" ]]; then
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
if ! [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] || [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; then
  error "--port must be a number between 1 and 65535."
fi

# --------------------------------------------
# Validate AUTO_UPDATE Argument (1 or 0)
# --------------------------------------------
validate_boolean_option "$AUTO_UPDATE" "autoupdate"

# --------------------------------------------
# Validate BRANCH Argument (Git Branch Naming)
# --------------------------------------------
if ! [[ "$BRANCH" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
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
# Validate MODE Argument
# --------------------------------------------
if [[ "$MODE" != "production" && "$MODE" != "development" ]]; then
  error "--mode must be 'production' or 'development'."
fi

# --------------------------------------------
# Validate Optional Boolean Arguments (1 or 0)
# --------------------------------------------
validate_boolean_option "$BUILD_BEFORE_START" "build-before-start"
validate_boolean_option "$REINSTALL_MODULES" "reinstall-modules"
validate_boolean_option "$FORCE_REBUILD" "force-rebuild"
validate_boolean_option "$ENABLE_SENTRY" "enable-sentry"
validate_boolean_option "$ENABLE_NGINX" "enable-nginx"
validate_boolean_option "$ENABLE_LOG_SERVICE" "enable-log-service"
# --------------------------------------------
# Display Initialization Message
# --------------------------------------------
info_message "Installing server environment..."

# --------------------------------------------
# Export Environment Variables
# --------------------------------------------
export PORT="$SERVER_PORT"
export CLUSTER_PORT=$((SERVER_PORT + 1))

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
success_message "Configuration:"
echo -e "${YELLOW}  SERVER_PORT: $SERVER_PORT${NC}"
echo -e "${YELLOW}  CLUSTER_PORT: $CLUSTER_PORT${NC}"
echo -e "${YELLOW}  AUTO_UPDATE: $AUTO_UPDATE${NC}"
echo -e "${YELLOW}  BUILD_BEFORE_START: $BUILD_BEFORE_START${NC}"
echo -e "${YELLOW}  REINSTALL_MODULES: $REINSTALL_MODULES${NC}"
echo -e "${YELLOW}  FORCE_REBUILD: $FORCE_REBUILD${NC}"
echo -e "${YELLOW}  ENABLE_SENTRY: $ENABLE_SENTRY${NC}"
echo -e "${YELLOW}  ENABLE_NGINX: $ENABLE_NGINX${NC}"
echo -e "${YELLOW}  BRANCH: $BRANCH${NC}"
echo -e "${YELLOW}  PRJ_TYPE: $PRJ_TYPE${NC}"
echo -e "${YELLOW}  PACKAGE_MANAGER: $PKG_MANAGER${NC}"
echo -e "${YELLOW}  MODE: $MODE${NC}" 
echo ""

# --------------------------------------------
# Function: Check if Git Branch is Up to Date
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
info_message "Setting file permissions..."
chmod +x ./check.sh || { error_exit "Failed to set execute permission on check.sh."; }
chmod +x ./sentry.sh || { error_exit "Failed to set execute permission on sentry.sh."; }
chmod +x ./nginx.sh || { error_exit "Failed to set execute permission on nginx.sh."; }

# --------------------------------------------
# Check Project Dependencies
# --------------------------------------------
info_message "Checking project dependencies..."
./check.sh --silent || { error_exit "Dependency check failed."; }

# --------------------------------------------
# Display Current Git Branch and Commit
# --------------------------------------------
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null)

if [[ -n "$CURRENT_BRANCH" && -n "$CURRENT_COMMIT" ]]; then
  success_message "Current branch: ${YELLOW}$CURRENT_BRANCH"
  success_message "Current commit: ${YELLOW}$CURRENT_COMMIT"
else
  error "Not a Git repository or Git is not installed."
fi

# --------------------------------------------
# Git Actions: Reset and Pull if Needed
# --------------------------------------------
if [[ -z "$GIT_REPO_ADDRESS" ]]; then
  info_message "Skipping Git actions (no repository provided)."
else
  if [[ -d .git && "$AUTO_UPDATE" -eq 1 ]]; then
    if is_git_up_to_date; then
      success_message "Project core is already up to date."
      success_message "Skip pulling."
      SKIP_UPDATE=true
    else
      info_message "Updating project core from repository..."

      PRE_PULL_COMMIT=$(git rev-parse HEAD)
      info_message "Pre-pull commit: ${YELLOW}$PRE_PULL_COMMIT${NC}"

      git reset --hard || { error_exit "Git reset failed."; }
      git pull || { error_exit "Git pull failed."; }

      POST_PULL_COMMIT=$(git rev-parse HEAD)
      success_message "Updated commit: ${YELLOW}$POST_PULL_COMMIT${NC}"

      CHANGED_FILES=$(git diff --name-only $PRE_PULL_COMMIT $POST_PULL_COMMIT)

      CHANGED_LOCK_FILES=$(echo "$CHANGED_FILES" | grep -E '^(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb)$')
      if [ -n "$CHANGED_LOCK_FILES" ]; then
        info_message "Changes detected in lock files:"
        debug_message "$CHANGED_LOCK_FILES"

      else
        success_message "No changes detected in lock files."
      fi

      if [ -f "tsconfig.json" ]; then
        if command -v jq >/dev/null 2>&1; then
          INCLUDE_PATTERNS=$(jq -r '.include[]' tsconfig.json | sed 's|^\./||')
          EXCLUDE_PATTERNS=$(jq -r '.exclude[]' tsconfig.json | sed 's|^\./||')
        else
          error "Jq not found. Skipping TypeScript files check."
          INCLUDE_PATTERNS=""
          EXCLUDE_PATTERNS=""
        fi

        CHANGED_TS_FILES=""

        while IFS= read -r file; do
          MATCH_INCLUDE=false
          for pattern in $INCLUDE_PATTERNS; do
            # Використовуємо bash glob matching
            if [[ "$file" == $pattern ]]; then
              MATCH_INCLUDE=true
              break
            fi
          done

          if [ "$MATCH_INCLUDE" = false ]; then
            continue
          fi

          MATCH_EXCLUDE=false
          for pattern in $EXCLUDE_PATTERNS; do
            if [[ "$file" == $pattern ]]; then
              MATCH_EXCLUDE=true
              break
            fi
          done

          if [ "$MATCH_EXCLUDE" = false ]; then
            CHANGED_TS_FILES+="$file"$' '
          fi
        done <<< "$CHANGED_FILES"

        if [ -n "$CHANGED_TS_FILES" ]; then
          info_message "Changes detected in TypeScript files."
          debug_message "$CHANGED_TS_FILES"
        else
          success_message "No changes detected in TypeScript files as per tsconfig.json."
        fi
      else
        error "tsconfig.json not found."
      fi

      if [ -n "$CHANGED_LOCK_FILES" ] || [ -n "$CHANGED_TS_FILES" ]; then
        SKIP_UPDATE=false
      else
        SKIP_UPDATE=true
      fi
    fi
  else
    warn_message "Auto update is disabled."
  fi
fi
# --------------------------------------------
# Load Environment Variables
# --------------------------------------------
if [ -f ".env" ]; then
    success_message ".env file found. Loading environment variables..."
    set -o allexport
    source .env
    set +o allexport
    success_message "Environment variables loaded successfully."
else
    error_exit ".env file not found. Please create a .env file with the required variables."
fi

# --------------------------------------------
# Handle Node Modules Installation and Updates
# --------------------------------------------
if [[ "$SKIP_UPDATE" == false || "$REINSTALL_MODULES" == "1" ]]; then
  # Reinstall node modules if requested
  if [[ "$REINSTALL_MODULES" == "1" ]]; then
    warn_message "Reinstalling node modules is enabled.${NC}"
    info_message "Remove node modules...${NC}"
    rm -rf node_modules || { error_exit "Failed to remove node_modules."; }
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
    warn_message "$LOCK_FILE does not exist. Creating..."
    $PKG_MANAGER install 2> >(grep -v warning >&2) | while IFS= read -r line; do
      echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
    done || { error_exit "Failed to install dependencies."; }
  fi
  info_message "Checking lock files..."
  # Handle Changes in Lock Files
  if [ -n "$CHANGED_LOCK_FILES" ]; then
    warn_message "Make action for detected changes in lock files. Trigger file:"
    debug_message "$CHANGED_LOCK_FILES"
    info_message "Installing updated packages..."
    info_message "Preparing dependencies..."
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
    success_message "No changes detected in lock files between local and remote."
  fi

  # --------------------------------------------
  # Consolidated Build Logic
  # --------------------------------------------

  if [ -n "$CHANGED_TS_FILES" ] && [ "$FORCE_REBUILD" != "1" ]; then
    warn_message "Detected changes in TypeScript files. Trigger files:"
    debug_message "$CHANGED_TS_FILES"
    info_message "Rebuilding application..."
    BUILD_REQUIRED=true
  fi

  if [ "$BUILD_BEFORE_START" == "1" ] && [ "$FORCE_REBUILD" != "1" ]; then
    # Only set BUILD_REQUIRED to true if not already set by TS changes
    if [ "$BUILD_REQUIRED" = false ]; then
      info_message "Building application as per BUILD_BEFORE_START flag..."
      BUILD_REQUIRED=true
    fi
  fi

  if [ "$BUILD_REQUIRED" = true ]; then
    NODE_ENV=production $CMD_PREFIX build > /dev/null 2>&1 || { error_exit "Build failed."; }
    success_message "Build completed successfully."
  elif [ "$FORCE_REBUILD" == "1" ]; then
    warn_message "Force rebuild enabled. Skipping build for detected changes in TypeScript files."
  else
    success_message "No build actions required."
  fi
fi

# --------------------------------------------
# Ensure Node Modules are Installed
# --------------------------------------------

info_message "Checking node modules before build operations..."
if ! directory_exists "node_modules"; then
  info_message "Installing node modules..."
  $PKG_MANAGER install 2> >(grep -v warning >&2) | while IFS= read -r line; do
    echo -e "${ORANGE}SIVIUM SCRIPTS |${LIGHTBLUE} $line${NC}"
  done || { error_exit "Failed to install node modules."; }
fi
# --------------------------------------------
# Handle Force Rebuild (If Not Covered Above)
# --------------------------------------------
if [[ "$FORCE_REBUILD" == "1" && "$BUILD_REQUIRED" = false ]]; then
  echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Force building project from source...${NC}"
  NODE_ENV=production $CMD_PREFIX build > /dev/null 2>&1 || { error_exit "Force build failed."; }
  success_message "Force build completed successfully."
  BUILD_REQUIRED=false
fi
# --------------------------------------------
# Handle Project Type Specific Builds (Optional)
# --------------------------------------------
if [[ "$BUILD_BEFORE_START" == "1" && "$FORCE_REBUILD" == "0" && "$BUILD_REQUIRED" = false ]]; then
  info_message "Checking build artifacts..."
  case "$PRJ_TYPE" in
    backend)
      if ! directory_exists "dist"; then
        info_message "Building backend from source..."
        NODE_ENV=production $CMD_PREFIX build > /dev/null 2>&1 || { error_exit "Backend build failed."; }
      fi
      ;;
    frontend)
      if ! directory_exists ".next"; then
        info_message "Building frontend from source..."
        NODE_ENV=production $CMD_PREFIX build > /dev/null 2>&1 || { error_exit "Frontend build failed."; }
      fi
      ;;
    api|microservice)
      # Add specific build steps if needed
      success_message "No specific build steps for project type '${PRJ_TYPE}'.${NC}"
      ;;
    *)
      error "Unknown project type: $PRJ_TYPE"
      ;;
  esac
fi
# --------------------------------------------
# Setup Sentry Release
# --------------------------------------------

if [ "$ENABLE_SENTRY" == "1" ]; then
    info_message "Checking Sentry release..."
    ./sentry.sh || { error_exit "Sentry setup failed."; }
  else
    info_message "Sentry plugin is dissabled."
fi

# --------------------------------------------
# Setup Nginx (if not disabled)
# --------------------------------------------
if [ "$ENABLE_NGINX" == "1" ]; then
    info_message "Setting up Nginx..."
    ./nginx.sh --verify --register || { error_exit "Nginx setup failed."; }
  else
    info_message "Nginx plugin is dissabled."
fi

# --------------------------------------------
# Start Production or Development Server
# --------------------------------------------

info_message "Starting production server..."
info_message "Starting application in '$MODE' mode..."

if [ "$MODE" == "production" ]; then
  NODE_ENV=production $CMD_PREFIX "$CUSTOM_CMD_PROD" > /dev/null 2>&1 || {
    error_exit "Failed to start production server."
  }
else
  NODE_ENV=development $CMD_PREFIX "$CUSTOM_CMD_DEV" > /dev/null 2>&1 || {
    error_exit "Failed to start dev server."
  }
fi

# --------------------------------------------
# Monitor with PM2
# --------------------------------------------
if [ "$ENABLE_LOG_SERVICE" == "1" ]; then
  info_message "Starting log service..."
  success_message "Process started. Monitoring with PM2."
  $CMD_PREFIX monit || { error_exit "Failed to start PM2 monitoring."; }
else
  warn_message "Log service (PM2 monitoring) is disabled."
fi


# --------------------------------------------
# Script Completion
# --------------------------------------------
success_message "Deployment completed successfully."