#!/bin/bash

# 确保以 root 用户运行
if [ "$EUID" -ne 0 ]; then
  echo "❗ 请使用 root 权限运行该脚本（例如 sudo ./runzerotier.sh）"
  exit 1
fi

# 更新系统软件包列表
echo "📦 更新系统软件包列表..."
apt update

# 安装 curl（如果未安装）
if ! command -v curl &>/dev/null; then
  echo "📥 安装 curl..."
  apt install -y curl
fi

# 安装 ZeroTier One
echo "🌐 安装 ZeroTier..."
curl -s https://install.zerotier.com | bash

# 启动 ZeroTier 服务
echo "🚀 启动 ZeroTier 服务..."
systemctl enable zerotier-one
systemctl start zerotier-one

# 加入 ZeroTier 网络
NETWORK_ID="你自己的 zeotier ID"
echo "🔗 加入 ZeroTier 网络：$NETWORK_ID..."
zerotier-cli join "$NETWORK_ID"

# 等待一会儿，让 ZeroTier 加入网络
sleep 5

# 显示 ZeroTier 状态
echo "🔍 当前 ZeroTier 网络状态："
zerotier-cli listnetworks

echo "✅ ZeroTier 安装并已加入网络 $NETWORK_ID"