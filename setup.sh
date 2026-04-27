#!/bin/bash
# =========================================
# setup (FINAL REVISED VERSION)
# =========================================

# Logging Global
LOG_FILE="/var/log/install.log"
INSTALL_STATUS="/var/log/install-status.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Colors
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

# Branch Detection
REPO_BASE="https://raw.githubusercontent.com/segumpalnenen/mysetup"
if wget --spider -q "$REPO_BASE/master/setup.sh"; then BRANCH="master"; else BRANCH="main"; fi
REPO="$REPO_BASE/$BRANCH"

safe_install() {
    local name=$1
    local folder_path=$2
    local script_name=$(basename "$folder_path")
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    echo -e "${yellow}  Installing $name...${nc}"
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
    if wget -O "$script_name" "$REPO/$folder_path"; then
        chmod +x "$script_name"
        if ./"$script_name"; then echo -e "$name: SUCCESS" >> "$INSTALL_STATUS"
        else echo -e "$name: FAILED" >> "$INSTALL_STATUS"; fi
        rm -f "$script_name"
    else echo -e "$name: FAILED (Download Error)" >> "$INSTALL_STATUS"; fi
}

# Timezone
timedatectl set-timezone Asia/Jakarta
apt update && apt install -y curl wget jq net-tools psmisc

# Input Data
mkdir -p /usr/local/etc/xray
read -rp "Enter Base Domain: " basedom
read -rp "Enter Server Code: " kode
read -rp "Enter Cloudflare Token: " cf_token
echo "$cf_token" > /etc/cf_token && chmod 600 /etc/cf_token

# --- UNIFIED DOMAIN MAPPING ---
# Format: service-code.domain
echo "${kode}.${basedom}" > /usr/local/etc/xray/domain
echo "ws-${kode}.${basedom}" > /usr/local/etc/xray/domain_ssh_ws
echo "vm-${kode}.${basedom}" > /usr/local/etc/xray/domain_vmess
echo "vl-${kode}.${basedom}" > /usr/local/etc/xray/domain_vless
echo "tr-${kode}.${basedom}" > /usr/local/etc/xray/domain_trojan
echo "ss-${kode}.${basedom}" > /usr/local/etc/xray/domain_ss
echo "ovpn-${kode}.${basedom}" > /usr/local/etc/xray/domain_ovpn
echo "ns-${kode}.${basedom}" > /usr/local/etc/xray/domain_slowdns
echo "zi-${kode}.${basedom}" > /usr/local/etc/xray/domain_zivpn

# Alias untuk gRPC agar tidak pakai domain terpisah
cp /usr/local/etc/xray/domain_vmess /usr/local/etc/xray/domain_vmgr
cp /usr/local/etc/xray/domain_vless /usr/local/etc/xray/domain_vlgr
cp /usr/local/etc/xray/domain_trojan /usr/local/etc/xray/domain_trgr
cp /usr/local/etc/xray/domain_ss /usr/local/etc/xray/domain_ssgr

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

# --- FINALIZING LOG ---
cat > /root/log-install.txt <<EOF
   >>> Service & Port
   - OpenSSH                  : 22, 2222
   - Dropbear                 : 109, 110
   - SSH Websocket            : 80, 1445
   - SSH SSL Websocket        : 444, 1444
   - OpenVPN                  : 443, 1195, 51825
   - WireGuard                : 51820
   - SlowDNS                  : 53, 5300
   - ZIVPN UDP                : 5667, 10000-30000
   - Nginx                    : 80, 8080
EOF

apt install -y netfilter-persistent iptables-persistent
cat > /root/.profile <<'EOF'
if [ "$BASH" ]; then if [ -f ~/.bashrc ]; then . ~/.bashrc; fi; fi
mesg n || true
clear
menu
EOF

echo -e "${green}Instalasi Selesai! Rebooting...${nc}"
sleep 5
reboot
