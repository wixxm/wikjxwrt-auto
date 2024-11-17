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

# 显示帮助信息
usage() {
    cat <<EOF
用法: $0

此脚本用于配置 OpenWrt 编译环境，安装所需的依赖软件。
EOF
}

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
    error "此脚本需要以 root 用户运行，请使用 sudo 或切换到 root 后重试。"
fi

# 检查必要工具是否已安装
info "检查必要工具..."
for tool in apt; do
    if ! command -v "$tool" &>/dev/null; then
        error "工具 $tool 未安装，请确认系统为基于 Debian 的发行版并安装 $tool 后重试。"
    fi
done
info "必要工具已就绪。"

# 更新系统并安装依赖
info "更新系统并安装 OpenWrt 编译所需的依赖包..."
apt update -y && apt full-upgrade -y
if ! apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib \
git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev \
libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev libreadline-dev \
libssl-dev libtool lrzsz mkisofs msmtp ninja-build p7zip p7zip-full patch pkgconf python3 \
python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion swig texinfo \
uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev; then
    error "依赖包安装失败，请检查网络连接或软件源配置！"
fi

info "所有依赖已安装完成，系统已配置好 OpenWrt 的编译环境！"
