#!/bin/bash
set -euo pipefail

# Map OpenWrt platform → AdGuardHome arch
case "${platform:-}" in
    x86_64)
        AGH_ARCH="amd64"
        ;;
    armv8|rk3399|rk3568|rk3576)
        AGH_ARCH="arm64"
        ;;
    *)
        echo "[AdGuardHome] Unsupported platform: ${platform:-unset}, skip."
        exit 0
        ;;
esac

mkdir -p files/usr/bin

AGH_CORE=$(curl -sL https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep "browser_download_url.*AdGuardHome_linux_${AGH_ARCH}.tar.gz" | head -n1 | awk -F '"' '{print $4}')

# wget -qO- $AGH_CORE | tar xOvz > files/usr/bin/AdGuardHome
curl -L "${AGH_CORE}" | tar -xzO "AdGuardHome/AdGuardHome" > files/usr/bin/AdGuardHome

chmod +x files/usr/bin/AdGuardHome

