#!/bin/bash

# ============================================
# SIVIUM SCRIPTS - Nginx and SSL Configuration
# ============================================
# This script automates the setup and configuration
# of Nginx with SSL certificates managed by acme.sh
# and integrates with Cloudflare for DNS management.
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
NGINX_CONFIG=".nginx/root.conf"                           # Path to Nginx configuration template
TARGET_CONFIG="/etc/nginx/sites-enabled/${DOMAIN_NAME}-${HOSTNAME}.conf" # Target Nginx configuration path
CERT_PATH=".ssl/${DOMAIN_NAME}-${HOSTNAME}"                # Path to store SSL certificates
ACME_PATH=".acme"                                         # Path to acme.sh installation

# --------------------------------------------
# Function: Display Error Messages and Usage
# --------------------------------------------
error() {
    echo -e "${ORANGE}SIVIUM SCRIPTS |${RED} Error:${NC} $1"
    usage  # Assuming a 'usage' function is defined elsewhere in your script
}

# --------------------------------------------
# Function: Display an Error Message and Exit
# --------------------------------------------
error_exit() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Error: $1${NC}"
    exit 1
}

# --------------------------------------------
# Function: Display a Success Message
# --------------------------------------------
success_message() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}$1${NC}"
}

# --------------------------------------------
# Function: Display an Informational Message
# --------------------------------------------
info_message() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}$1${NC}"
}

# --------------------------------------------
# Function: Display a Warning Message
# --------------------------------------------
warn_message() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${YELLOW}$1${NC}"
}

# --------------------------------------------
# Function: Display a Debug Message
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
    # Add more usage information as needed
    exit 1
}

# --------------------------------------------
# Check for Required Environment Variables
# --------------------------------------------
required_env_vars=(CF_Token CF_Account_ID CF_Zone_ID EMAIL DOMAIN_NAME HOSTNAME APP_PORT)

for var in "${required_env_vars[@]}"; do
    if [ -z "${!var}" ]; then
        error_exit "Required environment variable '$var' is not set. Exiting."
    fi
done

success_message "All required Cloudflare environment variables are set."

# --------------------------------------------
# Create Required Directories if They Don't Exist
# --------------------------------------------
debug_message "Creating directories: $(dirname "$NGINX_CONFIG"), $CERT_PATH, $ACME_PATH"
mkdir -p "$(dirname "$NGINX_CONFIG")" "$CERT_PATH" "$ACME_PATH"

# --------------------------------------------
# Register acme.sh Account with ZeroSSL if Not Registered
# --------------------------------------------
info_message "Checking acme.sh account registration with ZeroSSL..."

if [ ! -f "${ACME_PATH}/account.conf" ]; then
    # Attempt to register the account
    info_message "Registering acme.sh account with email: $EMAIL"
    "${ACME_PATH}/acme.sh" --register-account -m "$EMAIL"

    # Check if the registration was successful by looking for account.conf
    if [ -f "${ACME_PATH}/account.conf" ]; then
        success_message "Account successfully registered with ZeroSSL."
    else
        # If account.conf is missing, check for errors in the http.header
        if [ -f "${ACME_PATH}/http.header" ]; then
            error "Registration failed. Checking http.header for details..."
            cat "${ACME_PATH}/http.header"
        else
            error "Registration failed, and no http.header file found for debugging."
        fi
        # Exit to avoid further execution if registration fails
        exit 1
    fi
else
    success_message "acme.sh account is already registered."
fi

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
            error_message "SSL certificate for $domain is expiring in ${days_left} days. Renewing..."
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
# Function: Request or Renew the SSL Certificate
# --------------------------------------------
renew_certificate() {
    local domain="$1"

    if [ -x "${ACME_PATH}/acme.sh" ]; then
        info_message "Issuing SSL certificate for $domain using acme.sh..."
        "${ACME_PATH}/acme.sh" --issue --dns dns_cf -d "${domain}" \
            --keylength ec-256 \
            --cert-file "${CERT_PATH}/${domain}.cer" \
            --key-file "${CERT_PATH}/${domain}.key" \
            --fullchain-file "${CERT_PATH}/${domain}.fullchain.cer"

        if [ $? -eq 0 ]; then
            info_message "SSL certificate obtained successfully for $domain."
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
    local app_port="$2"

    info_message "Creating Nginx configuration for $domain."

    cat <<EOL > "$NGINX_CONFIG"
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
        proxy_pass http://localhost:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

    success_message "Nginx configuration generated at $NGINX_CONFIG."
}

# --------------------------------------------
# Main Process
# --------------------------------------------
main() {
    # Ensure DOMAIN_NAME and HOSTNAME are set
    if [ -z "${DOMAIN_NAME}" ] || [ -z "${HOSTNAME}" ]; then
        error_exit "DOMAIN_NAME and HOSTNAME environment variables must be set."
    fi

    # Ensure APP_PORT is set
    if [ -z "${APP_PORT}" ]; then
        error_exit "APP_PORT environment variable must be set."
    fi

    # Generate Nginx configuration if it doesn't exist
    if [ ! -f "$NGINX_CONFIG" ]; then
        warn_message "Configuration for $HOSTNAME not found, generating a new one."
        generate_nginx_config "$DOMAIN_NAME" "$APP_PORT"
        
        # Check SSL certificate expiration (which will renew if necessary)
        check_certificate_expiration "$DOMAIN_NAME"
        
        # Reload Nginx to apply new configuration
        info_message "Reloading Nginx to apply new configuration..."
        nginx -s reload || error_exit "Failed to reload Nginx."
        
        success_message "Nginx reloaded with the new configuration for $HOSTNAME."
    else
        info_message "Configuration for $HOSTNAME already exists. Checking SSL certificate expiration..."
        check_certificate_expiration "$DOMAIN_NAME"
    fi
}

# --------------------------------------------
# Execute Main Function
# --------------------------------------------
main