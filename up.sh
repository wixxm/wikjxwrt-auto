#!/bin/bash

# 定义颜色和状态图标
RESET="\033[0m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"
BOLD="\033[1m"

ICON_SUCCESS="[${GREEN}✓${RESET}]"
ICON_WARN="[${YELLOW}⚠${RESET}]"
ICON_ERROR="[${RED}✗${RESET}]"
ICON_PROGRESS="[${CYAN}...${RESET}]"

# 输出函数
info() {
    echo -e "${ICON_SUCCESS} $1"
}
warn() {
    echo -e "${ICON_WARN} $1"
}
error() {
    echo -e "${ICON_ERROR} $1"
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
WIKJXWRT_ENTRY="src-git wikjxwrt https://github.com/wixxm/wikjxwrt-packages"

# 帮助信息
usage() {
    cat <<EOF
${BOLD}用法:${RESET} $0 [-j <线程数>] [--skip-feeds] [--skip-compile]

${BOLD}选项:${RESET}
  -j <线程数>       指定编译时使用的并发线程数，默认值为 $(nproc)
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
for tool in git make sed; do
    if command -v "$tool" &>/dev/null; then
        info "工具已安装: $tool"
    else
        error "缺少工具: $tool，请安装后重试。"
    fi
done

# 更新主项目
section "更新主项目仓库"
info "拉取最新代码..."
if git pull; then
    info "主项目仓库更新完成。"
else
    error "主项目仓库更新失败！"
fi

# 修改 feeds.conf.default 文件
section "处理 $FEEDS_FILE"
info "检查和修改 $FEEDS_FILE..."
if [[ -f $FEEDS_FILE ]]; then
    sed -i "s/^#\($WIKJXWRT_ENTRY\)/\1/" "$FEEDS_FILE" || error "修改 $FEEDS_FILE 失败！"
    info "$FEEDS_FILE 修改完成。"
else
    error "$FEEDS_FILE 文件不存在！"
fi

# 更新 feeds
if [[ $SKIP_FEEDS -eq 0 ]]; then
    section "更新 feeds"
    info "更新 feeds..."
    ./scripts/feeds update -a || error "feeds 更新失败！"
    info "feeds 更新完成。"

    info "安装 feeds 中的包..."
    ./scripts/feeds install -a || error "feeds 包安装失败！"
    info "feeds 包安装完成。"
else
    warn "跳过 feeds 更新步骤。"
fi

# 恢复 feeds.conf.default 文件
section "恢复 $FEEDS_FILE"
info "注释自定义 feeds..."
sed -i "s|^$WIKJXWRT_ENTRY|#$WIKJXWRT_ENTRY|" "$FEEDS_FILE" || error "恢复 $FEEDS_FILE 失败！"
info "$FEEDS_FILE 恢复完成。"

# 编译 OpenWrt
if [[ $SKIP_COMPILE -eq 0 ]]; then
    section "编译 OpenWrt"
    info "开始编译 OpenWrt..."
    if make V=s -j"$CORES"; then
        info "编译完成！"
        info "固件文件路径：${BOLD}/bin/targets/x86/64/packages${RESET}"
    else
        error "编译过程中发生错误！"
    fi
else
    warn "跳过编译步骤。"
fi

section "任务完成"
info "🎉 所有任务已完成！"
