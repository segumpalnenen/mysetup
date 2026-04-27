#!/bin/bash
# =========================================
# AUTO CREATE DNS RECORDS CLOUDFLARE (UNIFIED FORMAT)
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

log() { echo -e "[${blue}INFO${nc}] $*"; }

# Get Zone ID
ZONE_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN&status=active" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ "$ZONE_ID" == "null" || -z "$ZONE_ID" ]]; then
    echo -e "${red}Error: Zone ID not found!${nc}"; exit 1
fi

create_or_update() {
    local NAME=$1
    local CONTENT=$2
    local TYPE=${3:-A}
    local RECORD_ID
    
    RECORD_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${NAME}&type=${TYPE}" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')

    local DATA="{\"type\":\"${TYPE}\",\"name\":\"${NAME}\",\"content\":\"${CONTENT}\",\"ttl\":120,\"proxied\":false}"

    if [[ -z "$RECORD_ID" ]]; then
        curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${CF_TOKEN}" \
            -H "Content-Type: application/json" --data "$DATA" > /dev/null
        log "Created $TYPE record: ${green}$NAME${nc}"
    else
        curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
            -H "Authorization: Bearer ${CF_TOKEN}" \
            -H "Content-Type: application/json" --data "$DATA" > /dev/null
        log "Updated $TYPE record: ${green}$NAME${nc}"
    fi
}

log "Starting DNS automation for IP: $IP"

# --- MAPPING SUBDOMAINS (Unified Format: service-code.domain) ---
create_or_update "${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"           # Main/SSH
create_or_update "ws-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # SSH WS
create_or_update "vm-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # Vmess
create_or_update "vl-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # Vless
create_or_update "tr-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # Trojan
create_or_update "zi-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # Zivpn
create_or_update "ss-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # Shadowsocks
create_or_update "ovpn-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"      # OpenVPN

# --- SLOWDNS NS RECORD ---
NS_HOST="ns-${SERVER_CODE}.${BASE_DOMAIN}"
MAIN_HOST="${SERVER_CODE}.${BASE_DOMAIN}"
create_or_update "$NS_HOST" "$MAIN_HOST" "NS"

# Save local copy for reference
echo "$NS_HOST" > /root/nsdomain

log "${green}All subdomains standardized and processed successfully!${nc}"
