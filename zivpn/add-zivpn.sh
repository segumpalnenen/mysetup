#!/bin/bash
# Command: add-zivpn [username] [password] [days]

ZIVPN_DIR="/etc/zivpn"
USERS_DB="$ZIVPN_DIR/users.db"
CONFIG_FILE="$ZIVPN_DIR/config.json"

# Check if arguments are provided, if not use interactive
if [[ $# -eq 3 ]]; then
    username=$1
    password=$2
    days=$3
else
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;33m       ADD ZIVPN UDP USER          \033[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    read -rp "Username : " username
    read -rp "Password : " password
    read -rp "Expired (days): " days
fi

if grep -q "^$username|" "$USERS_DB" 2>/dev/null; then
    echo "Error: User '$username' already exists!"
    exit 1
fi

if [[ "$days" == "0" ]]; then
    expiry="unlimited"
else
    expiry=$(date -d "+$days days" +%Y-%m-%d)
fi

echo "$username|$password|$expiry" >> "$USERS_DB"

# Update config.json
passwords=()
while IFS='|' read -r uname pass exp; do
    passwords+=("\"$pass\"")
done < "$USERS_DB"
pass_list=$(IFS=','; echo "${passwords[*]}")

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

echo -e "\033[0;32mSuccess! User created.\033[0m"
echo -e "Username : $username"
echo -e "Password : $password"
echo -e "Expired  : $expiry"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
