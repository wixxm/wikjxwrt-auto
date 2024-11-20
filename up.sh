#!/bin/bash

# 定义颜色和状态图标
RESET="\033[0m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"

ICON_SUCCESS="[${GREEN}✓${RESET}]"
ICON_WARN="[${YELLOW}⚠${RESET}]"
ICON_ERROR="[${RED}✗${RESET}]"
ICON_PROGRESS="[${CYAN}...${RESET}]"

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
CORES=$(nproc)
SKIP_FEEDS=0
SKIP_COMPILE=0
FEEDS_FILE="feeds.conf.default"
WIKJXWRT_ENTRY="src-git wikjxwrt https://github.com/wixxm/wikjxwrt-packages"

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

# 解析参数
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
        echo -e "$ICON_SUCCESS 工具已安装: $tool"
    else
        echo -e "$ICON_ERROR 缺少工具: $tool，请安装后重试。"
        exit 1
    fi
done
echo -e "$ICON_SUCCESS 环境检查通过。"

# 更新主项目仓库
section "更新主项目仓库"
info "拉取最新代码..."
if git pull; then
    echo -e "$ICON_SUCCESS 主项目仓库更新完成。"
else
    echo -e "$ICON_ERROR 主项目仓库更新失败！"
    exit 1
fi

# 修改 feeds.conf.default 文件
section "修改 feeds 配置"
info "检查和修改 $FEEDS_FILE..."
if [[ -f $FEEDS_FILE ]]; then
    if ! grep -q "^$WIKJXWRT_ENTRY" "$FEEDS_FILE"; then
        echo "$WIKJXWRT_ENTRY" >>"$FEEDS_FILE"
        echo -e "$ICON_SUCCESS 添加自定义 feeds: $WIKJXWRT_ENTRY"
    else
        echo -e "$ICON_WARN feeds 已存在，无需重复添加。"
    fi
else
    echo -e "$ICON_ERROR $FEEDS_FILE 文件不存在！"
    exit 1
fi

# 更新 feeds
if [[ $SKIP_FEEDS -eq 0 ]]; then
    section "更新 feeds"
    info "更新 feeds..."
    ./scripts/feeds update -a || error "feeds 更新失败！"
    echo -e "$ICON_SUCCESS feeds 更新完成。"

    info "安装 feeds 包..."
    ./scripts/feeds install -a || error "feeds 包安装失败！"
    echo -e "$ICON_SUCCESS feeds 包安装完成。"
else
    echo -e "$ICON_WARN 跳过 feeds 更新步骤。"
fi

# 恢复 feeds.conf.default 文件
section "恢复 feeds 配置"
info "恢复 $FEEDS_FILE 中的注释..."
if sed -i "s|^$WIKJXWRT_ENTRY|#$WIKJXWRT_ENTRY|" "$FEEDS_FILE"; then
    echo -e "$ICON_SUCCESS $FEEDS_FILE 恢复完成。"
else
    echo -e "$ICON_ERROR $FEEDS_FILE 恢复失败！"
    exit 1
fi

# 编译 OpenWrt
if [[ $SKIP_COMPILE -eq 0 ]]; then
    section "编译 OpenWrt"
    info "开始编译 OpenWrt..."
    if make V=s -j"$CORES"; then
        echo -e "$ICON_SUCCESS 编译完成！"
        echo -e "固件文件位于：${BOLD}/bin/targets/x86/64/packages${RESET}"
    else
        echo -e "$ICON_ERROR 编译过程中发生错误！"
        exit 1
    fi
else
    echo -e "$ICON_WARN 跳过编译步骤。"
fi

section "任务完成"
info "🎉 所有任务已完成！"
