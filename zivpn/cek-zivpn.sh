#!/bin/bash
# Command: cek-zivpn

ZIVPN_DIR="/etc/zivpn"
USERS_DB="$ZIVPN_DIR/users.db"

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;36m       LIST ZIVPN UDP USER         \033[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
printf "\033[1;37m%-15s %-15s %-15s\033[0m\n" "USERNAME" "PASSWORD" "EXPIRED"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

today=$(date +%Y-%m-%d)
while IFS='|' read -r uname pass expiry; do
    if [[ "$expiry" != "unlimited" && "$expiry" < "$today" ]]; then
        exp_status="\033[0;31m$expiry (Exp)\033[0m"
    else
        exp_status="\033[0;32m$expiry\033[0m"
    fi
    printf "%-15s %-15s %b\n" "$uname" "$pass" "$exp_status"
done < "$USERS_DB"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
