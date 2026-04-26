#!/bin/bash
# Menu Zivpn

while true; do
    clear
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;33m         ZIVPN UDP MENU            \033[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e " [\033[1;32m1\033[0m] Create User Zivpn"
    echo -e " [\033[1;32m2\033[0m] Delete User Zivpn"
    echo -e " [\033[1;32m3\033[0m] Check User Zivpn"
    echo -e " [\033[1;32m4\033[0m] Renew User Zivpn"
    echo -e " [\033[1;32m0\033[0m] Back to Main Menu"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    read -rp " Select menu : " opt
    case $opt in
        1) add-zivpn ;;
        2) del-zivpn ;;
        3) cek-zivpn ;;
        4) renew-zivpn ;;
        0) menu; break ;;
        *) echo "Invalid option"; sleep 1 ;;
    esac
done
