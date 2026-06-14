#!/bin/bash
# ============================================================
# OpenWrt Release Info Generator
# 生成 GitHub Release 正文 Markdown
#
# 必需环境变量：
#   RELEASE_TAG     版本号
#   DEVICE          目标设备 (x86_64 / nanopi-r5s / armv8 ...)
#
# 可选环境变量：
#   LAN_ADDR        默认 LAN
#   ROOT_PASSWORD   默认 root 密码
#   MANIFEST_FILE   固件 manifest 路径（用于检测插件）
#   KERNEL_VERSION  内核版本
#   GCC_VERSION     GCC 版本
#   WEB_SERVER      nginx / uhttpd
#   MIHOMO_CORE     meta / smart
#   DOCKER          true / false
#   BUILD_OPTIONS   原始构建选项串
#   OUTPUT_FILE     输出 md 文件路径，默认 info/info.md
#   INFO_MODE       curated(默认) | all | both | minimal
#   CURATED_LIST    自定义精选插件列表文件（每行: 显示名|包名前缀）
# ============================================================

set -e

OUTPUT_FILE="${OUTPUT_FILE:-info/info.md}"
MANIFEST_FILE="${MANIFEST_FILE:-info/manifest.txt}"
INFO_MODE="${INFO_MODE:-curated}"
mkdir -p "$(dirname "$OUTPUT_FILE")"

BUILD_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
RELEASE_TAG="${RELEASE_TAG:-unknown}"
DEVICE="${DEVICE:-unknown}"
LAN_ADDR="${LAN_ADDR:-192.168.1.1}"
ROOT_PASSWORD="${ROOT_PASSWORD:-password}"
KERNEL_VERSION="${KERNEL_VERSION:-N/A}"
GCC_VERSION="${GCC_VERSION:-N/A}"
WEB_SERVER="${WEB_SERVER:-nginx}"
MIHOMO_CORE="${MIHOMO_CORE:-meta}"
DOCKER="${DOCKER:-false}"
BUILD_OPTIONS="${BUILD_OPTIONS:-}"

# ---------- 工具 ----------
has_pkg() {
    local pattern="$1"
    if [ -f "$MANIFEST_FILE" ] && grep -qE "^${pattern}( |$)" "$MANIFEST_FILE"; then
        echo "✅ 已编译"
    else
        echo "❌ 未编译"
    fi
}

default_curated_list() {
    cat <<'LIST'
Docker (dockerd)|dockerd
ShadowSocksR Plus+|luci-app-ssr-plus
PassWall|luci-app-passwall
OpenClash|luci-app-openclash
Mihomo (Nikki)|luci-app-nikki
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
LIST
}

# ---------- 区块渲染 ----------
render_header() {
    echo "# 🎉 OpenWrt 固件发布"
    echo ""
}

render_build_info_full() {
    cat <<EOF
## 📊 构建信息

| 项目 | 值 |
|------|----|
| 🏷️ 版本 | \`${RELEASE_TAG}\` |
| 📅 编译时间 | ${BUILD_DATE} |
| 🎯 目标设备 | ${DEVICE} |
| 🐧 内核版本 | ${KERNEL_VERSION} |
| 🛠️ GCC 版本 | ${GCC_VERSION} |
| 🌐 Web 服务 | ${WEB_SERVER} |
| 🐳 Docker | ${DOCKER} |
| 🐱 Mihomo 内核 | ${MIHOMO_CORE} |
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
| 📅 编译时间 | ${BUILD_DATE} |
| 🎯 目标设备 | ${DEVICE} |

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

render_curated() {
    echo "## 📦 已编译插件（精选）"
    echo ""
    echo "| 插件 | 状态 |"
    echo "|------|------|"
    if [ -n "$CURATED_LIST" ] && [ -f "$CURATED_LIST" ]; then
        cat "$CURATED_LIST"
    else
        default_curated_list
    fi | while IFS='|' read -r name pkg; do
        [ -z "$name" ] && continue
        echo "| ${name} | $(has_pkg "$pkg") |"
    done
    echo ""
}

render_all_luci() {
    echo "## 📚 已编译 LuCI 应用（全量）"
    echo ""
    if [ ! -f "$MANIFEST_FILE" ]; then
        echo "_未找到 manifest 文件，无法列出_"
        echo ""
        return
    fi
    local count
    count=$(grep -cE '^luci-app-' "$MANIFEST_FILE" || true)
    echo "> 共 **${count}** 个 LuCI 应用"
    echo ""
    echo "| 插件 | 版本 |"
    echo "|------|------|"
    awk '/^luci-app-/ {print "| " $1 " | " $3 " |"}' "$MANIFEST_FILE"
    echo ""
}

render_footer_full() {
    cat <<'EOF'
## 📝 校验信息

> SHA256 校验请见同名 `sha256sums.txt` 文件

---
> 💡 刷机有风险，请确保固件完整性后再刷入设备
EOF
}

render_footer_minimal() {
    cat <<'EOF'
---
> SHA256 校验请见同名 `sha256sums.txt` 文件
EOF
}

# ---------- 组装 ----------
{
render_header

case "$INFO_MODE" in
    minimal)
        render_build_info_minimal
        render_footer_minimal
        ;;
    all)
        render_build_info_full
        render_build_options
        render_all_luci
        render_footer_full
        ;;
    both)
        render_build_info_full
        render_build_options
        render_curated
        render_all_luci
        render_footer_full
        ;;
    curated|*)
        render_build_info_full
        render_build_options
        render_curated
        render_footer_full
        ;;
esac
} > "$OUTPUT_FILE"

echo "✅ Release info generated [mode=${INFO_MODE}]: $OUTPUT_FILE"
echo "----------------------------------------"
cat "$OUTPUT_FILE"
echo "----------------------------------------"
