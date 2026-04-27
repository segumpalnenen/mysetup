#!/bin/bash
# =========================================
# setup (ULTRA-DEBUG & FULL GITHUB VERSION)
# =========================================

# 1. Inisialisasi Logging Global
LOG_FILE="/var/log/install.log"
INSTALL_STATUS="/var/log/install-status.log"
touch "$LOG_FILE"
touch "$INSTALL_STATUS"

# Redirect semua output ke log file dan terminal
exec > >(tee -a "$LOG_FILE") 2>&1

# Colors
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e "${yellow}      LOGGING STARTED: $LOG_FILE         ${nc}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"

# 2. Branch Detection
REPO_BASE="https://raw.githubusercontent.com/segumpalnenen/mysetup"
echo -e "[ INFO ] Checking repository branch..."
if wget --spider -q "$REPO_BASE/master/setup.sh"; then
    BRANCH="master"
else
    BRANCH="main"
fi
REPO="$REPO_BASE/$BRANCH"
echo -e "[ INFO ] Using Branch: $BRANCH"

safe_install() {
    local name=$1
    local folder_path=$2
    local script_name=$(basename "$folder_path")
    
    echo -e "\n${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    echo -e "${yellow}  Installing $name...${nc}"
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    
    if wget -O "$script_name" "$REPO/$folder_path"; then
        if [[ -s "$script_name" ]]; then
            chmod +x "$script_name"
            if ./"$script_name"; then
                echo -e "$name: SUCCESS" >> "$INSTALL_STATUS"
            else
                echo -e "${red}[ ERROR ] $name execution failed!${nc}"
                echo -e "$name: FAILED (Script Error)" >> "$INSTALL_STATUS"
            fi
            rm -f "$script_name"
        else
            echo -e "${red}[ ERROR ] $name file is empty (404)${nc}"
            echo -e "$name: FAILED (Empty File)" >> "$INSTALL_STATUS"
        fi
    else
        echo -e "${red}[ ERROR ] Failed to download $name${nc}"
        echo -e "$name: FAILED (Download Error)" >> "$INSTALL_STATUS"
    fi
}

# Timezone & Tools
timedatectl set-timezone Asia/Jakarta
timedatectl set-ntp true
apt update && apt install -y curl wget jq net-tools psmisc

# Setup domains & Token
mkdir -p /usr/local/etc/xray
read -rp "Enter Base Domain: " basedom
read -rp "Enter Server Code: " kode
read -rp "Enter Cloudflare Token: " cf_token
echo "$cf_token" > /etc/cf_token && chmod 600 /etc/cf_token

# Save domains
for p in domain domain_vmess domain_vless domain_trojan domain_ssh domain_slowdns domain_zivpn domain_ssh_ws; do
    echo "${kode}.${basedom}" > "/usr/local/etc/xray/$p"
done
echo "vm${kode}.${basedom}" > /usr/local/etc/xray/domain_vmess
echo "vl${kode}.${basedom}" > /usr/local/etc/xray/domain_vless
echo "ws-${kode}.${basedom}" > /usr/local/etc/xray/domain_ssh_ws
echo "ns-${kode}.${basedom}" > /usr/local/etc/xray/domain_slowdns

# --- DNS AUTOMATION ---
wget -O cf.sh "$REPO/ssh/cf.sh" && chmod +x cf.sh
./cf.sh "$basedom" "$kode" "$cf_token"
rm -f cf.sh

# --- START INSTALLATION ---
safe_install "SSH VPN" "ssh/ssh-vpn.sh"
safe_install "XRAY" "xray/ins-xray.sh"
safe_install "SSH WS" "ws/install-ws.sh"
safe_install "OpenVPN" "openvpn/openvpn.sh"
safe_install "SlowDNS" "slowdns/slowdns.sh"
safe_install "WireGuard" "wireguard/wg.sh"
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

echo -e "\n${green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e "${green}         INSTALLATION COMPLETED          ${nc}"
echo -e "${green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e " Full Log   : $LOG_FILE"
echo -e " Status     : /var/log/install-status.log"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 5
reboot
