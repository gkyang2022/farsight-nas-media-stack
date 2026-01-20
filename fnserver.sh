#!/bin/bash

#====================================================
# 脚本名称：Eric 的媒体服务器一键部署脚本 (优化版)
# 适用环境：飞牛 NAS (FnOS) 或 标准 Debian/Ubuntu
#====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=========================================${NC}"
echo "  飞牛媒体服务一键部署脚本"
echo "  YouTube 頻道：https://www.youtube.com/@Eric-f2v"
echo -e "${GREEN}=========================================${NC}"

# 1. 基础路径配置
BASE_DIR="/vol1/1000"
DOCKER_DIR="$BASE_DIR/docker"
MEDIA_DIR="$BASE_DIR/media"

# 确保以 root 执行
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}错误：请使用 root 权限执行此脚本 (sudo ./fnserver.sh)${NC}"
  exit 1
fi

echo "--- 正在建立所需的目录结构 ---"
mkdir -p "$DOCKER_DIR"/{jellyfin,jellyseerr,jackett,qbittorrent,sonarr,radarr,bazarr}/config
mkdir -p "$MEDIA_DIR"/{downloads,movie,tv}
echo "✅ 目录建立完成！"

# 2. 获取用户 ID
echo -e "\n--- 获取 PUID 和 PGID ---"
read -p "请输入 PUID (默认 1000): " PUID
PUID=${PUID:-1000}
read -p "请输入 PGID (默认 1001): " PGID
PGID=${PGID:-1001}
TZ="Asia/Shanghai"

# 3. 部署函数
deploy_app() {
  local app_name=$1
  local compose_content=$2
  local app_path="$DOCKER_DIR/$app_name"

  echo -e "\n🛠️  正在部署: $app_name"
  echo "$compose_content" > "$app_path/docker-compose.yml"
  
  cd "$app_path"
  docker compose up -d
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ $app_name 启动成功！${NC}"
  else
    echo -e "${RED}❌ $app_name 启动失败，请检查 docker-compose.yml${NC}"
  fi
  cd - > /dev/null
}

# --- 各应用配置开始 ---

# Jellyfin (含硬解支持)
jellyfin_compose="version: '3.5'
services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    network_mode: host
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - $DOCKER_DIR/jellyfin/config:/config
      - $MEDIA_DIR:/media
    devices:
      - /dev/dri:/dev/dri # 显卡硬解
    restart: unless-stopped"

# Jellyseerr
jellyseerr_compose="version: '3.5'
services:
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    ports:
      - 5055:5055
    environment:
      - TZ=$TZ
      - LOG_LEVEL=debug
    volumes:
      - $DOCKER_DIR/jellyseerr/config:/app/config
    restart: unless-stopped"

# Jackett
jackett_compose="version: '3.5'
services:
  jackett:
    image: lscr.io/linuxserver/jackett:latest
    container_name: jackett
    ports:
      - 9117:9117
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - $DOCKER_DIR/jackett/config:/config
      - $MEDIA_DIR/downloads:/downloads
    restart: unless-stopped"

# qBittorrent
qbittorrent_compose="version: '3.5'
services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    ports:
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
      - WEBUI_PORT=8080
    volumes:
      - $DOCKER_DIR/qbittorrent/config:/config
      - $MEDIA_DIR:/media
    restart: unless-stopped"

# Sonarr
sonarr_compose="version: '3.5'
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    ports:
      - 8989:8989
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - $DOCKER_DIR/sonarr/config:/config
      - $MEDIA_DIR:/media
    restart: unless-stopped"

# Radarr
radarr_compose="version: '3.5'
services:
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    ports:
      - 7878:7878
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - $DOCKER_DIR/radarr/config:/config
      - $MEDIA_DIR:/media
    restart: unless-stopped"

# Bazarr
bazarr_compose="version: '3.5'
services:
  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    ports:
      - 6767:6767
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TZ
    volumes:
      - $DOCKER_DIR/bazarr/config:/config
      - $MEDIA_DIR:/media
    restart: unless-stopped"

# --- 执行部署序列 ---
deploy_app "jellyfin" "$jellyfin_compose"
deploy_app "jellyseerr" "$jellyseerr_compose"
deploy_app "jackett" "$jackett_compose"
deploy_app "qbittorrent" "$qbittorrent_compose"
deploy_app "sonarr" "$sonarr_compose"
deploy_app "radarr" "$radarr_compose"
deploy_app "bazarr" "$bazarr_compose"

echo -e "\n${GREEN}--- 🎉 所有应用程序部署完成！ ---${NC}"
echo "请通过 NAS IP 加以下端口访问："
echo "  - Jellyfin:    8096"
echo "  - Jellyseerr:  5055"
echo "  - qBittorrent: 8080"
echo "  - Sonarr:      8989"
echo "  - Radarr:      7878"
echo "  - Jackett:     9117"
echo "  - Bazarr:      6767"
echo -e "\n${GREEN}温馨提示：在 Sonarr/Radarr 设置媒体库时，请统一使用 /media 路径以实现硬链接。${NC}"
