#!/bin/bash
# ============================================================
# OpenWrt Release Info Generator
#
# 必需环境变量：
#   RELEASE_TAG
#   DEVICE
#
# 可选环境变量：
#   LAN_ADDR
#   ROOT_PASSWORD
#   MANIFEST_FILE
#   CONFIG_BUILDINFO
#   OPENWRT_DIR
#   KERNEL_VERSION
#   GCC_VERSION
#   WEB_SERVER
#   MIHOMO_CORE
#   DOCKER
#   BUILD_OPTIONS
#   OUTPUT_FILE
#   INFO_MODE: full | minimal
#   CURATED_LIST
# ============================================================

set -e

OUTPUT_FILE="${OUTPUT_FILE:-info/info.md}"
MANIFEST_FILE="${MANIFEST_FILE:-info/manifest.txt}"
CONFIG_BUILDINFO="${CONFIG_BUILDINFO:-info/config.buildinfo}"
OPENWRT_DIR="${OPENWRT_DIR:-openwrt}"
INFO_MODE="${INFO_MODE:-full}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

BUILD_DATE="$(date '+%Y-%m-%d %H:%M:%S')"

RELEASE_TAG="${RELEASE_TAG:-unknown}"
DEVICE="${DEVICE:-unknown}"
LAN_ADDR="${LAN_ADDR:-192.168.1.1}"
ROOT_PASSWORD="${ROOT_PASSWORD:-}"
MIHOMO_CORE="${MIHOMO_CORE:-meta}"
BUILD_OPTIONS="${BUILD_OPTIONS:-}"

[ -z "$ROOT_PASSWORD" ] && ROOT_PASSWORD="无密码"

# ============================================================
# 自动检测函数
# ============================================================

has_pkg() {
    local pkg="$1"

    [ -f "$MANIFEST_FILE" ] || return 1

    awk '{print $1}' "$MANIFEST_FILE" | grep -qx "$pkg"
}

has_pkg_prefix() {
    local prefix="$1"

    [ -f "$MANIFEST_FILE" ] || return 1

    awk '{print $1}' "$MANIFEST_FILE" | grep -Eq "^${prefix}($|-|_)"
}

detect_gcc_version() {
    if [ -n "$GCC_VERSION" ] && [ "$GCC_VERSION" != "auto" ]; then
        echo "$GCC_VERSION"
        return
    fi

    if echo "$BUILD_OPTIONS" | grep -qw "USE_GCC13=y"; then
        echo "GCC13"
    elif echo "$BUILD_OPTIONS" | grep -qw "USE_GCC14=y"; then
        echo "GCC14"
    elif echo "$BUILD_OPTIONS" | grep -qw "USE_GCC15=y"; then
        echo "GCC15"
    elif echo "$BUILD_OPTIONS" | grep -qw "USE_GCC16=y"; then
        echo "GCC16"
    elif [ -f "$CONFIG_BUILDINFO" ] && grep -q "CONFIG_GCC_USE_VERSION_13=y" "$CONFIG_BUILDINFO"; then
        echo "GCC13"
    elif [ -f "$CONFIG_BUILDINFO" ] && grep -q "CONFIG_GCC_USE_VERSION_14=y" "$CONFIG_BUILDINFO"; then
        echo "GCC14"
    elif [ -f "$CONFIG_BUILDINFO" ] && grep -q "CONFIG_GCC_USE_VERSION_15=y" "$CONFIG_BUILDINFO"; then
        echo "GCC15"
    elif [ -f "$CONFIG_BUILDINFO" ] && grep -q "CONFIG_GCC_USE_VERSION_16=y" "$CONFIG_BUILDINFO"; then
        echo "GCC16"
    else
        echo "GCC15"
    fi
}

detect_web_server() {
    if [ -n "$WEB_SERVER" ] && [ "$WEB_SERVER" != "auto" ]; then
        echo "$WEB_SERVER"
        return
    fi

    if echo "$BUILD_OPTIONS" | grep -qw "ENABLE_UHTTPD=y"; then
        echo "uhttpd"
    elif [ -f "$MANIFEST_FILE" ] && has_pkg "uhttpd"; then
        echo "uhttpd"
    else
        echo "nginx"
    fi
}

detect_docker() {
    if [ -n "$DOCKER" ] && [ "$DOCKER" != "auto" ]; then
        echo "$DOCKER"
        return
    fi

    if has_pkg "dockerd" || has_pkg "docker" || has_pkg "luci-app-dockerman"; then
        echo "true"
    else
        echo "false"
    fi
}

detect_kernel_version() {
    if [ -n "$KERNEL_VERSION" ] && [ "$KERNEL_VERSION" != "auto" ]; then
        echo "$KERNEL_VERSION"
        return
    fi

    # 优先从 kmod 压缩包名称里提取
    # 例如：
    # x86_64-6.6.104~xxxx-r1.tar.gz
    # armv8-6.6.104~xxxx-r1.tar.gz
    # aarch64-6.6.104~xxxx-r1.tar.gz
    local kmod_file
    kmod_file="$(find "$OPENWRT_DIR" -maxdepth 1 -type f -name "*.tar.gz" 2>/dev/null | head -n 1 || true)"

    if [ -n "$kmod_file" ]; then
        basename "$kmod_file" \
            | sed -E 's/^(x86_64|armv8|aarch64)-//' \
            | sed -E 's/\.tar\.gz$//'
        return
    fi

    # 其次尝试从 config.buildinfo 读取 kernel patchver
    if [ -f "$CONFIG_BUILDINFO" ]; then
        local patchver
        patchver="$(grep -E '^CONFIG_KERNEL_PATCHVER=' "$CONFIG_BUILDINFO" | head -n1 | cut -d '"' -f2 || true)"
        if [ -n "$patchver" ]; then
            echo "$patchver"
            return
        fi
    fi

    echo "N/A"
}

GCC_VERSION="$(detect_gcc_version)"
WEB_SERVER="$(detect_web_server)"
DOCKER="$(detect_docker)"
KERNEL_VERSION="$(detect_kernel_version)"

# ============================================================
# 精选插件列表
# 格式：
# 显示名称|包名
# 只显示 manifest 中实际存在的插件
# ============================================================

default_curated_list() {
    cat <<'LIST'
Docker|dockerd
Docker 管理|luci-app-dockerman
ShadowSocksR Plus+|luci-app-ssr-plus
PassWall|luci-app-passwall
PassWall2|luci-app-passwall2
OpenClash|luci-app-openclash
Mihomo Nikki|luci-app-nikki
MosDNS|luci-app-mosdns
AdGuardHome|luci-app-adguardhome
SmartDNS|luci-app-smartdns
Lucky|luci-app-lucky
FRP 内网穿透|luci-app-frpc
OpenAppFilter|luci-app-oaf
网络唤醒|luci-app-wol
UPnP|luci-app-upnp
DDNS|luci-app-ddns
阿里云盘 FUSE|luci-app-aliyundrive-fuse
文件助手|luci-app-filemanager
应用过滤|luci-app-appfilter
ZeroTier|luci-app-zerotier
TailScale|luci-app-tailscale
iStore 商店|luci-app-store
QuickStart|luci-app-quickstart
TTYD 终端|luci-app-ttyd
Samba4|luci-app-samba4
QoS Nftables|luci-app-qos-nft
SQM QoS|luci-app-sqm
Argon 主题|luci-theme-argon
LIST
}

# ============================================================
# 渲染区块
# ============================================================

render_header() {
    cat <<EOF
# 🎉 OpenWrt 固件发布

EOF
}

render_build_info() {
    cat <<EOF
## 📊 构建信息

| 项目 | 值 |
|------|----|
| 🏷️ 版本 | \`${RELEASE_TAG}\` |
| 📅 编译时间 | \`${BUILD_DATE}\` |
| 🎯 目标设备 | \`${DEVICE}\` |
| 🐧 内核版本 | \`${KERNEL_VERSION}\` |
| 🛠️ GCC 版本 | \`${GCC_VERSION}\` |
| 🌐 Web 服务 | \`${WEB_SERVER}\` |
| 🐳 Docker | \`${DOCKER}\` |
| 🐱 Mihomo 内核 | \`${MIHOMO_CORE}\` |
| 🌍 默认 LAN | \`${LAN_ADDR}\` |
| 🔑 默认密码 | \`${ROOT_PASSWORD}\` |

EOF
}

render_build_info_minimal() {
    cat <<EOF
## 📊 构建信息

| 项目 | 值 |
|------|----|
| 🏷️ 版本 | \`${RELEASE_TAG}\` |
| 📅 编译时间 | \`${BUILD_DATE}\` |
| 🎯 目标设备 | \`${DEVICE}\` |

EOF
}

render_build_options() {
    [ -z "$BUILD_OPTIONS" ] && return

    cat <<EOF
## ⚙️ 构建选项

\`\`\`
${BUILD_OPTIONS}
\`\`\`

EOF
}

render_curated_compiled_only() {
    [ -f "$MANIFEST_FILE" ] || return

    local tmp_file
    tmp_file="$(mktemp)"

    if [ -n "$CURATED_LIST" ] && [ -f "$CURATED_LIST" ]; then
        list_file="$CURATED_LIST"
        while IFS='|' read -r name pkg; do
            [ -z "$name" ] && continue
            [ -z "$pkg" ] && continue

            if has_pkg "$pkg"; then
                echo "| ${name} | ✅ 已编译 |" >> "$tmp_file"
            fi
        done < "$list_file"
    else
        default_curated_list | while IFS='|' read -r name pkg; do
            [ -z "$name" ] && continue
            [ -z "$pkg" ] && continue

            if has_pkg "$pkg"; then
                echo "| ${name} | ✅ 已编译 |" >> "$tmp_file"
            fi
        done
    fi

    if [ -s "$tmp_file" ]; then
        cat <<EOF
## 📦 已编译插件

| 插件 | 状态 |
|------|------|
EOF
        cat "$tmp_file"
        echo
    fi

    rm -f "$tmp_file"
}

render_footer() {
    cat <<'EOF'
## 📝 校验信息

> 固件 SHA256 校验信息见 Release Assets。

---

> 💡 刷机有风险，请确认固件与设备型号匹配后再操作。
EOF
}

render_footer_minimal() {
    cat <<'EOF'
---
> SHA256 校验见 Release Assets。
EOF
}

# ============================================================
# 组装
# ============================================================

{
    render_header

    case "$INFO_MODE" in
        minimal)
            render_build_info_minimal
            render_footer_minimal
            ;;
        full|curated|*)
            render_build_info
            render_build_options
            render_curated_compiled_only
            render_footer
            ;;
    esac
} > "$OUTPUT_FILE"

echo "✅ Release info generated: $OUTPUT_FILE"
echo "----------------------------------------"
cat "$OUTPUT_FILE"
echo "----------------------------------------"
