#!/bin/bash
# =========================================
# INSTALL ZIVPN UDP (FULL GITHUB VERSION - FIXED)
# =========================================

# Colors
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

# REPOSITORY URL
REPO="https://raw.githubusercontent.com/segumpalnenen/mysetup/master"

# 1. Preparation
ZIVPN_DIR="/etc/zivpn"
ZIVPN_BIN="/usr/local/bin/zivpn"
mkdir -p "$ZIVPN_DIR"

# Stop service to avoid "Text file busy"
systemctl stop zivpn.service > /dev/null 2>&1

# 2. Download Binary
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    BINARY_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    BINARY_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
fi

echo -e "[ INFO ] Downloading Zivpn binary..."
wget -O "$ZIVPN_BIN" "$BINARY_URL"
chmod +x "$ZIVPN_BIN"

# 3. Generate SSL Cert
echo -e "[ INFO ] Generating SSL Certificate..."
if [[ ! -f "$ZIVPN_DIR/zivpn.crt" ]]; then
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=US/ST=CA/L=LA/O=ZIVPN/CN=zivpn" \
        -keyout "$ZIVPN_DIR/zivpn.key" -out "$ZIVPN_DIR/zivpn.crt" > /dev/null 2>&1
fi

# 4. Initial Config & DB
touch "$ZIVPN_DIR/users.db"
if [[ ! -f "$ZIVPN_DIR/config.json" ]]; then
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
fi

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

# 6. Setup Iptables
IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(S+)' | head -1)
if [[ -n "$IFACE" ]]; then
    iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 10000:30000 -j DNAT --to-destination :5667 2>/dev/null || true
fi

# 7. Install Command Scripts FROM GITHUB
echo -e "[ INFO ] Installing command scripts from GitHub..."
commands=("add-zivpn" "del-zivpn" "cek-zivpn" "renew-zivpn" "menu-zivpn")

for cmd in "${commands[@]}"; do
    echo -e " - Downloading $cmd..."
    wget -O "/usr/bin/$cmd" "$REPO/zivpn/$cmd.sh"
    chmod +x "/usr/bin/$cmd"
done
ln -sf /usr/bin/menu-zivpn /usr/bin/zivpn

echo -e "${green}ZIVPN Installation Finished Successfully!${nc}"
