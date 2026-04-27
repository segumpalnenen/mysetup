#!/bin/bash
# ==========================================
# VPS Management Menu (FINAL CLEAN)
# ==========================================
set -euo pipefail
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; white='\e[1;37m'; cyan='\e[1;36m'; nc='\e[0m'

get_dom() { cat "/usr/local/etc/xray/domain_$1" 2>/dev/null || cat "/usr/local/etc/xray/domain" 2>/dev/null || echo "Not Set"; }

display_header() {
    clear
    MYIP=$(curl -s ifconfig.me || wget -qO- ipv4.icanhazip.com || echo "Unknown")
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}              SYSTEM INFO                ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${white} IP VPS   ${nc}: $MYIP"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}             PROTOCOL DOMAINS            ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${white} SSH/VPN  ${nc}: $(get_dom ssh)"
    echo -e "${white} WS/OVPN  ${nc}: $(get_dom ssh_ws) / $(get_dom ovpn)"
    echo -e "${white} VMESS    ${nc}: $(get_dom vmess)"
    echo -e "${white} VLESS    ${nc}: $(get_dom vless)"
    echo -e "${white} TROJAN   ${nc}: $(get_dom trojan)"
    echo -e "${white} SS WS/GR ${nc}: $(get_dom ss)"
    echo -e "${white} ZIVPN/NS ${nc}: $(get_dom zivpn) / $(get_dom slowdns)"
    echo -e "${red}=========================================${nc}"
}

display_menu() {
    echo -e " 1  : Menu SSH VPN"
    echo -e " 2  : Menu Vmess"
    echo -e " 3  : Menu Vless"
    echo -e " 4  : Menu Trojan"
    echo -e " 5  : Menu Shadowsocks"
    echo -e " 6  : Menu Setting"
    echo -e " 7  : Menu TOR"
    echo -e " 8  : Xray Log"
    echo -e " 9  : Status Service"
    echo -e " 10 : Clear RAM Cache"
    echo -e " 11 : Reboot VPS"
    echo -e " 12 : Menu ZIVPN UDP"
    echo -e " 13 : Menu WireGuard"
    echo -e " x  : Exit Script"
    echo -e "${red}=========================================${nc}"
}

while true; do
    display_header
    display_menu
    read -p " Select menu [1-13, x]: " opt
    case $opt in
        1) m-sshovpn ;;
        2) m-vmess ;;
        3) m-vless ;;
        4) m-trojan ;;
        5) m-ssws ;;
        6) m-system ;;
        7) m-tor ;;
        8) xray-log ;;
        9) running ;;
        10) sync; echo 3 > /proc/sys/vm/drop_caches; echo "OK"; sleep 2 ;;
        11) reboot ;;
        12) menu-zivpn ;;
        13) m-wg ;;
        x|X) exit 0 ;;
        *) echo "Invalid"; sleep 1 ;;
    esac
done
