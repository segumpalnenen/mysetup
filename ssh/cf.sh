#!/bin/bash
# =========================================
# AUTO CREATE DNS RECORDS CLOUDFLARE
# =========================================
set -euo pipefail

# Colors
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

# Config
IP=$(wget -qO- ipv4.icanhazip.com || curl -s ifconfig.me)
SAVED_TOKEN=$(cat /etc/cf_token 2>/dev/null || echo "")

# Parameters
BASE_DOMAIN=$1
SERVER_CODE=$2
CF_TOKEN=${3:-$SAVED_TOKEN}

if [[ -z "$BASE_DOMAIN" || -z "$SERVER_CODE" || -z "$CF_TOKEN" ]]; then
    echo -e "${red}Error: Missing parameters!${nc}"
    echo "Usage: ./cf.sh [base_domain] [server_code] [token]"
    exit 1
fi

log() { echo -e "[${blue}INFO${nc}] $*"; }

# Get Zone ID
log "Fetching Zone ID for $BASE_DOMAIN..."
ZONE_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN&status=active" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ "$ZONE_ID" == "null" || -z "$ZONE_ID" ]]; then
    echo -e "${red}Error: Zone ID not found for domain $BASE_DOMAIN${nc}"
    exit 1
fi

create_or_update() {
    local NAME=$1
    local CONTENT=$2
    local RECORD_ID
    
    RECORD_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${NAME}" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')

    if [[ -z "$RECORD_ID" ]]; then
        # Create
        curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${CF_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${NAME}\",\"content\":\"${CONTENT}\",\"ttl\":120,\"proxied\":false}" > /dev/null
        log "Created A record: ${green}$NAME${nc} -> $CONTENT"
    else
        # Update
        curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
            -H "Authorization: Bearer ${CF_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${NAME}\",\"content\":\"${CONTENT}\",\"ttl\":120,\"proxied\":false}" > /dev/null
        log "Updated A record: ${green}$NAME${nc} -> $CONTENT"
    fi
}

log "Starting DNS record automation for IP: $IP"

# List of subdomains to create
# vmsg1.domain, vlsg1.domain, trsg1.domain, sg1.domain, wssg1.domain, ovpnsg1.domain, nssg1.domain, zisg1.domain
create_or_update "vm${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "vl${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "tr${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "ws${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "ovpn${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "ns${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "zi${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "ss${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "ssws${SERVER_CODE}.${BASE_DOMAIN}" "$IP"
create_or_update "ssgr${SERVER_CODE}.${BASE_DOMAIN}" "$IP"

log "${green}All DNS records processed successfully!${nc}"
