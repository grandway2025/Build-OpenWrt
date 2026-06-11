#!/bin/bash
set -e

# 创建 OpenClash 核心目录（若不存在则自动创建）
mkdir -p files/etc/openclash/core
mkdir -p files/etc/config

# 根据平台设置 core 架构
case "${platform:-}" in
    rockchip|rk3399|rk3568|rk3576|armv8)
        core="arm64"
        ;;
    x86_64)
        core="amd64"
        ;;
    *)
        echo "Unsupported platform: ${platform:-unset}, skip mihomo core preset."
        exit 0
        ;;
esac

# 内核类型，默认 meta
mihomo_core="${mihomo_core:-meta}"
case "$mihomo_core" in
    smart)
        SUBDIR="smart"
        ;;
    meta|*)
        SUBDIR="meta"
        ;;
esac

# 根据 mihomo_core 类型生成下载链接
CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/${SUBDIR}/clash-linux-${core}.tar.gz"

# 定义 geoip.dat、geosite.dat 下载链接
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
MODEL_URL="https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/model.bin"
CLASH_URL="https://github.com/grandway2025/default-settings/releases/download/settings/openclash"
NIKKI_URL="https://github.com/grandway2025/default-settings/releases/download/settings/nikki"

echo "platform=${platform:-unset}"
echo "core=${core}"
echo "mihomo_core=${mihomo_core}"
echo "SUBDIR=${SUBDIR}"
echo "CLASH_META_URL=${CLASH_META_URL}"

# 下载并解压 Clash Meta 内核，输出为 clash_meta 可执行文件
wget -qO- "${CLASH_META_URL}" | tar xOvz > files/etc/openclash/core/clash_meta

wget -qO- $MODEL_URL > files/etc/openclash/model.bin
wget -qO- $CLASH_URL > files/etc/config/openclash
wget -qO- $NIKKI_URL > files/etc/config/nikki

# 检查 Clash Meta 内核是否下载成功
if [ ! -s files/etc/openclash/core/clash_meta ]; then
    echo "Error: clash_meta download failed."
    exit 1
fi

# 下载 GeoIP 数据库（IP 地址归属地信息）
wget -qO files/etc/openclash/GeoIP.dat "${GEOIP_URL}"

# 下载 GeoSite 数据库（常用域名分类信息）
wget -qO files/etc/openclash/GeoSite.dat "${GEOSITE_URL}"

# 检查 GeoIP / GeoSite 是否下载成功
if [ ! -s files/etc/openclash/GeoIP.dat ]; then
    echo "Error: GeoIP.dat download failed."
    exit 1
fi

if [ ! -s files/etc/openclash/GeoSite.dat ]; then
    echo "Error: GeoSite.dat download failed."
    exit 1
fi

# 检查 openclash / nikki /  model.bin 是否下载成功
if [ ! -s files/etc/config/openclash]; then
    echo "Error: openclash download failed."
    exit 1
fi

if [ ! -s files/etc/config/nikki ]; then
    echo "Error: Nikki download failed."
    exit 1
fi

# 赋予 Clash 核心文件可执行权限
chmod +x files/etc/openclash/core/clash_meta
chmod +x files/etc/config/openclash
chmod +x files/etc/config/nikki

echo "mihomo core preset done."
