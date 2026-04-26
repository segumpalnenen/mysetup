#!/bin/bash
# =========================================
# setup (FULL GITHUB VERSION - IMPROVED)
# =========================================

# Color
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

# REPOSITORY URL
REPO="https://raw.githubusercontent.com/segumpalnenen/mysetup/master"

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
    
    # Download tanpa -q untuk debugging
    if wget -O "$script_name" "$REPO/$folder_path"; then
        chmod +x "$script_name"
        echo -e "[ INFO ] Running $script_name..."
        if ./"$script_name"; then
            echo -e "$name: SUCCESS" >> "$INSTALL_STATUS"
        else
            echo -e "$name: FAILED (Script Error)" >> "$INSTALL_STATUS"
        fi
        rm -f "$script_name"
    else
        echo -e "$name: FAILED (Download Error)" >> "$INSTALL_STATUS"
        echo -e "${red}[ ERROR ] Gagal mendownload $name dari GitHub!${nc}"
        echo -e "URL: $REPO/$folder_path"
    fi
}

# Timezone
timedatectl set-timezone Asia/Jakarta
timedatectl set-ntp true

# Setup domains
mkdir -p /usr/local/etc/xray
read -rp "Enter Base Domain: " basedom
read -rp "Enter Server Code: " kode

echo "${kode}.${basedom}" > /usr/local/etc/xray/domain
echo "vm${kode}.${basedom}" > /usr/local/etc/xray/domain_vmess
echo "vl${kode}.${basedom}" > /usr/local/etc/xray/domain_vless
echo "tr${kode}.${basedom}" > /usr/local/etc/xray/domain_trojan
echo "${kode}.${basedom}" > /usr/local/etc/xray/domain_ssh
echo "ns${kode}.${basedom}" > /usr/local/etc/xray/domain_slowdns
echo "zi${kode}.${basedom}" > /usr/local/etc/xray/domain_zivpn

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

echo -e "${green}Instalasi selesai! Laporan: /var/log/install-status.log${nc}"
sleep 2
reboot
