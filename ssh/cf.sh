#!/bin/bash
# =========================================
# AUTO CREATE DNS RECORDS CLOUDFLARE (ULTRA-FIX)
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
MAIN_HOST="${SERVER_CODE}.${BASE_DOMAIN}"
create_or_update "$MAIN_HOST" "$IP" "A"
create_or_update "ws-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"
create_or_update "vm-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"
create_or_update "vl-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"
create_or_update "tr-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"
create_or_update "ss-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"
create_or_update "ovpn-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"
create_or_update "zi-${SERVER_CODE}.${BASE_DOMAIN}" "$IP" "A"

# SLOWDNS NS RECORD FIX
NS_HOST="ns-${SERVER_CODE}.${BASE_DOMAIN}"
create_or_update "$NS_HOST" "$MAIN_HOST" "NS"

# Save references
echo "$NS_HOST" > /root/nsdomain
echo "$NS_HOST" > /usr/local/etc/xray/domain_slowdns

echo -e "${green}DNS records (including NS: $NS_HOST) created successfully!${nc}"
