#!/bin/bash
# quick-deploy.sh - MoviePilot + 115网盘 一键部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} MoviePilot + 115网盘 部署工具${NC}"
    echo -e "${BLUE}================================${NC}"
}

# 检查系统要求
check_requirements() {
    print_status "检查系统要求..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装!"
        echo "请访问 https://docs.docker.com/get-docker/ 安装Docker"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose未安装!"
        echo "请安装Docker Compose v2"
        exit 1
    fi
    
    print_status "系统要求检查完成 ✓"
}

# 创建项目目录
create_directories() {
    print_status "创建项目目录..."
    
    PROJECT_DIR="moviepilot-115"
    
    if [ -d "$PROJECT_DIR" ]; then
        print_warning "目录 $PROJECT_DIR 已存在"
        read -p "是否删除并重新创建? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$PROJECT_DIR"
        else
            print_error "部署已取消"
            exit 1
        fi
    fi
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # 创建子目录
    mkdir -p {clash,qbit,emby,moviepilot,downloads,media/{movies,tv,anime},mp-core,npm/{data,letsencrypt}}
    
    print_status "目录创建完成 ✓"
}

# 用户配置输入
collect_user_config() {
    print_status "收集用户配置..."
    
    echo "请输入以下配置信息（直接回车使用默认值）:"
    
    # qBittorrent配置
    read -p "qBittorrent用户名 [admin]: " QB_USER
    QB_USER=${QB_USER:-admin}
    
    read -s -p "qBittorrent密码 [admin123]: " QB_PASS
    QB_PASS=${QB_PASS:-admin123}
    echo
    
    # 服务器IP
    DEFAULT_IP=$(hostname -I | awk '{print $1}')
    read -p "服务器IP地址 [$DEFAULT_IP]: " SERVER_IP
    SERVER_IP=${SERVER_IP:-$DEFAULT_IP}
    
    # MoviePilot配置
    read -p "MoviePilot超级用户名 [admin]: " MP_USER
    MP_USER=${MP_USER:-admin}
    
    # PT站配置
    echo
    print_warning "PT站配置 (可稍后在MoviePilot中配置):"
    read -p "认证站点 (如: leaves): " AUTH_SITE
    read -p "用户UID: " LEAVES_UID
    read -p "PassKey: " LEAVES_PASSKEY
    
    # GitHub Token
    read -p "GitHub Token (防止API限制): " GITHUB_TOKEN
    
    # 代理配置
    echo
    print_warning "代理配置 (用于解决115网盘访问问题):"
    read -p "代理服务器地址: " PROXY_SERVER
    read -p "代理端口 [443]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-443}
    read -p "代理密码: " PROXY_PASS
    
    print_status "配置收集完成 ✓"
}

# 生成配置文件
generate_configs() {
    print_status "生成配置文件..."
    
    # .env文件
    cat > .env << EOF
# qBittorrent配置
QB_USERNAME=$QB_USER
QB_PASSWORD=$QB_PASS

# 服务器配置
SERVER_IP=$SERVER_IP

# MoviePilot配置
MP_SUPERUSER=$MP_USER
AUTH_SITE=$AUTH_SITE
LEAVES_UID=$LEAVES_UID
LEAVES_PASSKEY=$LEAVES_PASSKEY
GITHUB_TOKEN=$GITHUB_TOKEN

# 代理配置
PROXY_SERVER=$PROXY_SERVER
PROXY_PORT=$PROXY_PORT
PROXY_PASS=$PROXY_PASS
EOF

    # Docker Compose文件
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  clash:
    image: dreamacro/clash:latest
    container_name: moviepilot-clash
    restart: unless-stopped
    ports:
      - "7890:7890"
      - "7891:9090"
    volumes:
      - ./clash:/root/.config/clash
    networks:
      - moviepilot-net

  qbittorrent:
    image: linuxserver/qbittorrent:4.6.5
    container_name: moviepilot-qbit
    restart: unless-stopped
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
      - WEBUI_PORT=8080
      - TORRENTING_PORT=32156
      - QB_PASSWORD=${QB_PASSWORD}
      - QB_USERNAME=${QB_USERNAME}
    volumes:
      - ./qbit:/config
      - ./downloads:/downloads
      - ./media:/media
    ports:
      - "8080:8080"
      - "32156:32156"
    networks:
      - moviepilot-net

  emby:
    image: amilys/embyserver:latest
    container_name: moviepilot-emby
    restart: unless-stopped
    environment:
      - PUID=0
      - PGID=0
      - GIDLIST=0
      - TZ=Asia/Shanghai
      - EMBY_PublishedServerUrl=${SERVER_IP}
    volumes:
      - ./emby:/config
      - ./media:/media
    ports:
      - "8096:8096"
      - "8920:8920"
      - "7359:7359/udp"
      - "1900:1900/udp"
    privileged: true
    networks:
      - moviepilot-net

  moviepilot:
    build:
      context: .
      dockerfile: Dockerfile.moviepilot
    container_name: moviepilot-main
    restart: unless-stopped
    stdin_open: true
    tty: true
    environment:
      - NGINX_PORT=3000
      - PORT=3001
      - PUID=0
      - PGID=0
      - UMASK=000
      - SUPERUSER=${MP_SUPERUSER}
      - TZ=Asia/Shanghai
      - AUTH_SITE=${AUTH_SITE}
      - LEAVES_UID=${LEAVES_UID}
      - LEAVES_PASSKEY=${LEAVES_PASSKEY}
      - GITHUB_TOKEN=${GITHUB_TOKEN}
    volumes:
      - ./moviepilot:/config
      - ./media:/media
      - ./downloads:/downloads
      - ./mp-core:/moviepilot/.cache/ms-playwright
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./proxychains.conf:/etc/proxychains.conf:ro
    ports:
      - "3000:3000"
      - "65042:65042"
    depends_on:
      - clash
      - qbittorrent
    networks:
      - moviepilot-net

networks:
  moviepilot-net:
    driver: bridge
EOF

    # Clash配置
    cat > clash/config.yaml << EOF
mixed-port: 7890
allow-lan: true
mode: Rule
log-level: info
external-controller: "0.0.0.0:9090"
bind-address: "0.0.0.0"

proxies:
  - name: "proxy"
    type: ss
    server: $PROXY_SERVER
    port: $PROXY_PORT
    cipher: aes-256-gcm
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

    # 其他配置文件...
    cat > proxychains.conf << 'EOF'
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
http 172.17.0.1 7890
EOF

    cat > Dockerfile.moviepilot << 'EOF'
FROM jxxghp/moviepilot-v2:latest

USER root
RUN apt-get update && \
    apt-get install -y proxychains-ng curl && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint-wrapper.sh /entrypoint-wrapper.sh
RUN chmod +x /entrypoint-wrapper.sh

ENTRYPOINT ["/entrypoint-wrapper.sh"]
EOF

    cat > entrypoint-wrapper.sh << 'EOF'
#!/bin/sh
echo "启动MoviePilot with proxychains4..."
sleep 10

if curl -x http://172.17.0.1:7890 --connect-timeout 5 http://www.baidu.com > /dev/null 2>&1; then
    echo "使用proxychains4启动"
    exec proxychains4 /entrypoint.sh "$@"
else
    echo "直接启动MoviePilot"
    exec /entrypoint.sh "$@"
fi
EOF
    
    chmod +x entrypoint-wrapper.sh
    
    print_status "配置文件生成完成 ✓"
}

# 部署服务
deploy_services() {
    print_status "开始部署服务..."
    
    # 构建镜像
    print_status "构建MoviePilot镜像..."
    docker compose build --no-cache
    
    # 启动服务
    print_status "启动所有服务..."
    docker compose up -d
    
    # 等待服务启动
    print_status "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    print_status "检查服务状态..."
    docker compose ps
    
    print_status "服务部署完成 ✓"
}

# 显示访问信息
show_access_info() {
    print_header
    echo -e "${GREEN}部署成功! 🎉${NC}"
    echo
    echo "访问地址:"
    echo "- MoviePilot:    http://$SERVER_IP:3000"
    echo "- qBittorrent:   http://$SERVER_IP:8080"
    echo "- Emby:          http://$SERVER_IP:8096"
    echo
    echo "默认账号:"
    echo "- qBittorrent:   $QB_USER / $QB_PASS"
    echo "- MoviePilot:    $MP_USER (首次访问时设置密码)"
    echo
    echo "后续配置:"
    echo "1. 访问MoviePilot，完成初始设置"
    echo "2. 安装'115网盘STRM助手'插件"
    echo "3. 配置115网盘Cookie"
    echo "4. 设置媒体库路径"
    echo
    echo "管理命令:"
    echo "- 查看日志: docker compose logs -f [服务名]"
    echo "- 重启服务: docker compose restart [服务名]"
    echo "- 停止所有: docker compose down"
    echo
}

# 主函数
main() {
    print_header
    
    check_requirements
    create_directories
    collect_user_config
    generate_configs
    deploy_services
    show_access_info
}

# 错误处理
trap 'print_error "部署过程中发生错误!"; exit 1' ERR

# 执行主函数
main