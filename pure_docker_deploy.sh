#!/bin/bash
# pure-docker-deploy.sh - 纯Docker部署MoviePilot + 115网盘

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     MoviePilot + 115网盘 部署工具    ║${NC}"
    echo -e "${BLUE}║           纯Docker版本               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo
}

# 检查系统要求
check_requirements() {
    print_step "检查系统要求..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装!"
        echo "安装命令:"
        echo "Ubuntu/Debian: curl -fsSL https://get.docker.com | sh"
        echo "CentOS/RHEL: curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    
    # 检查Docker服务
    if ! docker info &> /dev/null; then
        print_error "Docker服务未启动!"
        echo "启动命令: sudo systemctl start docker"
        exit 1
    fi
    
    # 检查权限
    if ! docker ps &> /dev/null; then
        print_warning "当前用户无Docker权限，将使用sudo"
        DOCKER_CMD="sudo docker"
    else
        DOCKER_CMD="docker"
    fi
    
    print_info "系统检查完成 ✓"
}

# 创建网络
create_network() {
    print_step "创建Docker网络..."
    
    NETWORK_NAME="moviepilot-net"
    
    # 检查网络是否存在
    if $DOCKER_CMD network ls | grep -q "$NETWORK_NAME"; then
        print_warning "网络 $NETWORK_NAME 已存在，跳过创建"
    else
        $DOCKER_CMD network create "$NETWORK_NAME"
        print_info "网络创建完成 ✓"
    fi
}

# 创建目录结构
create_directories() {
    print_step "创建目录结构..."
    
    BASE_DIR="$HOME/moviepilot-115"
    
    if [ -d "$BASE_DIR" ]; then
        print_warning "目录 $BASE_DIR 已存在"
        read -p "是否删除并重新创建? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$BASE_DIR"
        else
            print_error "部署已取消"
            exit 1
        fi
    fi
    
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR"
    
    # 创建数据目录
    mkdir -p {config/{clash,qbit,emby,moviepilot},data/{downloads,media/{movies,tv,anime}},cache}
    
    print_info "目录创建完成: $BASE_DIR ✓"
}

# 收集配置信息
collect_config() {
    print_step "收集配置信息..."
    
    # 基础配置
    echo "=== 基础配置 ==="
    read -p "qBittorrent用户名 [admin]: " QB_USER
    QB_USER=${QB_USER:-admin}
    
    read -s -p "qBittorrent密码 [admin123]: " QB_PASS
    QB_PASS=${QB_PASS:-admin123}
    echo
    
    # 获取服务器IP
    DEFAULT_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")
    read -p "服务器IP [$DEFAULT_IP]: " SERVER_IP
    SERVER_IP=${SERVER_IP:-$DEFAULT_IP}
    
    read -p "MoviePilot超级用户 [admin]: " MP_USER
    MP_USER=${MP_USER:-admin}
    
    # PT站配置
    echo
    echo "=== PT站配置 (可稍后在WebUI中配置) ==="
    read -p "认证站点 (如leaves): " AUTH_SITE
    read -p "用户UID: " LEAVES_UID
    read -p "PassKey: " LEAVES_PASSKEY
    read -p "GitHub Token: " GITHUB_TOKEN
    
    # 代理配置
    echo
    echo "=== 代理配置 (海外VPS访问115网盘必需) ==="
    read -p "是否需要代理? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        NEED_PROXY=true
        read -p "代理类型 [ss]: " PROXY_TYPE
        PROXY_TYPE=${PROXY_TYPE:-ss}
        read -p "代理服务器: " PROXY_SERVER
        read -p "代理端口 [443]: " PROXY_PORT
        PROXY_PORT=${PROXY_PORT:-443}
        read -p "加密方式 [aes-256-gcm]: " PROXY_CIPHER
        PROXY_CIPHER=${PROXY_CIPHER:-aes-256-gcm}
        read -s -p "代理密码: " PROXY_PASS
        echo
    else
        NEED_PROXY=false
    fi
    
    # 端口配置
    echo
    echo "=== 端口配置 ==="
    read -p "MoviePilot端口 [3000]: " MP_PORT
    MP_PORT=${MP_PORT:-3000}
    
    read -p "qBittorrent端口 [8080]: " QB_PORT
    QB_PORT=${QB_PORT:-8080}
    
    read -p "Emby端口 [8096]: " EMBY_PORT
    EMBY_PORT=${EMBY_PORT:-8096}
    
    if [ "$NEED_PROXY" = true ]; then
        read -p "Clash代理端口 [7890]: " CLASH_PORT
        CLASH_PORT=${CLASH_PORT:-7890}
    fi
    
    print_info "配置收集完成 ✓"
}

# 生成配置文件
generate_configs() {
    print_step "生成配置文件..."
    
    # Clash配置 (如果需要代理)
    if [ "$NEED_PROXY" = true ]; then
        cat > config/clash/config.yaml << EOF
mixed-port: 7890
allow-lan: true
mode: Rule
log-level: info
external-controller: "0.0.0.0:9090"
bind-address: "0.0.0.0"

proxies:
  - name: "proxy"
    type: $PROXY_TYPE
    server: $PROXY_SERVER
    port: $PROXY_PORT
    cipher: $PROXY_CIPHER
    password: $PROXY_PASS

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - proxy
      - DIRECT

rules:
  - DOMAIN-SUFFIX,115.com,PROXY
  - DOMAIN-KEYWORD,115,PROXY
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
    fi
    
    # proxychains配置
    cat > config/proxychains.conf << 'EOF'
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

localnet 127.0.0.0/8
localnet 10.0.0.0/8
localnet 172.16.0.0/12
localnet 192.168.0.0/16

[ProxyList]
http clash 7890
EOF

    # MoviePilot启动脚本
    cat > config/moviepilot-start.sh << 'EOF'
#!/bin/sh
echo "启动MoviePilot..."

# 等待其他服务启动
sleep 15

# 检查是否需要代理
if [ "$USE_PROXY" = "true" ] && nc -z clash 7890; then
    echo "使用代理启动MoviePilot"
    exec proxychains4 -f /config/proxychains.conf /entrypoint.sh "$@"
else
    echo "直接启动MoviePilot"
    exec /entrypoint.sh "$@"
fi
EOF
    chmod +x config/moviepilot-start.sh
    
    # 生成环境变量文件
    cat > .env << EOF
# 基础配置
QB_USER=$QB_USER
QB_PASS=$QB_PASS
SERVER_IP=$SERVER_IP
MP_USER=$MP_USER

# PT站配置
AUTH_SITE=$AUTH_SITE
LEAVES_UID=$LEAVES_UID
LEAVES_PASSKEY=$LEAVES_PASSKEY
GITHUB_TOKEN=$GITHUB_TOKEN

# 代理配置
NEED_PROXY=$NEED_PROXY

# 端口配置
MP_PORT=$MP_PORT
QB_PORT=$QB_PORT
EMBY_PORT=$EMBY_PORT
CLASH_PORT=${CLASH_PORT:-7890}

# 目录配置
BASE_DIR=$BASE_DIR
EOF
    
    print_info "配置文件生成完成 ✓"
}

# 启动Clash代理 (如果需要)
start_clash() {
    if [ "$NEED_PROXY" = true ]; then
        print_step "启动Clash代理..."
        
        $DOCKER_CMD run -d \
            --name moviepilot-clash \
            --network moviepilot-net \
            --restart unless-stopped \
            -p $CLASH_PORT:7890 \
            -p 9090:9090 \
            -v "$BASE_DIR/config/clash:/root/.config/clash" \
            dreamacro/clash:latest
        
        print_info "Clash代理启动完成 ✓"
        
        # 等待代理启动
        sleep 10
    fi
}

# 启动qBittorrent
start_qbittorrent() {
    print_step "启动qBittorrent..."
    
    $DOCKER_CMD run -d \
        --name moviepilot-qbit \
        --network moviepilot-net \
        --restart unless-stopped \
        -e PUID=0 \
        -e PGID=0 \
        -e TZ=Asia/Shanghai \
        -e WEBUI_PORT=8080 \
        -e TORRENTING_PORT=32156 \
        -e QB_USERNAME="$QB_USER" \
        -e QB_PASSWORD="$QB_PASS" \
        -p $QB_PORT:8080 \
        -p 32156:32156 \
        -v "$BASE_DIR/config/qbit:/config" \
        -v "$BASE_DIR/data/downloads:/downloads" \
        -v "$BASE_DIR/data/media:/media" \
        linuxserver/qbittorrent:4.6.5
    
    print_info "qBittorrent启动完成 ✓"
}

# 启动Emby
start_emby() {
    print_step "启动Emby媒体服务器..."
    
    $DOCKER_CMD run -d \
        --name moviepilot-emby \
        --network moviepilot-net \
        --restart unless-stopped \
        -e PUID=0 \
        -e PGID=0 \
        -e GIDLIST=0 \
        -e TZ=Asia/Shanghai \
        -e EMBY_PublishedServerUrl="$SERVER_IP" \
        -p $EMBY_PORT:8096 \
        -p 8920:8920 \
        -p 7359:7359/udp \
        -p 1900:1900/udp \
        -v "$BASE_DIR/config/emby:/config" \
        -v "$BASE_DIR/data/media:/media" \
        --privileged \
        amilys/embyserver:latest
    
    print_info "Emby启动完成 ✓"
}

# 构建并启动MoviePilot
start_moviepilot() {
    print_step "构建并启动MoviePilot..."
    
    # 创建临时Dockerfile
    cat > Dockerfile.temp << EOF
FROM jxxghp/moviepilot-v2:latest

USER root
RUN apt-get update && \\
    apt-get install -y proxychains-ng curl netcat-openbsd && \\
    rm -rf /var/lib/apt/lists/*

COPY config/moviepilot-start.sh /moviepilot-start.sh
COPY config/proxychains.conf /config/proxychains.conf
RUN chmod +x /moviepilot-start.sh

ENTRYPOINT ["/moviepilot-start.sh"]
EOF

    # 构建镜像
    $DOCKER_CMD build -f Dockerfile.temp -t moviepilot-custom .
    
    # 启动容器
    PROXY_ENV=""
    if [ "$NEED_PROXY" = true ]; then
        PROXY_ENV="-e USE_PROXY=true"
    fi
    
    $DOCKER_CMD run -d \
        --name moviepilot-main \
        --network moviepilot-net \
        --restart unless-stopped \
        -e NGINX_PORT=3000 \
        -e PORT=3001 \
        -e PUID=0 \
        -e PGID=0 \
        -e UMASK=000 \
        -e SUPERUSER="$MP_USER" \
        -e TZ=Asia/Shanghai \
        -e AUTH_SITE="$AUTH_SITE" \
        -e LEAVES_UID="$LEAVES_UID" \
        -e LEAVES_PASSKEY="$LEAVES_PASSKEY" \
        -e GITHUB_TOKEN="$GITHUB_TOKEN" \
        $PROXY_ENV \
        -p $MP_PORT:3000 \
        -p 65042:65042 \
        -v "$BASE_DIR/config/moviepilot:/config" \
        -v "$BASE_DIR/data/media:/media" \
        -v "$BASE_DIR/data/downloads:/downloads" \
        -v "$BASE_DIR/cache:/moviepilot/.cache/ms-playwright" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        moviepilot-custom
    
    # 清理临时文件
    rm -f Dockerfile.temp
    
    print_info "MoviePilot启动完成 ✓"
}

# 检查服务状态
check_services() {
    print_step "检查服务状态..."
    
    echo "容器状态:"
    $DOCKER_CMD ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep moviepilot
    
    echo
    echo "等待服务完全启动..."
    sleep 30
    
    # 检查端口
    if nc -z localhost $MP_PORT 2>/dev/null; then
        print_info "MoviePilot (端口 $MP_PORT) ✓"
    else
        print_warning "MoviePilot (端口 $MP_PORT) 启动中..."
    fi
    
    if nc -z localhost $QB_PORT 2>/dev/null; then
        print_info "qBittorrent (端口 $QB_PORT) ✓"
    else
        print_warning "qBittorrent (端口 $QB_PORT) 启动中..."
    fi
    
    if nc -z localhost $EMBY_PORT 2>/dev/null; then
        print_info "Emby (端口 $EMBY_PORT) ✓"
    else
        print_warning "Emby (端口 $EMBY_PORT) 启动中..."
    fi
}

# 生成管理脚本
generate_management_scripts() {
    print_step "生成管理脚本..."
    
    # 停止脚本
    cat > stop.sh << 'EOF'
#!/bin/bash
echo "停止所有MoviePilot服务..."
docker stop moviepilot-main moviepilot-emby moviepilot-qbit 2>/dev/null
if docker ps -a | grep -q moviepilot-clash; then
    docker stop moviepilot-clash 2>/dev/null
fi
echo "服务已停止"
EOF

    # 启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
echo "启动所有MoviePilot服务..."
if docker ps -a | grep -q moviepilot-clash; then
    docker start moviepilot-clash
fi
docker start moviepilot-qbit moviepilot-emby moviepilot-main
echo "服务已启动"
EOF

    # 重启脚本
    cat > restart.sh << 'EOF'
#!/bin/bash
echo "重启所有MoviePilot服务..."
./stop.sh
sleep 5
./start.sh
EOF

    # 卸载脚本
    cat > uninstall.sh << 'EOF'
#!/bin/bash
echo "卸载MoviePilot..."
read -p "确认删除所有容器和数据? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker stop moviepilot-main moviepilot-emby moviepilot-qbit 2>/dev/null
    if docker ps -a | grep -q moviepilot-clash; then
        docker stop moviepilot-clash 2>/dev/null
    fi
    docker rm moviepilot-main moviepilot-emby moviepilot-qbit 2>/dev/null
    if docker ps -a | grep -q moviepilot-clash; then
        docker rm moviepilot-clash 2>/dev/null
    fi
    docker network rm moviepilot-net 2>/dev/null
    docker rmi moviepilot-custom 2>/dev/null
    echo "卸载完成！数据目录保留在: $(pwd)"
else
    echo "取消卸载"
fi
EOF

    # 日志查看脚本
    cat > logs.sh << 'EOF'
#!/bin/bash
SERVICE=${1:-moviepilot-main}
echo "查看 $SERVICE 日志..."
docker logs -f $SERVICE
EOF

    chmod +x *.sh
    
    print_info "管理脚本生成完成 ✓"
}

# 显示部署结果
show_result() {
    clear
    print_header
    echo -e "${GREEN}🎉 部署成功！${NC}"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}📋 服务访问信息${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎬 MoviePilot:    http://$SERVER_IP:$MP_PORT"
    echo "⚡ qBittorrent:   http://$SERVER_IP:$QB_PORT"
    echo "🎭 Emby:          http://$SERVER_IP:$EMBY_PORT"
    if [ "$NEED_PROXY" = true ]; then
        echo "🌐 Clash面板:     http://$SERVER_IP:9090"
    fi
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}🔑 默认账号${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "qBittorrent: $QB_USER / $QB_PASS"
    echo "MoviePilot:  $MP_USER (首次访问时设置密码)"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}📝 后续配置${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 访问MoviePilot完成初始设置"
    echo "2. 安装'115网盘STRM助手'插件"
    echo "3. 配置115网盘Cookie"
    echo "4. 配置MediaWrap插件"
    echo "5. 设置媒体库路径和刮削"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}🛠️ 管理命令${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "启动服务: ./start.sh"
    echo "停止服务: ./stop.sh"
    echo "重启服务: ./restart.sh"
    echo "查看日志: ./logs.sh [服务名]"
    echo "卸载服务: ./uninstall.sh"
    echo
    echo "手动管理:"
    echo "- 查看容器: docker ps | grep moviepilot"
    echo "- 查看日志: docker logs -f moviepilot-main"
    echo "- 进入容器: docker exec -it moviepilot-main bash"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}💡 提示${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "• 所有数据保存在: $BASE_DIR"
    echo "• 如遇问题请查看容器日志排查"
    echo "• 115网盘Cookie需要在MoviePilot中手动配置"
    if [ "$NEED_PROXY" = true ]; then
        echo "• 代理已配置，海外VPS应该能正常访问115网盘"
    fi
    echo
}

# 错误处理
cleanup_on_error() {
    print_error "部署过程中发生错误，正在清理..."
    $DOCKER_CMD stop moviepilot-main moviepilot-emby moviepilot-qbit moviepilot-clash 2>/dev/null || true
    $DOCKER_CMD rm moviepilot-main moviepilot-emby moviepilot-qbit moviepilot-clash 2>/dev/null || true
    exit 1
}

# 主函数
main() {
    trap cleanup_on_error ERR
    
    print_header
    check_requirements
    create_network
    create_directories
    collect_config
    generate_configs
    
    # 按顺序启动服务
    start_clash
    start_qbittorrent
    start_emby
    start_moviepilot
    
    check_services
    generate_management_scripts
    show_result
}

# 执行主函数
main "$@"