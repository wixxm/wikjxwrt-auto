#!/bin/bash

# 定义颜色输出函数
info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}
warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}
error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
    exit 1
}

# 默认配置
CORES=$(nproc)  # 默认使用 CPU 核心数
SKIP_FEEDS=0    # 默认不跳过 feeds 更新
SKIP_COMPILE=0  # 默认不跳过编译
FEEDS_FILE="feeds.conf.default"
WIKJXWRT_ENTRY="src-git wikjxwrt https://github.com/wixxm/wikjxwrt-packages"
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

# 检查依赖工具
info "检查必要工具..."
for tool in git make sed curl; do
    if ! command -v "$tool" &>/dev/null; then
        error "缺少工具: $tool，请安装后重试。"
    fi
done
info "环境检查通过。"

# 添加自定义 feeds
info "检查和修改 $FEEDS_FILE..."
if ! grep -q "^$WIKJXWRT_ENTRY" "$FEEDS_FILE"; then
    echo "$WIKJXWRT_ENTRY" >>"$FEEDS_FILE"
    info "添加自定义 feeds: $WIKJXWRT_ENTRY"
else
    warn "$FEEDS_FILE 中已包含 $WIKJXWRT_ENTRY，无需重复添加。"
fi

# 更新 feeds
if [[ $SKIP_FEEDS -eq 0 ]]; then
    info "更新 feeds..."
    ./scripts/feeds update -a || error "feeds 更新失败！"
else
    warn "跳过 feeds 更新步骤。"
fi

# 删除默认 coremark 并替换为自定义版本
info "替换 coremark..."
rm -rf feeds/packages/utils/coremark
git clone https://github.com/wixxm/wikjxwrt-coremark feeds/packages/utils/coremark || error "克隆 coremark 仓库失败！"

# 处理 sysinfo.sh
info "下载并配置 sysinfo.sh..."
git clone "$WIKJXWRT_SSH_REPO" temp_ssh_repo || error "克隆 $WIKJXWRT_SSH_REPO 仓库失败！"
mkdir -p "$(dirname $SYSINFO_TARGET)"
mv temp_ssh_repo/sysinfo.sh "$SYSINFO_TARGET" || error "移动 sysinfo.sh 失败！"
rm -rf temp_ssh_repo
info "sysinfo.sh 配置完成。"

# 添加 Turbo ACC
info "添加 Turbo ACC..."
curl -sSL "$TURBOACC_SCRIPT" -o add_turboacc.sh && bash add_turboacc.sh || error "添加 Turbo ACC 失败！"

# 安装 feeds
info "安装 feeds..."
./scripts/feeds install -a || error "第一次 feeds 安装失败！"
info "再次安装 feeds..."
./scripts/feeds install -a || error "第二次 feeds 安装失败！"

# 注释自定义 feeds
info "注释自定义 feeds..."
sed -i "s|^$WIKJXWRT_ENTRY|#$WIKJXWRT_ENTRY|" "$FEEDS_FILE" || error "注释自定义 feeds 失败！"

# 配置 .config 文件
info "下载并配置 .config..."
git clone "$WIKJXWRTR_CONFIG_REPO" temp_config_repo || error "克隆 $WIKJXWRTR_CONFIG_REPO 仓库失败！"
mv temp_config_repo/6.6/.config ./ || error "移动 .config 文件失败！"
rm -rf temp_config_repo
info ".config 配置完成。"

# 自动同步配置
info "自动同步配置文件..."
make defconfig || error "同步配置文件失败！"

# 下载编译所需的文件
info "下载编译所需文件..."
make download -j"$CORES" || error "文件下载失败！"

# 编译 OpenWrt
if [[ $SKIP_COMPILE -eq 0 ]]; then
    info "开始编译 OpenWrt..."
    make V=s -j"$CORES" || error "编译过程中发生错误！"
    info "编译完成！"
    info "生成的固件位于以下目录："
    echo -e "\033[1;34m/bin/targets/x86/64/packages\033[0m"
else
    warn "跳过编译步骤。"
fi

info "所有任务完成！"
