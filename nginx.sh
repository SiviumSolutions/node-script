#!/bin/bash

# ============================================
# SIVIUM SCRIPTS - Nginx and SSL Configuration
# ============================================
# This script automates the setup and configuration
# of Nginx with SSL certificates managed by acme.sh
# and integrates with Cloudflare for DNS management.
# It also includes container registration and verification
# with an external Node.js service.
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
# Configuration Variables
# --------------------------------------------
NGINX_CONFIG_TEMPLATE=".nginx/root.conf"                           # Path to Nginx configuration template
TARGET_CONFIG="/etc/nginx/sites-enabled/${DOMAIN_NAME}-${HOSTNAME}.conf" # Target Nginx configuration path
CERT_PATH=".ssl/${DOMAIN_NAME}-${HOSTNAME}"                # Path to store SSL certificates
ACME_PATH=".acme"                                         # Path to acme.sh installation
REGISTRATION_URL="https://your.nodejs.service/register-container" # URL to register the container
VERIFICATION_URL="https://your.nodejs.service/verify-container"   # URL to verify the container

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
    # Add more usage information as needed
    exit 1
}

# --------------------------------------------
# Function: Check Required Environment Variables
# --------------------------------------------
check_env_vars() {
    required_env_vars=(CF_Token CF_Account_ID CF_Zone_ID EMAIL DOMAIN_NAME HOSTNAME SERVER_PORT GITHUB_WEBHOOK_SECRET BEARER_TOKEN ENDPOINT API_KEY)
    
    for var in "${required_env_vars[@]}"; do
        if [ -z "${!var}" ]; then
            error_exit "Required environment variable '$var' is not set. Exiting."
        fi
    done
    
    success_message "All required environment variables are set."
}

# --------------------------------------------
# Function: Create Required Directories
# --------------------------------------------
create_directories() {
    debug_message "Creating directories: $(dirname "$NGINX_CONFIG_TEMPLATE"), $CERT_PATH, $ACME_PATH"
    mkdir -p "$(dirname "$NGINX_CONFIG_TEMPLATE")" "$CERT_PATH" "$ACME_PATH"
}

# --------------------------------------------
# Function: Register Container with External Service
# --------------------------------------------
register_container() {
    local container_id="$1"
    
    info_message "Registering container '$container_id' with external service..."
    
    # Make POST request to registration endpoint
    response=$(curl -s -w "\n%{http_code}" -X POST "$REGISTRATION_URL" \
        -H "Content-Type: application/json" \
        -d "{\"containerId\": \"${container_id}\"}")
    
    # Extract body and status code
    body=$(echo "$response" | sed '$d')
    status_code=$(echo "$response" | tail -n1)
    
    if [ "$status_code" -eq 201 ]; then
        access_token=$(echo "$body" | jq -r '.accessToken')
        success_message "Container registered successfully. Access Token: $access_token"
        echo "$access_token" > ".container_${container_id}_token.txt"
    elif [ "$status_code" -eq 409 ]; then
        access_token=$(echo "$body" | jq -r '.accessToken')
        warn_message "Container already registered. Existing Access Token: $access_token"
        echo "$access_token" > ".container_${container_id}_token.txt"
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
    
    info_message "Verifying registration status for container '$container_id'..."
    
    # Make GET request to verification endpoint
    response=$(curl -s -w "\n%{http_code}" -X GET "$VERIFICATION_URL?containerId=${container_id}" \
        -H "Authorization: Bearer ${access_token}")
    
    # Extract body and status code
    body=$(echo "$response" | sed '$d')
    status_code=$(echo "$response" | tail -n1)
    
    if [ "$status_code" -eq 200 ]; then
        status=$(echo "$body" | jq -r '.status')
        if [ "$status" == "registered" ]; then
            success_message "Container '$container_id' is successfully registered."
        else
            warn_message "Container '$container_id' registration status: $status"
        fi
    else
        error_exit "Failed to verify container registration. Status Code: $status_code, Response: $body"
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
    
    if [ -x "${ACME_PATH}/acme.sh" ]; then
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
    else
        error_exit "acme.sh not found or not executable at ${ACME_PATH}/acme.sh."
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
# Function: Register and Verify Container
# --------------------------------------------
register_and_verify_container() {
    local container_id="$1"
    
    register_container "$container_id"
    
    # Retrieve Access Token
    if [ -f ".container_${container_id}_token.txt" ]; then
        access_token=$(cat ".container_${container_id}_token.txt")
    else
        error_exit "Access token file not found for container '$container_id'."
    fi
    
    verify_container "$container_id" "$access_token"
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
    # Parse command-line arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --help|-h) usage ;;
            --register|-r) action="register" ;;
            --verify|-v) action="verify" ;;
            --force-renew|-f) action="force-renew" ;;
            *) 
                error_exit "Unknown parameter passed: $1"
                ;;
        esac
        shift
    done
    
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
    
    # Perform actions based on command-line arguments
    case "$action" in
        register)
            if [ -z "$HOSTNAME" ]; then
                error_exit "HOSTNAME environment variable must be set to register the container."
            fi
            register_and_verify_container "$HOSTNAME"
            ;;
        verify)
            if [ -z "$HOSTNAME" ]; then
                error_exit "HOSTNAME environment variable must be set to verify the container."
            fi
            if [ -f ".container_${HOSTNAME}_token.txt" ]; then
                access_token=$(cat ".container_${HOSTNAME}_token.txt")
                verify_container "$HOSTNAME" "$access_token"
            else
                error_exit "Access token file not found for container '$HOSTNAME'. Please register first."
            fi
            ;;
        force-renew)
            force_renew_ssl "$DOMAIN_NAME"
            ;;
        *)
            # Default behavior: setup and deploy
            ;;
    esac
}

# --------------------------------------------
# Execute Main Function
# --------------------------------------------
main "$@"
