#!/bin/bash
# Command: del-zivpn

ZIVPN_DIR="/etc/zivpn"
USERS_DB="$ZIVPN_DIR/users.db"
CONFIG_FILE="$ZIVPN_DIR/config.json"

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;31m       DELETE ZIVPN UDP USER       \033[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# List users
grep "|" "$USERS_DB" | cut -d'|' -f1

read -rp "Input Username to Delete: " username

if ! grep -q "^$username|" "$USERS_DB"; then
    echo "Error: User '$username' not found!"
    exit 1
fi

sed -i "/^$username|/d" "$USERS_DB"

# Update config.json
passwords=()
while IFS='|' read -r uname pass exp; do
    passwords+=("\"$pass\"")
done < "$USERS_DB"
pass_list=$(IFS=','; echo "${passwords[*]:-\"zivpn\"}")

cat > "$CONFIG_FILE" <<EOF
{
  "listen": ":5667",
  "cert": "$ZIVPN_DIR/zivpn.crt",
  "key": "$ZIVPN_DIR/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": [$pass_list]
  }
}
EOF

systemctl restart zivpn
echo -e "\033[0;32mUser '$username' deleted successfully.\033[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
