#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Generate OpenWrt release markdown info
# Output:
#   /builder/info/info.md
#   /builder/info/summary.md
#   /builder/rom/sha256sums.txt
#
# Expected env, all optional:
#   ROM_DIR
#   INFO_DIR
#   OPENWRT_VERSION
#   BUILD_TIME
#   DEVICE
#   TARGET
#   KERNEL_VERSION
#   GCC_VERSION
#   WEB_SERVER
#   DOCKER
#   MIHOMO_CORE
#   LAN_ADDR
#   ROOT_PASSWORD
#   BUILD_OPTIONS
#   RELEASE_TITLE
#   SOURCE_REPO
#   SOURCE_BRANCH
#   SOURCE_COMMIT
#   CONFIG_FILE
#   PLUGINS
# ============================================================

ROM_DIR="${ROM_DIR:-/builder/rom}"
INFO_DIR="${INFO_DIR:-/builder/info}"

mkdir -p "${ROM_DIR}" "${INFO_DIR}"

INFO_MD="${INFO_DIR}/info.md"
SUMMARY_MD="${INFO_DIR}/summary.md"
SHA_FILE="${ROM_DIR}/sha256sums.txt"

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
# 如果外部没有传入 PLUGINS，则使用默认展示列表。
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

  if [[ "${value}" == "unknown" || -z "${value}" ]]; then
    echo "unknown"
  else
    echo "${value}"
  fi
}

format_size() {
  local file="${1:-}"

  if command -v numfmt >/dev/null 2>&1; then
    stat -c '%s' "${file}" | numfmt --to=iec --suffix=B
  else
    ls -lh "${file}" | awk '{print $5}'
  fi
}

make_sha256() {
  : > "${SHA_FILE}"

  shopt -s nullglob
  local files=("${ROM_DIR}"/*)

  if [[ "${#files[@]}" -eq 0 ]]; then
    echo "::error::No firmware files found in ${ROM_DIR}" >&2
    exit 1
  fi

  for file in "${files[@]}"; do
    [[ -f "${file}" ]] || continue

    # 避免重复把 sha256sums.txt 自己写进去
    if [[ "$(basename "${file}")" == "sha256sums.txt" ]]; then
      continue
    fi

    sha256sum "${file}" >> "${SHA_FILE}"
  done

  if [[ ! -s "${SHA_FILE}" ]]; then
    echo "::error::No valid files for sha256 generation." >&2
    exit 1
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

render_assets_table() {
  echo "| 文件 | 大小 | SHA256 |"
  echo "|---|---:|---|"

  shopt -s nullglob
  local file name size sha

  while read -r sha name; do
    file="${ROM_DIR}/${name}"

    if [[ ! -f "${file}" ]]; then
      continue
    fi

    size="$(format_size "${file}")"

    echo "| \`${name}\` | ${size} | \`${sha}\` |"
  done < <(cd "${ROM_DIR}" && sha256sum $(find . -maxdepth 1 -type f ! -name 'sha256sums.txt' -printf '%f\n' | sort))
}

render_asset_list() {
  shopt -s nullglob

  local file name size

  for file in "${ROM_DIR}"/*; do
    [[ -f "${file}" ]] || continue
    name="$(basename "${file}")"

    if [[ "${name}" == "sha256sums.txt" ]]; then
      continue
    fi

    size="$(format_size "${file}")"
    echo "- \`${name}\` - ${size}"
  done
}

make_sha256

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
  echo "# 🎉 OpenWrt 固件发布"
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
    echo
    echo '```text'
    echo "${BUILD_OPTIONS}"
    echo '```'
  else
    echo
    echo "> 未提供额外构建选项。"
  fi

  echo
  echo "---"
  echo
  echo "## 📦 已编译插件"
  echo
  echo
  render_plugins_table

  echo
  echo "---"
  echo
  echo "## 🔐 固件校验信息"
  echo
  echo
  echo "以下 SHA256 可用于下载后校验固件完整性。"
  echo
  echo
  render_assets_table

  echo
  echo
  echo "<details>"
  echo "<summary>展开 sha256sums.txt</summary>"
  echo
  echo '```text'
  cat "${SHA_FILE}"
  echo '```'
  echo
  echo "</details>"

  echo
  echo "---"
  echo
  echo "## 🧾 固件文件"
  echo
  echo
  render_asset_list

  echo
  echo "---"
  echo
  echo "## 💡 使用提示"
  echo
  echo
  echo "- 默认管理地址：\`http://${LAN_ADDR}\`"
  echo "- 默认密码：\`${ROOT_PASSWORD_DISPLAY}\`"
  echo "- 建议刷机前备份当前配置。"
  echo "- 如果是首次刷入，建议使用 factory / combined 类型镜像。"
  echo "- 如果是系统内升级，建议使用 sysupgrade 类型镜像。"
  echo
  echo "> ⚠️ 刷机有风险，请确认固件、设备型号、分区布局匹配后再操作。"
} > "${INFO_MD}"

{
  echo "## 🎉 OpenWrt 构建完成"
  echo
  echo "| 项目 | 值 |"
  echo "|---|---|"
  echo "| 版本 | \`${OPENWRT_VERSION}\` |"
  echo "| 设备 | \`${DEVICE}\` |"
  echo "| 内核 | \`${KERNEL_DISPLAY}\` |"
  echo "| GCC | \`${GCC_DISPLAY}\` |"
  echo "| LAN | \`${LAN_ADDR}\` |"
  echo "| Docker | \`${DOCKER_DISPLAY}\` |"
  echo
  echo "### 固件文件"
  echo
  render_asset_list
  echo
  echo "### SHA256"
  echo
  echo '```text'
  cat "${SHA_FILE}"
  echo '```'
} > "${SUMMARY_MD}"

echo "Generated release info:"
echo "  ${INFO_MD}"
echo "  ${SUMMARY_MD}"
echo "  ${SHA_FILE}"
