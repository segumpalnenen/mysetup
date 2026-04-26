#!/bin/bash
# =========================================
# setup
# =========================================

# color
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
white='\e[1;37m'
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

# delete old
rm -f cf.sh >/dev/null 2>&1
rm -f ssh-vpn.sh >/dev/null 2>&1
rm -f ins-xray.sh >/dev/null 2>&1
rm -f udp-custom.sh >/dev/null 2>&1
rm -f slowdns.sh >/dev/null 2>&1

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Script need run AS root...!"
    exit 1
fi

# Detect OS
if [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/lsb-release ]; then
    OS="ubuntu"
else
    print_error "OS Not Support. Script for OS Debian/Ubuntu."
    exit 1
fi

# -------------------------------
# 1️⃣ Set timezone ke Asia/Jakarta
# -------------------------------
echo "Setting timezone to Asia/Jakarta..."
timedatectl set-timezone Asia/Jakarta
echo "Timezone set:"
timedatectl | grep "Time zone"

# -------------------------------
# 2️⃣ Enable NTP (auto-sync waktu)
# -------------------------------
echo "Enabling NTP..."
timedatectl set-ntp true
# Cek status sinkronisasi
timedatectl status | grep -E "NTP enabled|NTP synchronized" || true

echo ""

# -------------------------------
# 3️⃣ Install & enable cron
# -------------------------------
if ! systemctl list-unit-files | grep -q '^cron.service'; then
    echo "Cron not found. Installing cron..."
    apt update -y
    apt install -y cron
fi

echo "Enabling and starting cron service..."
systemctl enable cron
systemctl restart cron

echo ""
echo "✅ VPS timezone, NTP, and cron setup complete!"

# create folder
mkdir -p /usr/local/etc/xray
mkdir -p /etc/log

MYIP=$(wget -qO- ipv4.icanhazip.com || curl -s ifconfig.me)
clear
echo -e "${red}=========================================${nc}"
echo -e "${green}    AUTOMATIC SUBDOMAIN GENERATOR       ${nc}"
echo -e "${red}=========================================${nc}"
read -rp "Enter Base Domain (e.g. myvpn.com): " basedom
read -rp "Enter Server Code (e.g. sg1): " kode
echo -e "${red}=========================================${nc}"

# Create Folder
mkdir -p /usr/local/etc/xray

# Function to save domain
set_dom() { echo "$1" > "/usr/local/etc/xray/$2"; }

# Generate and Save All Domains
set_dom "vm${kode}.${basedom}" "domain_vmess"
set_dom "vl${kode}.${basedom}" "domain_vless"
set_dom "tr${kode}.${basedom}" "domain_trojan"
set_dom "${kode}.${basedom}" "domain_ssh"
set_dom "ws${kode}.${basedom}" "domain_ssh_ws"
set_dom "ovpn${kode}.${basedom}" "domain_ovpn"
set_dom "ns${kode}.${basedom}" "domain_slowdns"
set_dom "zi${kode}.${basedom}" "domain_zivpn"
set_dom "ss${kode}.${basedom}" "domain_ss"
set_dom "ssws${kode}.${basedom}" "domain_ssws"
set_dom "ssgr${kode}.${basedom}" "domain_ssgr"
set_dom "vmgr${kode}.${basedom}" "domain_vmgr"
set_dom "vlgr${kode}.${basedom}" "domain_vlgr"
set_dom "trgr${kode}.${basedom}" "domain_trgr"

# Set default for legacy scripts
echo "${kode}.${basedom}" > /usr/local/etc/xray/domain

echo -e "${green}All subdomains generated successfully!${nc}"
echo -e "Sample: vmess -> vm${kode}.${basedom}"
sleep 2

echo -e "${green}Done${nc}"

# Status Tracking
INSTALL_STATUS="/var/log/install-status.log"
echo "--- INSTALLATION REPORT $(date) ---" > "$INSTALL_STATUS"

safe_install() {
    local name=$1
    local cmd=$2
    echo -e "${blue}[ INFO ]${nc} Memulai instalasi $name..."
    if eval "$cmd"; then
        echo -e "$name: ${green}SUCCESS${nc}" >> "$INSTALL_STATUS"
        echo -e "${green}[ OK ]${nc} $name terpasang."
    else
        echo -e "$name: ${red}FAILED${nc}" >> "$INSTALL_STATUS"
        echo -e "${red}[ WARN ]${nc} $name gagal diinstal, melanjutkan ke bagian lain..."
    fi
}

# --- Mulai Instalasi Komponen ---

echo -e "${blue}Menginstal Komponen...${nc}"

safe_install "SSH VPN" "./ssh-vpn.sh"
safe_install "XRAY" "./ins-xray.sh"
safe_install "SSH WS" "./install-ws.sh"
safe_install "OpenVPN" "./openvpn.sh"
safe_install "SlowDNS" "./slowdns.sh"

# Zivpn logic (with folder check)
if [[ -d "./zivpn" ]]; then
    cd zivpn
    safe_install "ZIVPN" "./ins-zivpn.sh"
    cd ..
else
    safe_install "ZIVPN" "wget -q https://raw.githubusercontent.com/segumpalnenen/mysetup/master/zivpn/ins-zivpn.sh && chmod +x ins-zivpn.sh && ./ins-zivpn.sh"
fi

# ==========================================
# INSTALL WEBSOCKET PROXY.JS
# ==========================================
LOG_FILE="/var/log/ws-proxy-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================="
echo "Starting WebSocket Proxy.js installation..."
echo "========================================="

# -------------------------------
# Set non-interactive mode
# -------------------------------
export DEBIAN_FRONTEND=noninteractive

# -------------------------------
# Update & Install dependencies
# -------------------------------
echo "[STEP 1] Updating system and installing packages..."
apt update -y || true
apt upgrade -y || true
apt install -y wget curl lsof net-tools ufw build-essential || true
# -------------------------------
# Install Node.js
# -------------------------------
echo "[STEP 2] Checking Node.js version..."
apt remove -y nodejs npm || true
NODE_VERSION=$(node -v 2>/dev/null || echo "v0")
NODE_MAJOR=${NODE_VERSION#v}
NODE_MAJOR=${NODE_MAJOR%%.*}

if [[ $NODE_MAJOR -lt 16 ]]; then
    echo "Node.js version too old ($NODE_VERSION). Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - || true
    apt install -y nodejs || true
else
    echo "Node.js version is sufficient ($NODE_VERSION)"
fi

# -------------------------------
# Download proxy.js
# -------------------------------
echo "[STEP 3] Downloading proxy.js..."
rm -f /usr/local/bin/proxy.js
wget -q -O /usr/local/bin/proxy.js https://raw.githubusercontent.com/segumpalnenen/mysetup/master/ws-stunnel/proxy.js
chmod +x /usr/local/bin/proxy.js
echo "[STEP 3] proxy.js installed at /usr/local/bin/proxy.js"

# -------------------------------
# Download systemd service
# -------------------------------
echo "[STEP 4] Setting up ws-proxy systemd service..."
rm -f /etc/systemd/system/ws-proxy.service
wget -q -O /etc/systemd/system/ws-proxy.service https://raw.githubusercontent.com/segumpalnenen/mysetup/master/ws-stunnel/ws-proxy.service
chmod 644 /etc/systemd/system/ws-proxy.service

cd /usr/local/bin
npm install ws
npm init -y

# Reload systemd to recognize new service
systemctl daemon-reload || true

# Enable and start ws-proxy service
systemctl enable ws-proxy || true
systemctl restart ws-proxy || true

# -------------------------------
# Verify service
# -------------------------------
if systemctl is-active --quiet ws-proxy; then
    echo "[STEP 5] ws-proxy service is active and running."
else
    echo "[WARNING] ws-proxy service failed to start. Check logs with: journalctl -u ws-proxy -f"
fi

# -------------------------------
# Final message
# -------------------------------
echo "========================================="
echo "WebSocket Proxy.js installation complete!"
echo "You can check the service status: systemctl status ws-proxy"
echo "========================================="

echo -e "${red}=========================================${nc}"
echo -e "${blue}           Install OpenVPN              ${nc}"
echo -e "${red}=========================================${nc}"
# install tor openvpn
wget https://raw.githubusercontent.com/segumpalnenen/mysetup/master/openvpn/openvpn.sh && chmod +x openvpn.sh && ./openvpn.sh

echo -e "${red}=========================================${nc}"
echo -e "${blue}           Install SlowDNS              ${nc}"
echo -e "${red}=========================================${nc}"
# install slowdns otomatis
wget https://raw.githubusercontent.com/segumpalnenen/mysetup/master/slowdns/slowdns.sh && chmod +x slowdns.sh && ./slowdns.sh

echo -e "${red}=========================================${nc}"
echo -e "${blue}           Install UDP CUSTOM           ${nc}"
echo -e "${red}=========================================${nc}"
# install udp-custom dengan exclude port Zivpn agar tidak bentrok
wget https://raw.githubusercontent.com/segumpalnenen/mysetup/master/udp-custom/udp-custom.sh && chmod +x udp-custom.sh && ./udp-custom.sh "53 5300 7100 7200 7300 7400 7500 7600 7700 7800 7900 10000-30000"


echo -e "${red}=========================================${nc}"
echo -e "${blue}          Install ZIVPN UDP             ${nc}"
echo -e "${red}=========================================${nc}"
# install zivpn udp modular
cd /root/result/zivpn
chmod +x ins-zivpn.sh
./ins-zivpn.sh

cat > /root/.profile <<'EOF'
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
command -v menu >/dev/null 2>&1 && menu
EOF

apt install -y netfilter-persistent iptables-persistent
# Flush
iptables -L INPUT -n --line-numbers
# Allow loopback
iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || \
iptables -I INPUT -i lo -j ACCEPT
# Allow established connections
iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Allow SSH & Dropbear
iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
iptables -C INPUT -p tcp --dport 2222 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 2222 -j ACCEPT
iptables -C INPUT -p tcp --dport 109 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 109 -j ACCEPT
iptables -C INPUT -p tcp --dport 110 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 110 -j ACCEPT
iptables -C INPUT -p tcp --dport 222 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 222 -j ACCEPT
iptables -C INPUT -p tcp --dport 333 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 333 -j ACCEPT
iptables -C INPUT -p tcp --dport 444 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 444 -j ACCEPT
iptables -C INPUT -p tcp --dport 777 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 777 -j ACCEPT
iptables -C INPUT -p tcp --dport 8443 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 8443 -j ACCEPT
# Allow HTTP/HTTPS
iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
# Allow HTTP/HTTPS nginx
iptables -C INPUT -p tcp --dport 8080 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
iptables -C INPUT -p tcp --dport 4433 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 4433 -j ACCEPT
# Allow WebSocket ports
iptables -C INPUT -p tcp --dport 1444 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 1444 -j ACCEPT
iptables -C INPUT -p tcp --dport 1445 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 1445 -j ACCEPT
# Save
netfilter-persistent save
# chattr +i /etc/iptables/rules.v4
netfilter-persistent reload

systemctl enable netfilter-persistent
systemctl start netfilter-persistent

echo ""
echo -e "========================================="  | tee -a ~/log-install.txt
echo -e "          Service Information            "  | tee -a ~/log-install.txt
echo -e "========================================="  | tee -a ~/log-install.txt
echo ""
echo "   >>> Service & Port"  | tee -a ~/log-install.txt
echo "   - OpenSSH                  : 22, 2222"  | tee -a ~/log-install.txt
echo "   - Dropbear                 : 109, 110" | tee -a ~/log-install.txt
echo "   - SSH Websocket            : 80, 1445" | tee -a ~/log-install.txt
echo "   - SSH SSL Websocket        : 444, 1444" | tee -a ~/log-install.txt
echo "   - Stunnel4                 : 222, 333, 777" | tee -a ~/log-install.txt
echo "   - Badvpn                   : 7100-7900" | tee -a ~/log-install.txt
echo "   - OpenVPN                  : 443, 1195, 51825" | tee -a ~/log-install.txt
echo "   - SlowDNS                  : 53, 2200, 2299" | tee -a ~/log-install.txt
echo "   - ZIVPN UDP                : 5667, 10000-30000" | tee -a ~/log-install.txt
echo "   - Nginx                    : 80" | tee -a ~/log-install.txt
echo "   - Vmess WS TLS             : 443" | tee -a ~/log-install.txt
echo "   - Vless WS TLS             : 443" | tee -a ~/log-install.txt
echo "   - Trojan WS TLS            : 443" | tee -a ~/log-install.txt
echo "   - Shadowsocks WS TLS       : 443" | tee -a ~/log-install.txt
echo "   - Vmess WS none TLS        : 80" | tee -a ~/log-install.txt
echo "   - Vless WS none TLS        : 80" | tee -a ~/log-install.txt
echo "   - Trojan WS none TLS       : 80" | tee -a ~/log-install.txt
echo "   - Shadowsocks WS none TLS  : 80" | tee -a ~/log-install.txt
echo "   - Vmess gRPC               : 443" | tee -a ~/log-install.txt
echo "   - Vless gRPC               : 443" | tee -a ~/log-install.txt
echo "   - Trojan gRPC              : 443" | tee -a ~/log-install.txt
echo "   - Shadowsocks gRPC         : 443" | tee -a ~/log-install.txt
echo ""
echo -e "=========================================" | tee -a ~/log-install.txt
echo -e "               t.me/givps_com            "  | tee -a ~/log-install.txt
echo -e "=========================================" | tee -a ~/log-install.txt
echo ""
echo -e "Auto reboot in 10 seconds..."
sleep 10
clear
reboot
     : 443" | tee -a ~/log-install.txt
echo ""
echo -e "=========================================" | tee -a ~/log-install.txt
echo -e "               t.me/givps_com            "  | tee -a ~/log-install.txt
echo -e "=========================================" | tee -a ~/log-install.txt
echo ""
echo -e "Auto reboot in 10 seconds..."
sleep 10
clear
reboot
