#!/bin/bash
# =========================================
# AUTO CREATE DNS RECORDS CLOUDFLARE (REFINED)
# =========================================
set -euo pipefail
red='\e[1;31m'; green='\e[0;32m'; blue='\e[1;34m'; nc='\e[0m'

IP=$(wget -qO- ipv4.icanhazip.com || curl -s ifconfig.me)
BASE_DOMAIN=$1
SERVER_CODE=$2
CF_TOKEN=$3

# Get Zone ID
ZONE_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN&status=active" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

create_or_update() {
    local NAME=$1; local CONTENT=$2; local TYPE=${3:-A}
    local RECORD_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${NAME}&type=${TYPE}" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')
    local DATA="{\"type\":\"${TYPE}\",\"name\":\"${NAME}\",\"content\":\"${CONTENT}\",\"ttl\":120,\"proxied\":false}"
    if [[ -z "$RECORD_ID" ]]; then
        curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" -H "Authorization: Bearer ${CF_TOKEN}" -H "Content-Type: application/json" --data "$DATA" > /dev/null
    else
        curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" -H "Authorization: Bearer ${CF_TOKEN}" -H "Content-Type: application/json" --data "$DATA" > /dev/null
    fi
}

# --- UNIFIED DNS MAPPING ---
create_or_update "${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"           # Main/SSH
create_or_update "ws-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # SSH WS
create_or_update "vm-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # Vmess
create_or_update "vl-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # Vless
create_or_update "tr-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # Trojan
create_or_update "ss-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # Shadowsocks
create_or_update "ovpn-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"      # OpenVPN
create_or_update "zi-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"        # ZIVPN

# NS RECORD FIX: ns-sgp1.domain.com points to sgp1.domain.com
create_or_update "ns-${SERVER_CODE}.${BASE_DOMAIN}" "${SERVER_CODE}.${BASE_DOMAIN}" "NS"

echo -e "${green}DNS records for all protocols created successfully!${nc}"
