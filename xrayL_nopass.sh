DEFAULT_START_PORT=20000                         # 默认起始端口
DEFAULT_WS_PATH="/ws"                            # 默认ws路径
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid) # 默认随机UUID

IP_ADDRESSES=($(hostname -I))

install_xray() {
    echo "安装 Xray..."
    apt-get install unzip -y || yum install unzip -y
    wget https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip
    unzip Xray-linux-64.zip
    mv xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL
    cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.toml
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xrayL.service
    systemctl start xrayL.service
    echo "Xray 安装完成."
}

config_xray() {
    config_type=$1
    mkdir -p /etc/xrayL
    if [ "$config_type" != "socks" ] && [ "$config_type" != "vmess" ]; then
        echo "类型错误！仅支持socks和vmess."
        exit 1
    fi

    read -p "起始端口 (默认 $DEFAULT_START_PORT): " START_PORT
    START_PORT=${START_PORT:-$DEFAULT_START_PORT}
    if [ "$config_type" == "vmess" ]; then
        read -p "UUID (默认随机): " UUID
        UUID=${UUID:-$DEFAULT_UUID}
        read -p "WebSocket 路径 (默认 $DEFAULT_WS_PATH): " WS_PATH
        WS_PATH=${WS_PATH:-$DEFAULT_WS_PATH}
    fi

    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        config_content+="[[inbounds]]\n"
        config_content+="port = $((START_PORT + i))\n"
        config_content+="protocol = \"$config_type\"\n"
        config_content+="tag = \"tag_$((i + 1))\"\n"
        config_content+="[inbounds.settings]\n"
        if [ "$config_type" == "socks" ]; then
            config_content+="auth = \"noauth\"\n"
            config_content+="udp = true\n"
            config_content+="ip = \"${IP_ADDRESSES[i]}\"\n"
            # 开启 mixed 模式，兼容 HTTP 和 SOCKS 代理
            config_content+="userLevel = 0\n"
            config_content+="tcpFastOpen = false\n"
        elif [ "$config_type" == "vmess" ]; then
            config_content+="[[inbounds.settings.clients]]\n"
            config_content+="id = \"$UUID\"\n"
            config_content+="[inbounds.streamSettings]\n"
            config_content+="network = \"ws\"\n"
            config_content+="[inbounds.streamSettings.wsSettings]\n"
            config_content+="path = \"$WS_PATH\"\n\n"
        fi
        config_content+="[[outbounds]]\n"
        config_content+="sendThrough = \"${IP_ADDRESSES[i]}\"\n"
        config_content+="protocol = \"freedom\"\n"
        config_content+="tag = \"tag_$((i + 1))\"\n\n"
        config_content+="[[routing.rules]]\n"
        config_content+="type = \"field\"\n"
        config_content+="inboundTag = \"tag_$((i + 1))\"\n"
        config_content+="outboundTag = \"tag_$((i + 1))\"\n\n\n"
    done
    echo -e "$config_content" >/etc/xrayL/config.toml
    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service
    echo ""
    echo "生成 $config_type 配置完成"
    echo "起始端口:$START_PORT"
    echo "结束端口:$(($START_PORT + $i - 1))"
    if [ "$config_type" == "vmess" ]; then
        echo "UUID:$UUID"
        echo "ws路径:$WS_PATH"
    fi
    echo ""
}

main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    if [ $# -eq 1 ]; then
        config_type="$1"
    else
        read -p "选择生成的节点类型 (socks/vmess): " config_type
    fi
    if [ "$config_type" == "vmess" ]; then
        config_xray "vmess"
    elif [ "$config_type" == "socks" ]; then
        config_xray "socks"
    else
        echo "未正确选择类型，使用默认socks配置."
        config_xray "socks"
    fi
}

main "$@"