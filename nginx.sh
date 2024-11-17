#!/bin/bash

# Colors for output
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
DOMAIN_NAME='test.sivium.solutions'
NGINX_CONFIG=".nginx/root.conf"
TARGET_CONFIG="/etc/nginx/sites-enabled/${DOMAIN_NAME}-${HOSTNAME}.conf"
CERT_PATH=".ssl/${DOMAIN_NAME}-${HOSTNAME}"
ACME_PATH=".acme"
EMAIL="my@example.com"  # Replace with your actual email for acme.sh account

# Check for required environment variables
if [ -z "${CF_Token}" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Cloudflare Token (CF_Token) is not set. Exiting.${NC}"
    exit 1
fi

if [ -z "${CF_Account_ID}" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Cloudflare Account ID (CF_Account_ID) is not set. Exiting.${NC}"
    exit 1
fi

if [ -z "${CF_Zone_ID}" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Cloudflare Zone ID (CF_Zone_ID) is not set. Exiting.${NC}"
    exit 1
fi

echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}All required Cloudflare environment variables are set.${NC}"

# Create required directories if they don't exist
mkdir -p "$(dirname "$NGINX_CONFIG")" "$CERT_PATH" "$ACME_PATH"

# Register acme.sh account with email if not already registered
if [ ! -f "${ACME_PATH}/account.conf" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | Registering acme.sh account with ZeroSSL...${NC}"
    "${ACME_PATH}/acme.sh" --register-account -m "$EMAIL"
fi

# Function to check certificate expiration
check_certificate_expiration() {
    if [ -f "${CERT_PATH}/${DOMAIN_NAME}-${HOSTNAME}.cer" ]; then
        expiration_date=$(openssl x509 -enddate -noout -in "${CERT_PATH}/${DOMAIN_NAME}.cer" | cut -d= -f2)
        expiration_epoch=$(date -d "${expiration_date}" +%s)
        current_epoch=$(date +%s)
        days_left=$(( (expiration_epoch - current_epoch) / 86400 ))

        if [ "$days_left" -le 30 ]; then
            echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}SSL certificate for $DOMAIN_NAME is expiring in ${days_left} days. Renewing...${NC}"
            renew_certificate
        else
            echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}SSL certificate for $DOMAIN_NAME is valid for ${days_left} more days.${NC}"
        fi
    else
        echo -e "${ORANGE}SIVIUM SCRIPTS | SSL certificate not found for $DOMAIN_NAME. Requesting new certificate...${NC}"
        renew_certificate
    fi
}

# Function to request or renew the SSL certificate
renew_certificate() {
    if [ -x "${ACME_PATH}/acme.sh" ]; then
        "${ACME_PATH}/acme.sh" --issue --dns dns_cf -d "${DOMAIN_NAME}" \
            --keylength ec-256 \
            --cert-file "${CERT_PATH}/${DOMAIN_NAME}.cer" \
            --key-file "${CERT_PATH}/${DOMAIN_NAME}.key" \
            --fullchain-file "${CERT_PATH}/${DOMAIN_NAME}.fullchain.cer"
        if [ $? -eq 0 ]; then
            echo -e "${ORANGE}SIVIUM SCRIPTS | ${PURPLE}SSL certificate obtained successfully for $DOMAIN_NAME.${NC}"
        else
            echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}Failed to obtain SSL certificate for $DOMAIN_NAME.${NC}"
            exit 1
        fi
    else
        echo -e "${ORANGE}SIVIUM SCRIPTS | ${RED}acme.sh not found or not executable at ${ACME_PATH}/acme.sh.${NC}"
        exit 1
    fi
}

# Generate Nginx configuration
generate_nginx_config() {
    echo -e "${ORANGE}SIVIUM SCRIPTS | Creating Nginx configuration for $CONTAINER_NAME.${NC}"
    cat <<EOL > "$NGINX_CONFIG"
server {
    listen 80;
    listen 443 ssl;
    server_name ${DOMAIN_NAME};

    ssl_certificate ${CERT_PATH}/${DOMAIN_NAME}.cer;
    ssl_certificate_key ${CERT_PATH}/${DOMAIN_NAME}.key;

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
    cp "$NGINX_CONFIG" "$TARGET_CONFIG"
}

# Main process
if [ ! -f "$TARGET_CONFIG" ]; then
    echo -e "${ORANGE}SIVIUM SCRIPTS | Configuration for $CONTAINER_NAME not found, generating a new one.${NC}"
    generate_nginx_config
    check_certificate_expiration
    nginx -s reload
    echo -e "${ORANGE}SIVIUM SCRIPTS | ${GREEN}Nginx reloaded with the new configuration for $CONTAINER_NAME.${NC}"
else
    echo -e "${ORANGE}SIVIUM SCRIPTS | Configuration for $CONTAINER_NAME already exists. Checking SSL certificate expiration...${NC}"
    check_certificate_expiration
fi
