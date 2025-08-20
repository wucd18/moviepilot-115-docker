#!/bin/bash
# root-deploy.sh - 允许root用户运行的MoviePilot部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     MoviePilot + 115网盘 ROOT部署工具 v1.0                   ║
║                                                              ║
║     🎬 自动下载  📁 云端播放  🚀 一键部署                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info() { echo -e "${GREEN}✓${NC} $1"; }
print_step() { echo -e "${BLUE}➤${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Root用户警告
if [[ $EUID -eq 0 ]]; then
    print_warn "检测到root用户，将以root权限运行"
    print_warn "建议：生产环境请使用普通用户 + sudo"
    sleep 3
    DOCKER_CMD="docker"
    USER_HOME="/root"
else
    USER_HOME="$HOME"
    if ! docker ps >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    else
        DOCKER_CMD="docker"
    fi
fi

# 检查系统
check_system() {
    print_step "检查系统环境..."
    
    # 检查Docker
    if ! command -v docker >/dev/null 2>&1; then
        print_warn "Docker未安装，正在安装..."
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
    else
        print_info "Docker已安装: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    fi
    
    # 检查Docker服务
    if ! systemctl is-active --quiet docker; then
        print_step "启动Docker服务..."
        systemctl start docker
        systemctl enable docker
    fi
    
    print_info "系统检查完成"
}

# 获取配置
get_config() {
    print_step "配置部署参数..."
    
    # 自动检测IP
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "127.0.0.1")
    
    # 检查网络环境
    if curl -s --connect-timeout 3 https://www.baidu.com >/dev/null 2>&1; then
        LOCATION="domestic"
        print_info "检测到国内网络环境"
        NEED_PROXY=false
    else
        LOCATION="overseas" 
        print_warn "检测到海外网络环境"
        NEED_PROXY=true
    fi
    
    # 检查端口可用性
    get_available_port() {
        local port=$1
        while ss -tlnp 2>/dev/null | grep -q ":$port " || netstat -tlnp 2>/dev/null | grep -q ":$port "; do
            ((port++))
        done
        echo $port
    }
    
    MP_PORT=$(get_available_port 3000)
    QB_PORT=$(get_available_port 8080)
    EMBY_PORT=$(get_available_port 8096)
    CLASH_PORT=$(get_available_port 7890)
    
    # 默认配置
    QB_USER="admin"
    QB_PASS="admin123"
    MP_USER="admin"
    
    print_info "使用配置:"
    echo "  服务器IP: $SERVER_IP"
    echo "  MoviePilot: http://$SERVER_IP:$MP_PORT"
    echo "  qBittorrent: http://$SERVER_IP:$QB_PORT (admin/admin123)"
    echo "  Emby: http://$SERVER_IP:$EMBY_PORT"
    if [[ "$NEED_PROXY" = true ]]; then
        echo "  Clash代理: http://$SERVER_IP:9090"
    fi
    echo
}

# 创建目录和配置
setup_environment() {
    print_step "创建运行环境..."
    
    # 创建工作目录
    WORK_DIR="$USER_HOME/moviepilot-115"
    if [[ -d "$WORK_DIR" ]]; then
        print_warn "目录已存在，将清理重建"
        rm -rf "$WORK_DIR"
    fi
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # 创建子目录
    mkdir -p {config/{qbit,emby,moviepilot},downloads,media/{movies,tv,anime},cache}
    
    # 如果是海外环境，创建基础代理配置
    if [[ "$NEED_PROXY" = true ]]; then
        mkdir -p config/clash
        cat > config/clash/config.yaml << 'EOF'
mixed-port: 7890
allow-lan: true
mode: Rule
log-level: info
external-controller: "0.0.0.0:9090"

# 基础配置 - 请根据实际情况修改代理信息
proxies:
  - name: "DIRECT"
    type: direct

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT

rules:
  - DOMAIN-SUFFIX,115.com,PROXY
  - DOMAIN-KEYWORD,115,PROXY
  - MATCH,DIRECT
EOF

        print_warn "已创建基础代理配置，如需访问115网盘请手动配置代理信息"
    fi
    
    print_info "环境创建完成: $WORK_DIR"
}

# 启动服务
deploy_services() {
    print_step "部署服务中..."
    
    # 创建网络
    $DOCKER_CMD network create moviepilot-net 2>/dev/null || true
    
    # 1. 启动代理(如果需要)
    if [[ "$NEED_PROXY" = true ]]; then
        print_step "启动Clash代理..."
        $DOCKER_CMD run -d \
            --name moviepilot-clash \
            --network moviepilot-net \
            --restart unless-stopped \
            -p $CLASH_PORT:7890 -p 9090:9090 \
            -v "$PWD/config/clash:/root/.config/clash" \
            dreamacro/clash:latest >/dev/null
        sleep 5
    fi
    
    # 2. 启动qBittorrent
    print_step "启动qBittorrent..."
    $DOCKER_CMD run -d \
        --name moviepilot-qbit \
        --network moviepilot-net \
        --restart unless-stopped \
        -e PUID=0 -e PGID=0 -e TZ=Asia/Shanghai \
        -e WEBUI_PORT=8080 -e TORRENTING_PORT=32156 \
        -e QB_USERNAME="$QB_USER" -e QB_PASSWORD="$QB_PASS" \
        -p $QB_PORT:8080 -p 32156:32156 \
        -v "$PWD/config/qbit:/config" \
        -v "$PWD/downloads:/downloads" \
        -v "$PWD/media:/media" \
        linuxserver/qbittorrent:4.6.5 >/dev/null
    
    # 3. 启动Emby
    print_step "启动Emby媒体服务器..."
    $DOCKER_CMD run -d \
        --name moviepilot-emby \
        --network moviepilot-net \
        --restart unless-stopped \
        -e PUID=0 -e PGID=0 -e TZ=Asia/Shanghai \
        -e EMBY_PublishedServerUrl="$SERVER_IP" \
        -p $EMBY_PORT:8096 -p 8920:8920 \
        -v "$PWD/config/emby:/config" \
        -v "$PWD/media:/media" \
        --privileged \
        amilys/embyserver:latest >/dev/null
    
    # 4. 构建并启动MoviePilot
    print_step "构建MoviePilot镜像..."
    
    # 创建Dockerfile
    cat > Dockerfile << 'EOF'
FROM jxxghp/moviepilot-v2:latest

USER root
RUN apt-get update && apt-get install -y curl netcat-openbsd && rm -rf /var/lib/apt/lists/*

COPY start-mp.sh /start-mp.sh
RUN chmod +x /start-mp.sh

ENTRYPOINT ["/start-mp.sh"]
EOF

    # 创建启动脚本
    if [[ "$NEED_PROXY" = true ]]; then
        cat > start-mp.sh << 'EOF'
#!/bin/sh
echo "启动MoviePilot with proxy support..."
sleep 15

# 检查代理是否可用
if nc -z moviepilot-clash 7890 2>/dev/null; then
    echo "代理可用，配置代理环境"
    export http_proxy=http://moviepilot-clash:7890
    export https_proxy=http://moviepilot-clash:7890
fi

exec /entrypoint.sh "$@"
EOF
    else
        cat > start-mp.sh << 'EOF'
#!/bin/sh
echo "启动MoviePilot..."
sleep 10
exec /entrypoint.sh "$@"
EOF
    fi
    
    $DOCKER_CMD build -t moviepilot-custom . >/dev/null 2>&1
    
    print_step "启动MoviePilot..."
    $DOCKER_CMD run -d \
        --name moviepilot-main \
        --network moviepilot-net \
        --restart unless-stopped \
        -e NGINX_PORT=3000 -e PORT=3001 \
        -e PUID=0 -e PGID=0 -e UMASK=000 \
        -e SUPERUSER="$MP_USER" -e TZ=Asia/Shanghai \
        -p $MP_PORT:3000 -p 65042:65042 \
        -v "$PWD/config/moviepilot:/config" \
        -v "$PWD/media:/media" -v "$PWD/downloads:/downloads" \
        -v "$PWD/cache:/moviepilot/.cache/ms-playwright" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        moviepilot-custom >/dev/null
    
    # 清理构建文件
    rm -f Dockerfile start-mp.sh
}

# 创建管理脚本
create_scripts() {
    print_step "创建管理脚本..."
    
    # 状态检查脚本
    cat > status.sh << 'EOF'
#!/bin/bash
echo "=== MoviePilot服务状态 ==="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep moviepilot
EOF

    # 重启脚本
    cat > restart.sh << 'EOF'
#!/bin/bash
echo "重启MoviePilot服务..."
docker restart moviepilot-qbit moviepilot-emby moviepilot-main 2>/dev/null
if docker ps | grep -q moviepilot-clash; then
    docker restart moviepilot-clash 2>/dev/null
fi
echo "重启完成"
EOF

    # 停止脚本
    cat > stop.sh << 'EOF'
#!/bin/bash
echo "停止MoviePilot服务..."
docker stop moviepilot-main moviepilot-emby moviepilot-qbit 2>/dev/null
if docker ps | grep -q moviepilot-clash; then
    docker stop moviepilot-clash 2>/dev/null
fi
echo "服务已停止"
EOF

    # 启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
echo "启动MoviePilot服务..."
if docker ps -a | grep -q moviepilot-clash; then
    docker start moviepilot-clash 2>/dev/null
    sleep 3
fi
docker start moviepilot-qbit moviepilot-emby moviepilot-main 2>/dev/null
echo "服务已启动"
EOF

    # 卸载脚本
    cat > uninstall.sh << 'EOF'
#!/bin/bash
echo "停止并删除所有服务..."
docker stop moviepilot-main moviepilot-emby moviepilot-qbit 2>/dev/null || true
if docker ps -a | grep -q moviepilot-clash; then
    docker stop moviepilot-clash 2>/dev/null || true
fi
docker rm moviepilot-main moviepilot-emby moviepilot-qbit 2>/dev/null || true
if docker ps -a | grep -q moviepilot-clash; then
    docker rm moviepilot-clash 2>/dev/null || true
fi
docker network rm moviepilot-net 2>/dev/null || true
docker rmi moviepilot-custom 2>/dev/null || true
echo "卸载完成，数据保留在: $(pwd)"
EOF

    chmod +x *.sh
}

# 等待服务启动
wait_services() {
    print_step "等待服务启动..."
    
    # 等待30秒
    for i in {1..30}; do
        echo -n "."
        sleep 1
    done
    echo
    
    # 检查服务状态
    check_service() {
        local port=$1
        local name=$2
        if curl -s --connect-timeout 3 http://localhost:$port >/dev/null 2>&1; then
            print_info "$name 运行正常"
            return 0
        else
            print_warn "$name 仍在启动中，请稍后手动检查"
            return 1
        fi
    }
    
    check_service $MP_PORT "MoviePilot"
    check_service $QB_PORT "qBittorrent"
    check_service $EMBY_PORT "Emby"
}

# 显示结果
show_result() {
    clear
    echo -e "${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                    🎉 部署成功！                             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${BLUE}📱 访问地址:${NC}"
    echo "┌────────────────────────────────────────────────────────────────┐"
    echo "│ 🎬 MoviePilot:    http://$SERVER_IP:$MP_PORT"
    echo "│ ⚡ qBittorrent:   http://$SERVER_IP:$QB_PORT"  
    echo "│ 🎭 Emby:          http://$SERVER_IP:$EMBY_PORT"
    if [[ "$NEED_PROXY" = true ]]; then
        echo "│ 🌐 Clash面板:     http://$SERVER_IP:9090"
    fi
    echo "└────────────────────────────────────────────────────────────────┘"
    echo
    
    echo -e "${BLUE}🔑 默认账号:${NC}"
    echo "  qBittorrent: admin / admin123"
    echo "  MoviePilot:  admin (首次访问设置密码)"
    echo
    
    echo -e "${BLUE}📋 后续步骤:${NC}"
    echo "  1. 访问MoviePilot完成初始化设置"
    echo "  2. 安装'115网盘STRM助手'插件"
    echo "  3. 配置115网盘Cookie"
    echo "  4. 配置PT站点信息"
    echo "  5. 设置媒体库和刮削"
    echo
    
    if [[ "$NEED_PROXY" = true ]]; then
        echo -e "${YELLOW}⚠ 海外部署提醒:${NC}"
        echo "  • 当前使用基础代理配置，可能无法访问115网盘"
        echo "  • 请编辑 config/clash/config.yaml 配置您的真实代理"
        echo "  • 代理配置完成后运行: ./restart.sh"
        echo
    fi
    
    echo -e "${BLUE}🛠 管理命令:${NC}"
    echo "  ./status.sh     - 查看服务状态"
    echo "  ./start.sh      - 启动所有服务"
    echo "  ./stop.sh       - 停止所有服务"
    echo "  ./restart.sh    - 重启所有服务"  
    echo "  ./uninstall.sh  - 卸载所有服务"
    echo
    
    echo -e "${GREEN}部署完成！现在可以开始使用MoviePilot了 🚀${NC}"
    echo
    echo -e "${YELLOW}当前目录: $PWD${NC}"
    echo -e "${YELLOW}管理脚本位置: $PWD/*.sh${NC}"
}

# 主函数
main() {
    check_system
    get_config
    setup_environment
    deploy_services
    create_scripts
    wait_services
    show_result
}

# 错误处理
trap 'print_error "部署失败!"; exit 1' ERR

# 运行主函数
main "$@"
