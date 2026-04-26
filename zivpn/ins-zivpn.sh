#!/bin/bash
# =========================================
# INSTALL ZIVPN UDP (MODULAR VERSION)
# =========================================

# Colors
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# Error logging mechanism
ERROR_LOG="/var/log/install-error.log"
log_err() {
    echo -e "[ $(date) ] ERROR di baris $1: $2" >> "$ERROR_LOG"
    echo -e "${red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    echo -e "${red}          FATAL ERROR DETECTED           ${nc}"
    echo -e "${red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    echo -e "${red} Baris  : $1${nc}"
    echo -e "${red} Command: $2${nc}"
    echo -e "${red} Log    : $ERROR_LOG${nc}"
    echo -e "${red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
}
trap 'log_err $LINENO "$BASH_COMMAND"' ERR

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root!"
   exit 1
fi

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e "${yellow}      INSTALLING ZIVPN UDP SERVER       ${nc}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"

# 1. Preparation
ZIVPN_DIR="/etc/zivpn"
ZIVPN_BIN="/usr/local/bin/zivpn"
mkdir -p "$ZIVPN_DIR"

# 2. Download Binary
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    BINARY_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    BINARY_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
fi

echo -e "[ INFO ] Downloading Zivpn binary..."
wget -q "$BINARY_URL" -O "$ZIVPN_BIN"
chmod +x "$ZIVPN_BIN"

# 3. Generate SSL Cert
echo -e "[ INFO ] Generating SSL Certificate..."
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=US/ST=CA/L=LA/O=ZIVPN/CN=zivpn" \
    -keyout "$ZIVPN_DIR/zivpn.key" -out "$ZIVPN_DIR/zivpn.crt" > /dev/null 2>&1

# 4. Initial Config & DB
touch "$ZIVPN_DIR/users.db"
cat > "$ZIVPN_DIR/config.json" <<EOF
{
  "listen": ":5667",
  "cert": "$ZIVPN_DIR/zivpn.crt",
  "key": "$ZIVPN_DIR/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": ["zivpn"]
  }
}
EOF

# 5. Setup Systemd Service
cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZIVPN UDP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$ZIVPN_DIR
ExecStart=$ZIVPN_BIN server -c $ZIVPN_DIR/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

# 6. Setup Iptables (Port Forwarding)
echo -e "[ INFO ] Configuring Iptables..."
IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(S+)' | head -1)
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 10000:30000 -j DNAT --to-destination :5667
netfilter-persistent save > /dev/null 2>&1

# 7. Install Command Scripts to /usr/bin
echo -e "[ INFO ] Installing command scripts..."
# assuming we are in the script directory or the scripts are in the same folder
cp add-zivpn.sh /usr/bin/add-zivpn
cp del-zivpn.sh /usr/bin/del-zivpn
cp cek-zivpn.sh /usr/bin/cek-zivpn
cp renew-zivpn.sh /usr/bin/renew-zivpn
cp menu-zivpn.sh /usr/bin/menu-zivpn

chmod +x /usr/bin/add-zivpn
chmod +x /usr/bin/del-zivpn
chmod +x /usr/bin/cek-zivpn
chmod +x /usr/bin/renew-zivpn
chmod +x /usr/bin/menu-zivpn
ln -sf /usr/bin/menu-zivpn /usr/bin/zivpn

# 8. Setup Auto-delete Cron
cat > /usr/local/bin/zivpn-cron.sh <<'CRONEOF'
#!/bin/bash
TODAY=$(date +%Y-%m-%d)
USERS_DB="/etc/zivpn/users.db"
CHANGED=0
if [[ ! -f "$USERS_DB" ]]; then exit 0; fi
TMPFILE=$(mktemp)
while IFS='|' read -r uname pass expiry; do
    if [[ "$expiry" != "unlimited" && "$expiry" < "$TODAY" ]]; then
        CHANGED=1
    else
        echo "$uname|$pass|$expiry" >> "$TMPFILE"
    fi
done < "$USERS_DB"
if [[ $CHANGED -eq 1 ]]; then
    mv "$TMPFILE" "$USERS_DB"
    passwords=()
    while IFS='|' read -r uname pass expiry; do
        passwords+=("\"$pass\"")
    done < "$USERS_DB"
    pass_list=$(IFS=','; echo "${passwords[*]:-\"zivpn\"}")
    cat > /etc/zivpn/config.json <<EOF
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": [$pass_list]
  }
}
EOF
    systemctl restart zivpn
else
    rm -f "$TMPFILE"
fi
CRONEOF
chmod +x /usr/local/bin/zivpn-cron.sh
(crontab -l 2>/dev/null | grep -v "zivpn-cron"; echo "0 0 * * * /usr/local/bin/zivpn-cron.sh") | crontab -

echo -e "${green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e "${green}    ZIVPN UDP INSTALLATION COMPLETED     ${nc}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e " Commands:"
echo -e " - menu-zivpn  : Open Zivpn Menu"
echo -e " - add-zivpn   : Add Zivpn User"
echo -e " - del-zivpn   : Delete Zivpn User"
echo -e " - cek-zivpn   : List Zivpn Users"
echo -e " - renew-zivpn : Renew Zivpn User"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
