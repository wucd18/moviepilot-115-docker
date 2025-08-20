# MoviePilot + 115网盘 纯Docker部署

[![Docker](https://img.shields.io/badge/Docker-Only-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)](https://github.com/YOUR_USERNAME/moviepilot-115-docker)

> 🚀 **无需Docker Compose**，纯Docker命令部署MoviePilot + 115网盘解决方案

## ✨ 特色

- 🎯 **纯Docker部署** - 只需要Docker，无需Docker Compose
- 🎬 **MoviePilot** - 自动搜索下载PT站资源
- 📁 **115网盘** - STRM文件云端播放
- ⚡ **qBittorrent** - 种子下载客户端  
- 🎭 **Emby** - 家庭媒体服务器
- 🌐 **代理支持** - 解决海外VPS访问限制
- 🔧 **一键部署** - 交互式配置，3分钟完成

## 🚀 一键部署

### 方式一：直接运行（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/wucd18/moviepilot-115-docker/refs/heads/main/pure_docker_deploy.sh | bash
```

### 方式二：下载后运行

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/moviepilot-115-docker/main/pure-docker-deploy.sh
chmod +x pure-docker-deploy.sh
./pure-docker-deploy.sh
```

## 📋 系统要求

| 项目 | 要求 |
|------|------|
| **操作系统** | Linux (Ubuntu 18.04+, CentOS 7+, Debian 9+) |
| **Docker** | 18.09+ |
| **内存** | 2GB+ (推荐4GB+) |
| **磁盘** | 10GB+ (不含媒体文件) |
| **网络** | 海外VPS需要回国代理 |

## 🎯 部署流程

### 1. 系统检查
脚本会自动检查：
- Docker是否安装并运行
- 用户权限是否足够
- 网络连接是否正常

### 2. 交互式配置
按提示输入：
- qBittorrent账号密码
- 服务器IP地址
- PT站点信息（可选）
- 代理配置（海外VPS必需）
- 端口配置

### 3. 自动部署
脚本将依次启动：
1. Clash代理（如果需要）
2. qBittorrent下载器
3. Emby媒体服务器
4. MoviePilot主程序

## 🛠️ 服务说明

| 服务 | 默认端口 | 说明 |
|------|----------|------|
| MoviePilot | 3000 | 主管理界面 |
| qBittorrent | 8080 | 下载客户端WebUI |
| Emby | 8096 | 媒体服务器 |
| Clash | 7890 | 代理服务（可选） |

## 📖 使用指南

### 初次配置

1. **访问MoviePilot** (`http://your-ip:3000`)
   - 设置超级用户密码
   - 配置基本设置

2. **配置下载器**
   - 类型：qBittorrent
   - 地址：`http://moviepilot-qbit:8080`
   - 用户名/密码：部署时设置的账号

3. **配置媒体服务器**
   - 类型：Emby
   - 地址：`http://moviepilot-emby:8096`

4. **安装插件**
   - 115网盘STRM助手
   - MediaWrap（用于302重定向）

### 115网盘配置

1. **获取Cookie**
   ```bash
   # 浏览器F12，找到115.com请求的Cookie
   # 复制完整Cookie字符串
   ```

2. **配置插件**
   - 进入MoviePilot插件页面
   - 找到"115网盘STRM助手"
   - 填入Cookie和相关配置

3. **设置路径**
   - 本地路径：`/media`
   - 115网盘路径：根据实际情况

## 🔧 管理操作

部署完成后，在项目目录下有以下管理脚本：

```bash
# 启动所有服务
./start.sh

# 停止所有服务  
./stop.sh

# 重启所有服务
./restart.sh

# 查看服务日志
./logs.sh [服务名]

# 完全卸
