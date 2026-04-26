#!/bin/bash
# Command: renew-zivpn

ZIVPN_DIR="/etc/zivpn"
USERS_DB="$ZIVPN_DIR/users.db"

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;33m       RENEW ZIVPN UDP USER        \033[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

read -rp "Username to Renew: " username
if ! grep -q "^$username|" "$USERS_DB"; then
    echo "Error: User not found!"
    exit 1
fi

read -rp "Add days: " add_days
old_exp=$(grep "^$username|" "$USERS_DB" | cut -d'|' -f3)
pass=$(grep "^$username|" "$USERS_DB" | cut -d'|' -f2)

if [[ "$old_exp" == "unlimited" ]]; then
    new_exp="unlimited"
else
    today=$(date +%Y-%m-%d)
    if [[ "$old_exp" < "$today" ]]; then
        new_exp=$(date -d "+$add_days days" +%Y-%m-%d)
    else
        new_exp=$(date -d "$old_exp +$add_days days" +%Y-%m-%d)
    fi
fi

sed -i "s/^$username|$pass|$old_exp/$username|$pass|$new_exp/" "$USERS_DB"
echo -e "\033[0;32mSuccess! User renewed until $new_exp\033[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
