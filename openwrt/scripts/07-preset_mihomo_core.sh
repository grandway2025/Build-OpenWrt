#!/bin/bash
set -euo pipefail

# 工作目录应为 openwrt/
mkdir -p files/etc/openclash/core

# 平台 → 架构映射
case "$platform" in
    rk3399|rk3568|rk3576|armv8)
        core="arm64" ;;
    x86_64)
        core="amd64" ;;
    *)
        echo "Skip mihomo preset: unsupported platform=$platform"
        exit 0 ;;
esac

# 内核类型，默认 meta
mihomo_core="${mihomo_core:-meta}"
case "$mihomo_core" in
    smart) SUBDIR="smart" ;;
    meta|*) SUBDIR="meta" ;;
esac

CLASH_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/${SUBDIR}/clash-linux-${core}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

echo "Downloading mihomo core: $CLASH_URL"
# 解压到临时目录后再移动，避免 stdout 拼接问题
TMPDIR=$(mktemp -d)
wget -qO- "$CLASH_URL" | tar -xz -C "$TMPDIR"
BIN=$(find "$TMPDIR" -type f | head -n1)
[ -n "$BIN" ] && mv "$BIN" files/etc/openclash/core/clash_meta
rm -rf "$TMPDIR"
[ -s files/etc/openclash/core/clash_meta ] || { echo "clash_meta download failed"; exit 1; }

wget -qO files/etc/openclash/GeoIP.dat   "$GEOIP_URL"
wget -qO files/etc/openclash/GeoSite.dat "$GEOSITE_URL"
[ -s files/etc/openclash/GeoIP.dat ]   || { echo "GeoIP download failed"; exit 1; }
[ -s files/etc/openclash/GeoSite.dat ] || { echo "GeoSite download failed"; exit 1; }

chmod +x files/etc/openclash/core/clash_meta
echo "mihomo core preset done."

# ============================================================
# Copy custom rootfs files from repository
# Repository path: Build-OpenWrt/files
# Current path:    Build-OpenWrt/openwrt
# Target path:     Build-OpenWrt/openwrt/files
# ============================================================
# ============================================================
# Copy custom rootfs files from repository
# ============================================================
echo "Copy custom rootfs files from repository ..."
echo "Current directory:"
pwd
echo "GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-}"
CUSTOM_FILES_DIR=""
# 依次尝试多个可能位置
for dir in \
    "../files" \
    "${GITHUB_WORKSPACE:-}/files" \
    "/builder/files" \
    "/workdir/files"
do
    if [ -n "$dir" ] && [ -d "$dir" ]; then
        CUSTOM_FILES_DIR="$dir"
        break
    fi
done
if [ -n "$CUSTOM_FILES_DIR" ]; then
    echo "Found custom files directory: $CUSTOM_FILES_DIR"
    mkdir -p files
    cp -a "$CUSTOM_FILES_DIR"/. files/
    echo "Custom files copied to openwrt/files"
    # 兼容 OpenClash model 文件名
    if [ -s files/etc/openclash/model-large.bin ]; then
        ln -sf model-large.bin files/etc/openclash/model.bin
        echo "Created symlink: files/etc/openclash/model.bin -> model-large.bin"
    fi
    echo "Final custom file list:"
    ls -lh files/etc/config/openclash 2>/dev/null || true
    ls -lh files/etc/config/nikki 2>/dev/null || true
    ls -lh files/etc/openclash/model-large.bin 2>/dev/null || true
    ls -lh files/etc/openclash/model.bin 2>/dev/null || true
else
    echo "Warning: custom files directory not found, skip."
    echo "Debug path list:"
    ls -la .. 2>/dev/null || true
    ls -la "${GITHUB_WORKSPACE:-/not-set}" 2>/dev/null || true
fi
