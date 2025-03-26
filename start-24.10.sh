#!/bin/bash

# 定义颜色和状态图标
RESET="\033[0m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"
BLUE="\033[1;34m"

ICON_SUCCESS="[${GREEN}✓${RESET}]"
ICON_WARN="[${YELLOW}⚠${RESET}]"
ICON_ERROR="[${RED}✗${RESET}]"

# 输出函数
info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}
warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}
error() {
    echo -e "${RED}[ERROR]${RESET} $1"
    exit 1
}
section() {
    echo -e "\n${CYAN}========== $1 ==========${RESET}\n"
}

# 默认配置
CORES=$(nproc)  # 默认使用 CPU 核心数
SKIP_FEEDS=0    # 默认不跳过 feeds 更新
SKIP_COMPILE=0  # 默认不跳过编译
FEEDS_FILE="feeds.conf.default"
WIKJXWRT_ENTRY="src-git wikjxwrt https://github.com/wixxm/wikjxwrt-feeds"
WIKJXWRT_SSH_REPO="https://github.com/wixxm/WikjxWrt-ssh"
SYSINFO_TARGET="feeds/packages/utils/bash/files/etc/profile.d/sysinfo.sh"
TURBOACC_SCRIPT="https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh"
WIKJXWRTR_CONFIG_REPO="https://github.com/wixxm/wikjxwrtr-config"

# 显示帮助信息
usage() {
    cat <<EOF
用法: $0 [-j <线程数>] [--skip-feeds] [--skip-compile]

选项:
  -j <线程数>       指定编译时使用的并发线程数，默认 $(nproc)
  --skip-feeds      跳过 feeds 更新步骤
  --skip-compile    跳过编译步骤
  -h, --help        显示帮助信息
EOF
}

# 参数解析
while [[ $# -gt 0 ]]; do
    case "$1" in
        -j)
            CORES="$2"
            shift 2
            ;;
        --skip-feeds)
            SKIP_FEEDS=1
            shift
            ;;
        --skip-compile)
            SKIP_COMPILE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "未知参数: $1"
            ;;
    esac
done

# 环境检查
section "环境检查"
info "检查必要工具..."
for tool in git make sed curl; do
    if command -v "$tool" &>/dev/null; then
        echo -e "$ICON_SUCCESS 工具已安装: $tool"
    else
        echo -e "$ICON_ERROR 缺少工具: $tool，请安装后重试。"
        exit 1
    fi
done
echo -e "$ICON_SUCCESS 环境检查通过。"

# 添加自定义 feeds
section "自定义 feeds 配置"
info "检查和修改 $FEEDS_FILE..."
if ! grep -q "^$WIKJXWRT_ENTRY" "$FEEDS_FILE"; then
    echo "$WIKJXWRT_ENTRY" >>"$FEEDS_FILE"
    echo -e "$ICON_SUCCESS 添加自定义 feeds: $WIKJXWRT_ENTRY"
else
    echo -e "$ICON_WARN $FEEDS_FILE 中已包含 $WIKJXWRT_ENTRY，无需重复添加。"
fi

# 更新 feeds
if [[ $SKIP_FEEDS -eq 0 ]]; then
    info "更新 feeds..."
    ./scripts/feeds update -a || error "feeds 更新失败！"
    echo -e "$ICON_SUCCESS feeds 更新完成。"
else
    echo -e "$ICON_WARN 跳过 feeds 更新步骤。"
fi

# 替换 coremark
section "替换 coremark"
info "删除默认 coremark 并替换为自定义版本..."
rm -rf feeds/packages/utils/coremark
git clone https://github.com/wixxm/wikjxwrt-coremark feeds/packages/utils/coremark || error "克隆 coremark 仓库失败！"
echo -e "$ICON_SUCCESS coremark 替换完成。"

# 配置 sysinfo.sh
section "配置 sysinfo.sh"
info "下载并配置 sysinfo.sh..."
git clone "$WIKJXWRT_SSH_REPO" temp_ssh_repo || error "克隆 $WIKJXWRT_SSH_REPO 仓库失败！"
mkdir -p "$(dirname $SYSINFO_TARGET)"
mv temp_ssh_repo/sysinfo.sh "$SYSINFO_TARGET" || error "移动 sysinfo.sh 失败！"
rm -rf temp_ssh_repo
echo -e "$ICON_SUCCESS sysinfo.sh 配置完成。"

# 添加 Turbo ACC
section "添加 Turbo ACC"
info "下载并执行 Turbo ACC 安装脚本..."
curl -sSL "$TURBOACC_SCRIPT" -o add_turboacc.sh && bash add_turboacc.sh || error "添加 Turbo ACC 失败！"
echo -e "$ICON_SUCCESS Turbo ACC 添加完成。"


# 安装 feeds
section "安装 feeds"
info "安装 feeds..."
./scripts/feeds install -a || error "第一次 feeds 安装失败！"
info "再次安装 feeds..."
./scripts/feeds install -a || error "第二次 feeds 安装失败！"
echo -e "$ICON_SUCCESS feeds 安装完成。"

# 注释自定义 feeds
section "注释自定义 feeds"
info "注释自定义 feeds..."
sed -i "s|^$WIKJXWRT_ENTRY|#$WIKJXWRT_ENTRY|" "$FEEDS_FILE" || error "注释自定义 feeds 失败！"
echo -e "$ICON_SUCCESS 注释完成。"

# 配置 .config 文件
section "配置 .config 文件"
info "下载并配置 .config..."
git clone "$WIKJXWRTR_CONFIG_REPO" temp_config_repo || error "克隆配置仓库失败！"
mv temp_config_repo/6.6/.config ./ || error "移动 .config 文件失败！"
rm -rf temp_config_repo
make defconfig || error "同步配置文件失败！"
echo -e "$ICON_SUCCESS .config 配置完成。"

# 下载编译所需文件
section "下载编译文件"
info "下载编译所需文件..."
make download -j"$CORES" || error "文件下载失败！"
echo -e "$ICON_SUCCESS 文件下载完成。"

# 编译 OpenWrt
if [[ $SKIP_COMPILE -eq 0 ]]; then
    section "编译 OpenWrt"
    info "开始编译 OpenWrt..."
    make V=s -j"$CORES" || error "编译过程中发生错误！"
    echo -e "$ICON_SUCCESS 编译完成！"
    info "生成的固件位于以下目录："
    echo -e "${BLUE}/bin/targets/x86/64/packages${RESET}"
else
    echo -e "$ICON_WARN 跳过编译步骤。"
fi

section "所有任务完成"
info "🎉 所有任务已完成！"
