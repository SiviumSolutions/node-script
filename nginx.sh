#!/bin/bash

# ============================================
# SIVIUM SCRIPTS - Nginx and SSL Configuration
# ============================================
# This script automates the setup and configuration
# of Nginx with SSL certificates managed by acme.sh
# and integrates with Cloudflare for DNS management.
# It also includes container registration and verification
# with an external Node.js service using access tokens.
# ============================================

# --------------------------------------------
# ANSI Color Codes for Styled Output
# --------------------------------------------
ORANGE='\033[0;33m'       # Orange
GREEN='\033[0;32m'        # Green
PURPLE='\033[0;35m'       # Purple
YELLOW='\033[1;33m'       # Yellow
RED='\033[0;31m'          # Red
LIGHTBLUE='\033[1;34m'    # Light Blue
GREY='\033[1;30m'         # Grey
BOLD='\033[1m'            # Bold Text
UNDERLINE='\033[4m'       # Underlined Text
NC='\033[0m'              # No Color

# --------------------------------------------
# Function: Display Error Messages and Exit
# --------------------------------------------
error_exit() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: $1${NC}"
    exit 1
}

# --------------------------------------------
# Function: Display Success Messages
# --------------------------------------------
success_message() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}$1${NC}"
}

# --------------------------------------------
# Function: Display Informational Messages
# --------------------------------------------
info_message() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}$1${NC}"
}

# --------------------------------------------
# Function: Display Warning Messages
# --------------------------------------------
warn_message() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}$1${NC}"
}

# --------------------------------------------
# Function: Display Debug Messages
# --------------------------------------------
debug_message() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREY}$1${NC}"
}

# --------------------------------------------
# Function: Display Usage Instructions
# --------------------------------------------
usage() {
    echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Usage:${NC} $0 [options]"
    echo -e "Options:"
    echo -e "  --help, -h           Display this help message."
    echo -e "  --register, -r       Register the container with the external service."
    echo -e "  --verify, -v         Verify the container registration status."
    echo -e "  --force-renew, -f    Force renewal of SSL certificates."
    exit 0
}

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
# Configuration Variables
# --------------------------------------------
NGINX_CONFIG_TEMPLATE=".nginx/root.conf"                                # Path to Nginx configuration template
TARGET_CONFIG="/etc/nginx/sites-enabled/${DOMAIN_NAME}-${HOSTNAME}.conf" # Target Nginx configuration path
CERT_PATH=".ssl/${DOMAIN_NAME}-${HOSTNAME}"                             # Path to store SSL certificates
ACME_PATH=".acme"                                                     # Path to acme.sh installation
REGISTRATION_URL="https://hosting.sivium.solutions/api/register-container/"  # URL to register the container
VERIFICATION_URL="https://hosting.sivium.solutions/api/check-files/"    # URL to verify the container

# Flag to indicate if registration has been performed in this run
REGISTERED=false

# --------------------------------------------
# Function: Check Dependencies
# --------------------------------------------
check_dependencies() {
    local dependencies=(curl jq openssl nginx systemctl sudo)
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            error_exit "Required command '$cmd' is not installed. Please install it and retry."
        fi
    done

    if [ ! -x "${ACME_PATH}/acme.sh" ]; then
        error_exit "acme.sh not found or not executable at ${ACME_PATH}/acme.sh."
    fi
}

# --------------------------------------------
# Function: Check Required Environment Variables
# --------------------------------------------
check_env_vars() {
    required_env_vars=(CF_Token CF_Account_ID CF_Zone_ID EMAIL DOMAIN_NAME HOSTNAME SERVER_PORT CLUSTER_CLOUD_REGISTER_TOKEN)

    missing_vars=()

    for var in "${required_env_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error:${NC} Missing required environment variables: ${missing_vars[*]}"
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}Please update your .env file and add the missing tokens:${NC}"
        for var in "${missing_vars[@]}"; do
            echo -e "  - ${var}"
        done
        exit 1
    else
        success_message "All required environment variables are set."
    fi
}

# --------------------------------------------
# Function: Create Required Directories
# --------------------------------------------
create_directories() {
    debug_message "Creating directories: $(dirname "$NGINX_CONFIG_TEMPLATE"), $CERT_PATH, $ACME_PATH"
    mkdir -p "$(dirname "$NGINX_CONFIG_TEMPLATE")" "$CERT_PATH" "$ACME_PATH" || error_exit "Failed to create necessary directories."
}

# --------------------------------------------
# Function: Register Container with External Service
# --------------------------------------------
register_container() {
    local container_id="$1"

    info_message "Registering container '$container_id' with external service..."

    # Make POST request to registration endpoint with CLUSTER_CLOUD_REGISTER_TOKEN for authentication
    response=$(curl -s -w "\n%{http_code}" -X POST "$REGISTRATION_URL" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${CLUSTER_CLOUD_REGISTER_TOKEN}" \
        -d "{\"containerId\": \"${container_id}\"}")

    # Extract body and status code
    body=$(echo "$response" | sed '$d')
    status_code=$(echo "$response" | tail -n1)

    if [ "$status_code" -eq 201 ]; then
        access_token=$(echo "$body" | jq -r '.accessToken')
        success_message "Container registered successfully."
        echo -e "${ORANGE}====================================CRITICAL ALERT=======================================${NC}"
        echo -e "${ORANGE}===   ${RED}Please add the following line to your .env file:${NC}"
        echo -e "${ORANGE}===   ${RED}CLUSTER_CLOUD_TOKEN=${access_token}${NC}"
        echo -e "${ORANGE}===   ${YELLOW}This token is available only once for this container.${NC}"
        echo -e "${ORANGE}=========================================================================================${NC}"
        # Export the token for current script session
        export CLUSTER_CLOUD_TOKEN="$access_token"
        REGISTERED=true
    elif [ "$status_code" -eq 409 ]; then
        warn_message "Container is already registered."
        if [ -n "$CLUSTER_CLOUD_TOKEN" ]; then
            success_message "CLUSTER_CLOUD_TOKEN is already set in the environment."
        else
            echo -e "\n${ORANGE}SIVIUM SCRIPTS | ${RED}Error: CLUSTER_CLOUD_TOKEN is not set in your .env file.${NC}"
            echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}Please add the existing CLUSTER_CLOUD_TOKEN to your .env file to proceed.${NC}"
            exit 1
        fi
    else
        error_exit "Failed to register container. Status Code: $status_code, Response: $body"
    fi
}

# --------------------------------------------
# Function: Verify Container Registration
# --------------------------------------------
verify_container() {
    local container_id="$1"
    local access_token="$2"

    info_message "Verifying nginx configurations for container '$container_id'..."

    # Make GET request to verification endpoint with CLUSTER_CLOUD_TOKEN for authentication
    response=$(curl -s -w "\n%{http_code}" -X GET "$VERIFICATION_URL?serverId=${container_id}&rootDomain=${DOMAIN_NAME}" \
        -H "Authorization: Bearer ${access_token}")

    # Extract body and status code
    body=$(echo "$response" | sed '$d')
    status_code=$(echo "$response" | tail -n1)

    if [ "$status_code" -eq 200 ]; then
        status=$(echo "$body" | jq -r '.changedFiles')
        if [ "$status" == "null" ] || [ -z "$status" ]; then
            success_message "Nothing to update in cluster configuration."
        else
            warn_message "Changes detected. Updating cluster..."
            warn_message "Files to upload: $status"
            # Add additional logic here if needed to handle the changes
        fi
    else
        error_exit "Failed to verify container nginx settings. Status Code: $status_code, Response: $body"
    fi
}

# --------------------------------------------
# Function: Register acme.sh Account with ZeroSSL
# --------------------------------------------
register_acme_account() {
    info_message "Checking acme.sh account registration with ZeroSSL..."

    # Check account registration directly via acme.sh
    REGISTRATION_STATUS=$("${ACME_PATH}/acme.sh" --register-account -m "$EMAIL" 2>&1)

    # Parse the output to determine success
    if echo "$REGISTRATION_STATUS" | grep -q "Already registered"; then
        success_message "Account is already registered with ZeroSSL."
    elif echo "$REGISTRATION_STATUS" | grep -q "ACCOUNT_THUMBPRINT"; then
        success_message "Account successfully registered with ZeroSSL."
    else
        warn_message "Account registration failed. Skipping registration and proceeding."
    fi
}

# --------------------------------------------
# Function: Check SSL Certificate Expiration
# --------------------------------------------
check_certificate_expiration() {
    local domain="$1"

    if [ -f "${CERT_PATH}/${domain}.cer" ]; then
        # Get the expiration date of the certificate
        expiration_date=$(openssl x509 -enddate -noout -in "${CERT_PATH}/${domain}.cer" | cut -d= -f2)
        # Convert to epoch
        expiration_epoch=$(date -d "${expiration_date}" +%s)
        current_epoch=$(date +%s)
        # Calculate days left
        days_left=$(( (expiration_epoch - current_epoch) / 86400 ))

        if [ "$days_left" -le 30 ]; then
            warn_message "SSL certificate for $domain is expiring in ${days_left} days. Renewing..."
            renew_certificate "$domain"
        else
            success_message "SSL certificate for $domain is valid for ${days_left} more days."
        fi
    else
        warn_message "SSL certificate not found for $domain. Requesting new certificate..."
        renew_certificate "$domain"
    fi
}

# --------------------------------------------
# Function: Renew SSL Certificate
# --------------------------------------------
renew_certificate() {
    local domain="$1"

    info_message "Issuing SSL certificate for $domain using acme.sh..."
    "${ACME_PATH}/acme.sh" --issue --dns dns_cf -d "${domain}" \
        --keylength ec-256 \
        --cert-file "${CERT_PATH}/${domain}.cer" \
        --key-file "${CERT_PATH}/${domain}.key" \
        --fullchain-file "${CERT_PATH}/${domain}.fullchain.cer" \
        --debug
    if [ $? -eq 0 ]; then
        success_message "SSL certificate obtained successfully for $domain."
    else
        error_exit "Failed to obtain SSL certificate for $domain."
    fi
}

# --------------------------------------------
# Function: Generate Nginx Configuration
# --------------------------------------------
generate_nginx_config() {
    local domain="$1"
    local server_port="$2"

    info_message "Creating Nginx configuration for $domain."

    cat <<EOL > "$NGINX_CONFIG_TEMPLATE"
server {
    listen 80;
    listen 443 ssl;
    server_name ${domain};

    ssl_certificate ${CERT_PATH}/${domain}.cer;
    ssl_certificate_key ${CERT_PATH}/${domain}.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://localhost:${server_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

    success_message "Nginx configuration generated at $NGINX_CONFIG_TEMPLATE."
}

# --------------------------------------------
# Function: Deploy Nginx Configuration
# --------------------------------------------
deploy_nginx_config() {
    local domain="$1"
    local server_port="$2"

    info_message "Deploying Nginx configuration for $domain."

    # Copy the configuration to the target directory
    sudo cp "$NGINX_CONFIG_TEMPLATE" "$TARGET_CONFIG" || error_exit "Failed to copy Nginx configuration."

    success_message "Nginx configuration deployed to $TARGET_CONFIG."

    # Test Nginx configuration
    info_message "Testing Nginx configuration..."
    sudo nginx -t
    if [ $? -ne 0 ]; then
        error_exit "Nginx configuration test failed."
    else
        success_message "Nginx configuration test passed."
    fi

    # Reload Nginx to apply changes
    info_message "Reloading Nginx to apply new configuration..."
    sudo systemctl reload nginx
    if [ $? -ne 0 ]; then
        error_exit "Failed to reload Nginx."
    else
        success_message "Nginx reloaded successfully."
    fi
}

# --------------------------------------------
# Function: Force Renew SSL Certificates
# --------------------------------------------
force_renew_ssl() {
    local domain="$1"

    info_message "Forcing renewal of SSL certificate for $domain..."
    renew_certificate "$domain"

    # Reload Nginx after renewal
    info_message "Reloading Nginx after certificate renewal..."
    sudo systemctl reload nginx
    if [ $? -ne 0 ]; then
        error_exit "Failed to reload Nginx after certificate renewal."
    else
        success_message "Nginx reloaded successfully after certificate renewal."
    fi
}

# --------------------------------------------
# Main Function
# --------------------------------------------
main() {
    # Check for required dependencies
    # check_dependencies

    # Parse command-line arguments and store actions in an array
    actions=()
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --help|-h)
                usage
                ;;
            --register|-r)
                actions+=("register")
                ;;
            --verify|-v)
                actions+=("verify")
                ;;
            --force-renew|-f)
                actions+=("force-renew")
                ;;
            *)
                error_exit "Unknown parameter passed: $1"
                ;;
        esac
        shift
    done

    # If no actions are specified, set default action
    if [ ${#actions[@]} -eq 0 ]; then
        actions+=("default")
    fi

    # Check required environment variables
    check_env_vars

    # Create necessary directories
    create_directories

    # Register acme.sh account
    register_acme_account

    # Generate Nginx configuration if not exists
    if [ ! -f "$NGINX_CONFIG_TEMPLATE" ]; then
        warn_message "Configuration for $HOSTNAME not found, generating a new one."
        generate_nginx_config "$DOMAIN_NAME" "$SERVER_PORT"

        # Check SSL certificate expiration (which will renew if necessary)
        check_certificate_expiration "$DOMAIN_NAME"

        # Deploy Nginx configuration
        deploy_nginx_config "$DOMAIN_NAME" "$SERVER_PORT"
    else
        info_message "Configuration for $HOSTNAME already exists. Checking SSL certificate expiration..."
        check_certificate_expiration "$DOMAIN_NAME"
    fi

    # If both register and verify are present, ensure register is executed first
    if [[ " ${actions[*]} " == *" register "* ]] && [[ " ${actions[*]} " == *" verify "* ]]; then
        # Rearrange actions to have 'register' first
        new_actions=()
        for action in "${actions[@]}"; do
            if [ "$action" == "register" ]; then
                new_actions+=("register")
            fi
        done
        for action in "${actions[@]}"; do
            if [ "$action" != "register" ]; then
                new_actions+=("$action")
            fi
        done
        actions=("${new_actions[@]}")
    fi

    # Execute actions in the order they were provided
    for action in "${actions[@]}"; do
        case "$action" in
            register)
                if [ -z "$HOSTNAME" ]; then
                    error_exit "HOSTNAME environment variable must be set to register the container."
                fi
                register_container "$HOSTNAME"
                ;;
            verify)
                if [ -z "$HOSTNAME" ]; then
                    error_exit "HOSTNAME environment variable must be set to verify the container."
                fi
                if [ -n "$CLUSTER_CLOUD_TOKEN" ]; then
                    verify_container "$HOSTNAME" "$CLUSTER_CLOUD_TOKEN"
                else
                    error_exit "CLUSTER_CLOUD_TOKEN is not set in your .env file. Please add it to proceed with verification."
                fi
                ;;
            force-renew)
                force_renew_ssl "$DOMAIN_NAME"
                ;;
            default)
                # Default behavior: setup and deploy
                :
                ;;
            *)
                warn_message "Unknown action: $action. Skipping."
                ;;
        esac
    done
}

# --------------------------------------------
# Execute Main Function
# --------------------------------------------
main "$@"
