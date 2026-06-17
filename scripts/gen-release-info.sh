#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Generate OpenWrt release markdown info
# Output:
#   /builder/info/info.md
#   /builder/info/summary.md
# ============================================================

INFO_DIR="${INFO_DIR:-/builder/info}"

mkdir -p "${INFO_DIR}"

INFO_MD="${INFO_DIR}/info.md"
SUMMARY_MD="${INFO_DIR}/summary.md"

OPENWRT_VERSION="${OPENWRT_VERSION:-OpenWrt}"
BUILD_TIME="${BUILD_TIME:-$(date -u '+%Y-%m-%d %H:%M:%S UTC')}"
DEVICE="${DEVICE:-unknown}"
TARGET="${TARGET:-${DEVICE}}"
KERNEL_VERSION="${KERNEL_VERSION:-unknown}"
GCC_VERSION="${GCC_VERSION:-unknown}"
WEB_SERVER="${WEB_SERVER:-unknown}"
DOCKER="${DOCKER:-auto}"
MIHOMO_CORE="${MIHOMO_CORE:-unknown}"
LAN_ADDR="${LAN_ADDR:-192.168.1.1}"
ROOT_PASSWORD="${ROOT_PASSWORD:-}"
BUILD_OPTIONS="${BUILD_OPTIONS:-}"
RELEASE_TITLE="${RELEASE_TITLE:-OpenWrt 固件发布}"
SOURCE_REPO="${SOURCE_REPO:-}"
SOURCE_BRANCH="${SOURCE_BRANCH:-}"
SOURCE_COMMIT="${SOURCE_COMMIT:-}"
CONFIG_FILE="${CONFIG_FILE:-}"

# 插件列表。
# 格式支持：
#   PLUGINS="Docker=true PassWall=true OpenClash=false"
# 或：
#   PLUGINS="Docker Docker管理 PassWall OpenClash Mihomo_Nikki MosDNS OpenAppFilter UPnP TTYD Argon"
PLUGINS="${PLUGINS:-Docker=true Docker管理=true PassWall=true OpenClash=true Mihomo_Nikki=true MosDNS=true OpenAppFilter=true UPnP=true TTYD终端=true Argon主题=true}"

escape_md() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//|/\\|}"
  echo "${s}"
}

format_bool() {
  local value="${1:-}"

  case "${value}" in
    true|TRUE|yes|YES|y|Y|1|enable|enabled|ENABLE|ENABLED|on|ON)
      echo "已启用"
      ;;
    false|FALSE|no|NO|n|N|0|disable|disabled|DISABLE|DISABLED|off|OFF)
      echo "未启用"
      ;;
    auto|AUTO|"")
      echo "自动"
      ;;
    *)
      echo "${value}"
      ;;
  esac
}

format_compile_status() {
  local value="${1:-}"

  case "${value}" in
    true|TRUE|yes|YES|y|Y|1|enable|enabled|ENABLE|ENABLED|on|ON)
      echo "✅ 已编译"
      ;;
    false|FALSE|no|NO|n|N|0|disable|disabled|DISABLE|DISABLED|off|OFF)
      echo "❌ 未编译"
      ;;
    auto|AUTO|"")
      echo "🔍 自动检测"
      ;;
    *)
      echo "${value}"
      ;;
  esac
}

format_root_password() {
  local value="${1:-}"

  if [[ -z "${value}" ]]; then
    echo "无密码"
  else
    echo "已设置"
  fi
}

format_gcc() {
  local value="${1:-}"

  case "${value}" in
    GCC15|gcc15|15)
      echo "GCC 15"
      ;;
    GCC14|gcc14|14)
      echo "GCC 14"
      ;;
    GCC13|gcc13|13)
      echo "GCC 13"
      ;;
    GCC12|gcc12|12)
      echo "GCC 12"
      ;;
    *)
      echo "${value}"
      ;;
  esac
}

format_kernel() {
  local value="${1:-}"

  if [[ -z "${value}" ]]; then
    echo "unknown"
  else
    echo "${value}"
  fi
}

render_plugins_table() {
  echo "| 插件 | 状态 |"
  echo "|---|---|"

  local item name value display_name status

  # shellcheck disable=SC2206
  local arr=(${PLUGINS})

  for item in "${arr[@]}"; do
    if [[ "${item}" == *"="* ]]; then
      name="${item%%=*}"
      value="${item#*=}"
    else
      name="${item}"
      value="true"
    fi

    display_name="${name//_/ }"
    status="$(format_compile_status "${value}")"

    echo "| $(escape_md "${display_name}") | ${status} |"
  done
}

GCC_DISPLAY="$(format_gcc "${GCC_VERSION}")"
KERNEL_DISPLAY="$(format_kernel "${KERNEL_VERSION}")"
DOCKER_DISPLAY="$(format_bool "${DOCKER}")"
ROOT_PASSWORD_DISPLAY="$(format_root_password "${ROOT_PASSWORD}")"

SOURCE_LINE=""
if [[ -n "${SOURCE_REPO}" ]]; then
  SOURCE_LINE="${SOURCE_REPO}"

  if [[ -n "${SOURCE_BRANCH}" ]]; then
    SOURCE_LINE="${SOURCE_LINE}@${SOURCE_BRANCH}"
  fi

  if [[ -n "${SOURCE_COMMIT}" ]]; then
    SOURCE_LINE="${SOURCE_LINE} (${SOURCE_COMMIT})"
  fi
fi

{
  echo "# 🎉 ${RELEASE_TITLE}"
  echo
  echo "> 请确认固件与设备型号匹配后再刷机。刷机有风险，操作需谨慎。"
  echo
  echo "---"
  echo
  echo "## 📊 构建信息"
  echo
  echo "| 项目 | 值 |"
  echo "|---|---|"
  echo "| 🏷️ 版本 | \`${OPENWRT_VERSION}\` |"
  echo "| 📅 编译时间 | \`${BUILD_TIME}\` |"
  echo "| 🎯 目标设备 | \`${DEVICE}\` |"
  echo "| 🧩 Target | \`${TARGET}\` |"
  echo "| 🐧 内核版本 | \`${KERNEL_DISPLAY}\` |"
  echo "| 🛠️ GCC 版本 | \`${GCC_DISPLAY}\` |"
  echo "| 🌐 Web 服务 | \`${WEB_SERVER}\` |"
  echo "| 🐳 Docker | \`${DOCKER_DISPLAY}\` |"
  echo "| 🐱 Mihomo 内核 | \`${MIHOMO_CORE}\` |"
  echo "| 🌍 默认 LAN | \`${LAN_ADDR}\` |"
  echo "| 🔑 默认密码 | \`${ROOT_PASSWORD_DISPLAY}\` |"

  if [[ -n "${SOURCE_LINE}" ]]; then
    echo "| 🔗 源码来源 | \`${SOURCE_LINE}\` |"
  fi

  if [[ -n "${CONFIG_FILE}" ]]; then
    echo "| ⚙️ 配置文件 | \`${CONFIG_FILE}\` |"
  fi

  echo
  echo "---"
  echo
  echo "## ⚙️ 构建选项"
  echo

  if [[ -n "${BUILD_OPTIONS}" ]]; then
    echo '```text'
    echo "${BUILD_OPTIONS}"
    echo '```'
  else
    echo "> 未提供额外构建选项。"
  fi

  echo
  echo "---"
  echo
  echo "## 📦 已编译插件"
  echo
  render_plugins_table
} > "${INFO_MD}"

{
  echo "## 🎉 OpenWrt 构建完成"
  echo
  echo "| 项目 | 值 |"
  echo "|---|---|"
  echo "| 版本 | \`${OPENWRT_VERSION}\` |"
  echo "| 设备 | \`${DEVICE}\` |"
  echo "| Target | \`${TARGET}\` |"
  echo "| 内核 | \`${KERNEL_DISPLAY}\` |"
  echo "| GCC | \`${GCC_DISPLAY}\` |"
  echo "| LAN | \`${LAN_ADDR}\` |"
  echo "| Docker | \`${DOCKER_DISPLAY}\` |"
  echo "| Mihomo | \`${MIHOMO_CORE}\` |"
  echo
  echo "### 构建选项"
  echo

  if [[ -n "${BUILD_OPTIONS}" ]]; then
    echo '```text'
    echo "${BUILD_OPTIONS}"
    echo '```'
  else
    echo "> 未提供额外构建选项。"
  fi
} > "${SUMMARY_MD}"

echo "Generated release info:"
echo "  ${INFO_MD}"
echo "  ${SUMMARY_MD}"
