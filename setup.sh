#!/bin/bash
# =========================================
# setup (ULTRA-SAFE GITHUB VERSION)
# =========================================

# Colors
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

# 1. Branch Detection
REPO_BASE="https://raw.githubusercontent.com/segumpalnenen/mysetup"
echo -e "[ INFO ] Checking repository branch..."
if wget --spider -q "$REPO_BASE/master/setup.sh"; then
    BRANCH="master"
elif wget --spider -q "$REPO_BASE/main/setup.sh"; then
    BRANCH="main"
else
    echo -e "${red}[ ERROR ] Repositori tidak ditemukan atau private!${nc}"
    exit 1
fi
REPO="$REPO_BASE/$BRANCH"
echo -e "[ INFO ] Using Branch: $BRANCH"

# Status Tracking
INSTALL_STATUS="/var/log/install-status.log"
echo "--- INSTALLATION REPORT $(date) ---" > "$INSTALL_STATUS"

safe_install() {
    local name=$1
    local folder_path=$2
    local script_name=$(basename "$folder_path")
    
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    echo -e "${yellow}  Installing $name...${nc}"
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    
    if wget -O "$script_name" "$REPO/$folder_path"; then
        if [[ -s "$script_name" ]]; then
            chmod +x "$script_name"
            if ./"$script_name"; then
                echo -e "$name: SUCCESS" >> "$INSTALL_STATUS"
            else
                echo -e "$name: FAILED (Execution Error)" >> "$INSTALL_STATUS"
            fi
            rm -f "$script_name"
        else
            echo -e "$name: FAILED (File 404/Empty)" >> "$INSTALL_STATUS"
            rm -f "$script_name"
        fi
    else
        echo -e "$name: FAILED (Download Error)" >> "$INSTALL_STATUS"
    fi
}

# Setup domains
mkdir -p /usr/local/etc/xray
read -rp "Enter Base Domain (e.g., google.com): " basedom
read -rp "Enter Server Code (e.g., sg1): " kode

# Save domains
for p in domain domain_vmess domain_vless domain_trojan domain_ssh domain_slowdns domain_zivpn; do
    echo "${kode}.${basedom}" > "/usr/local/etc/xray/$p"
done
# override specific if needed
echo "vm${kode}.${basedom}" > /usr/local/etc/xray/domain_vmess
echo "vl${kode}.${basedom}" > /usr/local/etc/xray/domain_vless
echo "ns${kode}.${basedom}" > /usr/local/etc/xray/domain_slowdns

# --- START INSTALLATION ---
safe_install "SSH VPN" "ssh/ssh-vpn.sh"
safe_install "XRAY" "xray/ins-xray.sh"
safe_install "SSH WS" "ws/install-ws.sh"
safe_install "OpenVPN" "openvpn/openvpn.sh"
safe_install "SlowDNS" "slowdns/slowdns.sh"
safe_install "ZIVPN" "zivpn/ins-zivpn.sh"

# Finalize
apt install -y netfilter-persistent iptables-persistent
cat > /root/.profile <<'EOF'
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
mesg n || true
clear
menu
EOF

echo -e "${green}Instalasi selesai! SIlakan cek /var/log/install-status.log${nc}"
sleep 2
reboot
