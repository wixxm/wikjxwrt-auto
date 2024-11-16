#!/bin/bash

# 定义颜色输出函数
info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}
error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# 默认配置
CORES=$(nproc)  # 默认使用 CPU 核心数
SKIP_FEEDS=0    # 默认不跳过 feeds 更新
SKIP_COMPILE=0  # 默认不跳过编译

# 显示帮助信息
usage() {
    echo "用法: $0 [-j <线程数>] [--skip-feeds] [--skip-compile]"
    echo ""
    echo "选项:"
    echo "  -j <线程数>       指定编译时使用的并发线程数，默认 $(nproc)"
    echo "  --skip-feeds      跳过 feeds 更新步骤"
    echo "  --skip-compile    跳过编译步骤"
    echo "  -h, --help        显示帮助信息"
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
            usage
            exit 1
            ;;
    esac
done

# 检查环境依赖
info "检查必要工具..."
REQUIRED_TOOLS=("git" "make" "sed")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        error "缺少工具: $tool，请安装后重试。"
        exit 1
    fi
done
info "环境检查通过。"

# 主项目更新
info "正在更新主项目仓库..."
if git pull; then
    info "主项目仓库更新完成。"
else
    error "主项目仓库更新失败！"
    exit 1
fi

# 修改 feeds.conf.default 文件
FEEDS_FILE="feeds.conf.default"
if [[ -f $FEEDS_FILE ]]; then
    info "正在修改 $FEEDS_FILE，去掉 '#src-git wikjxwrt' 的注释..."
    sed -i 's/^#\(src-git wikjxwrt https:\/\/github\.com\/wixxm\/wikjxwrt-packages\)/\1/' $FEEDS_FILE
    info "$FEEDS_FILE 修改完成。"
else
    error "$FEEDS_FILE 文件不存在！"
    exit 1
fi

# 更新 feeds
if [[ $SKIP_FEEDS -eq 0 ]]; then
    info "更新 feeds..."
    if ./scripts/feeds update -a; then
        info "feeds 更新完成。"
        info "安装 feeds 中的包..."
        if ./scripts/feeds install -a; then
            info "feeds 包安装完成。"
        else
            error "feeds 包安装失败！"
            exit 1
        fi
    else
        error "feeds 更新失败！"
        exit 1
    fi
else
    info "跳过 feeds 更新步骤。"
fi

# 恢复 feeds.conf.default 文件
info "恢复 $FEEDS_FILE 中的 '#src-git wikjxwrt' 注释..."
if sed -i 's/^\(src-git wikjxwrt https:\/\/github\.com\/wixxm\/wikjxwrt-packages\)/#\1/' $FEEDS_FILE; then
    info "$FEEDS_FILE 恢复完成。"
else
    error "$FEEDS_FILE 恢复失败！"
    exit 1
fi

# 编译 OpenWrt
if [[ $SKIP_COMPILE -eq 0 ]]; then
    info "开始编译 OpenWrt..."
    if make V=s -j"$CORES"; then
        info "编译完成！"
        info "固件生成路径：/bin/targets/x86/64/packages"
    else
        error "编译过程中发生错误！"
        exit 1
    fi
else
    info "跳过编译步骤。"
fi

info "所有任务完成。"
info "生成的固件位于路径：/bin/targets/x86/64/packages"
