#!/bin/bash

# Colors for output
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables (ensure these are set in the Docker environment or adjust them manually)
NGINX_CONFIG="/mnt/configs/nginx-config.conf"
TARGET_CONFIG="/etc/nginx/sites-enabled/${CONTAINER_NAME}.conf"
CERT_PATH="/etc/nginx/certs/${DOMAIN_NAME}"
ACME_PATH="/root/.acme.sh"  # Ensure acme.sh is installed here or adjust accordingly

# Cloudflare API token (make sure it's set as an environment variable)
export CF_Token="${CLOUDFLARE_API_TOKEN}"

# Function to check certificate expiration
check_certificate_expiration() {
    if [ -f "${CERT_PATH}/${DOMAIN_NAME}.cer" ]; then
        # Check certificate expiration date
        expiration_date=$(openssl x509 -enddate -noout -in "${CERT_PATH}/${DOMAIN_NAME}.cer" | cut -d= -f2)
        expiration_epoch=$(date -d "${expiration_date}" +%s)
        current_epoch=$(date +%s)
        days_left=$(( (expiration_epoch - current_epoch) / 86400 ))

        if [ "$days_left" -le 30 ]; then
            echo -e "${RED}SIVIUM SCRIPTS | SSL certificate for $DOMAIN_NAME is expiring in ${days_left} days. Renewing...${NC}"
            renew_certificate
        else
            echo -e "${GREEN}SIVIUM SCRIPTS | SSL certificate for $DOMAIN_NAME is valid for ${days_left} more days.${NC}"
        fi
    else
        echo -e "${ORANGE}SIVIUM SCRIPTS | SSL certificate not found for $DOMAIN_NAME. Requesting new certificate...${NC}"
        renew_certificate
    fi
}

# Function to request or renew the SSL certificate
renew_certificate() {
    ${ACME_PATH}/acme.sh --issue --dns dns_cf -d ${DOMAIN_NAME} \
        --keylength ec-256 \
        --cert-file "${CERT_PATH}/${DOMAIN_NAME}.cer" \
        --key-file "${CERT_PATH}/${DOMAIN_NAME}.key" \
        --fullchain-file "${CERT_PATH}/${DOMAIN_NAME}.fullchain.cer"
    if [ $? -eq 0 ]; then
        echo -e "${PURPLE}SIVIUM SCRIPTS | SSL certificate obtained successfully for $DOMAIN_NAME.${NC}"
    else
        echo -e "${RED}SIVIUM SCRIPTS | Failed to obtain SSL certificate for $DOMAIN_NAME.${NC}"
        exit 1
    fi
}

# Generate Nginx configuration
generate_nginx_config() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | Creating Nginx configuration for $CONTAINER_NAME.${NC}"
    cat <<EOL > $NGINX_CONFIG
server {
    listen 80;
    listen 443 ssl;
    server_name ${DOMAIN_NAME};

    # SSL certificate files
    ssl_certificate ${CERT_PATH}/${DOMAIN_NAME}.cer;
    ssl_certificate_key ${CERT_PATH}/${DOMAIN_NAME}.key;

    # SSL configurations
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

    # Copy configuration to the global server directory
    cp "$NGINX_CONFIG" "$TARGET_CONFIG"
}

# Main process
if [ ! -f "$TARGET_CONFIG" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | Configuration for $CONTAINER_NAME not found, generating a new one.${NC}"

    # Generate Nginx configuration
    generate_nginx_config

    # Check and renew SSL certificate
    check_certificate_expiration

    # Reload Nginx to apply the new configuration
    nginx -s reload
    echo -e "${GREEN}SIVIUM SCRIPTS | Nginx reloaded with the new configuration for $CONTAINER_NAME.${NC}"
else
    echo -e "${ORANGE}SIVIUM SCRIPTS | Configuration for $CONTAINER_NAME already exists. Checking SSL certificate expiration...${NC}"
    
    # Check and renew SSL certificate if necessary
    check_certificate_expiration
fi
