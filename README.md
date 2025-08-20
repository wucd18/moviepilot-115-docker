# moviepilot-115-docker
一键部署MoviePilot + 115网盘的Docker解决方案
🚀 基于Docker的MoviePilot + 115网盘自动化媒体管理解决方案

✨ 特性

🎬 MoviePilot: 自动搜索、下载和管理PT站资源
📁 115网盘: 使用STRM文件实现云端媒体播放
⚡ qBittorrent: 高效的种子下载客户端
🎭 Emby: 强大的家庭媒体服务器
🌐 代理支持: 解决海外VPS访问115网盘的限制
🔧 一键部署: 无需复杂配置，几分钟完成部署

🚀 快速开始
curl -fsSL https://raw.githubusercontent.com/wucd18/moviepilot-115-docker/main/quick-deploy.sh | bash

方式二：Git克隆部署
# 克隆仓库
git clone https://github.com/wucd18/moviepilot-115-docker.git
cd moviepilot-115-docker

# 运行部署脚本
chmod +x quick-deploy.sh
./quick-deploy.sh

方式三：手动部署
# 下载配置文件
wget https://raw.githubusercontent.com/wucd18/moviepilot-115-docker/main/docker-compose.yml
wget https://raw.githubusercontent.com/wucd18/moviepilot-115-docker/main/.env.example

# 配置环境变量
cp .env.example .env
nano .env

# 启动服务
docker compose up -d

📋 系统要求

操作系统: Linux (Ubuntu 20.04+, CentOS 7+, Debian 10+)
Docker: 20.10+
Docker Compose: 2.0+
内存: 2GB+ 推荐4GB+
存储: 10GB+ (不含媒体文件)
网络: 海外VPS需要回国代理

🛠️ 服务组件
服务端口说明MoviePilot3000主要管理界面qBittorrent8080下载客户端Emby8096媒体服务器Clash7890代理服务Nginx Proxy Manager81反向代理管理
📖 使用指南
1. 首次配置
部署完成后访问 http://your-ip:3000 进入MoviePilot：

设置超级用户账号
配置下载器（qBittorrent）
配置媒体服务器（Emby）
安装115网盘STRM助手插件

2. 115网盘配置

获取115网盘Cookie
在MoviePilot插件中配置
设置STRM文件生成路径
配置MediaWrap插件进行302重定向

3. PT站点配置
支持主流PT站点：

🍃 Leaves
🌸 CHD
🎭 TTG
🎬 其他支持站点

🔧 高级配置
代理配置
编辑 configs/clash/config.yaml 配置您的代理服务器：
yamlproxies:
  - name: "your-proxy"
    type: ss
    server: your-server.com
    port: 443
    cipher: aes-256-gcm
    password: your-password
自定义路径
修改 .env 文件中的路径配置：
env# 下载目录
DOWNLOADS_PATH=./downloads

# 媒体目录
MEDIA_PATH=./media

# 配置目录
CONFIG_PATH=./configs
🐛 故障排除
常见问题
1. 115网盘访问403错误
bash# 检查代理服务
docker compose logs clash

# 测试代理连接
curl -x http://localhost:7890 https://115.com
2. MoviePilot无法启动
bash# 查看日志
docker compose logs moviepilot

# 重新构建镜像
docker compose build --no-cache moviepilot
3. 权限问题
bash# 修复文件权限
sudo chown -R $USER:$USER .
详细故障排除请查看 故障排除文档
📚 文档

📖 安装指南
⚙️ 配置说明
🔧 故障排除

🤝 贡献
欢迎提交Issue和Pull Request！

Fork 本仓库
创建您的特性分支 (git checkout -b feature/AmazingFeature)
提交您的更改 (git commit -m 'Add some AmazingFeature')
推送到分支 (git push origin feature/AmazingFeature)
打开一个Pull Request

📄 许可证
本项目使用 MIT License 许可证。
⭐ Star History
如果这个项目对您有帮助，请给个Star⭐️支持一下！
Show Image
🙏 致谢

MoviePilot - 优秀的自动化媒体管理工具
qBittorrent - 强大的BitTorrent客户端
Emby - 出色的媒体服务器
Clash - 网络代理工具

📞 联系方式

📧 Email: your-email@example.com
💬 Telegram: @your_telegram
🐛 Issues: GitHub Issues
