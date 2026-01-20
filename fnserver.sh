#!/bin/bash

#====================================================
# 腳本名稱：Eric 的媒體服務器一鍵部署腳本
# 腳本作者：Eric
# YouTube 頻道：https://www.youtube.com/@Eric-f2v
#
# 描述：本腳本將在飛牛 NAS 上自動部署一套完整的
#       媒體服務器堆棧，包括 Jellyfin、Jellyseerr、
#       Jackett、qBittorrent、Sonarr、Radarr 和 Bazarr。
#
# ---------------------------------------------------
# 執行前請確保已安裝 Docker 和 Docker Compose。
#====================================================

echo "========================================="
echo "飞牛媒体服务一键部署脚本"
echo "YouTube 頻道：https://www.youtube.com/@Eric-f2v"
echo "========================================="


# 定義基礎目錄
BASE_DIR="/vol1/1000"

# 定義子目錄
DOCKER_DIR="$BASE_DIR/docker"
MEDIA_DIR="$BASE_DIR/media"

# 確保腳本以 root 權限執行
if [ "$EUID" -ne 0 ]; then
  echo "--- 錯誤：請使用 root 權限執行此腳本 ---"
  echo "請輸入：sudo ./fnserver.sh"
  exit 1
fi

echo "--- 正在建立所需的目錄結構 ---"
# 建立基礎目錄
mkdir -p "$DOCKER_DIR/jellyfin/config"
mkdir -p "$DOCKER_DIR/jellyseerr/config"
mkdir -p "$DOCKER_DIR/jackett/config"
mkdir -p "$DOCKER_DIR/qbittorrent/config"
mkdir -p "$DOCKER_DIR/sonarr/config"
mkdir -p "$DOCKER_DIR/radarr/config"
mkdir -p "$DOCKER_DIR/bazarr/config"
mkdir -p "$MEDIA_DIR/downloads"
mkdir -p "$MEDIA_DIR/movie"
mkdir -p "$MEDIA_DIR/tv"

echo "✅ 目錄建立完成！"

# 互動式輸入 PUID 和 PGID，並設定默認值
echo -e "\n--- 獲取 PUID 和 PGID ---"
echo "你可以透過在終端機運行 'id' 或 'id <你的用戶名>' 命令來獲取。"
echo "如果你不確定，直接按 Enter 將使用默認值 (PUID: 1000, PGID: 1001)。"

read -p "請輸入 PUID (默認 1000): " PUID
# 驗證輸入，如果為空則使用默認值，否則檢查是否為數字
if [ -z "$PUID" ]; then
    PUID=1000
else
    while ! [[ "$PUID" =~ ^[0-9]+$ ]]
    do
      read -p "PUID 必須是數字，請重新輸入: " PUID
    done
fi

read -p "請輸入 PGID (默認 1001): " PGID
# 驗證輸入，如果為空則使用默認值，否則檢查是否為數字
if [ -z "$PGID" ]; then
    PGID=1001
else
    while ! [[ "$PGID" =~ ^[0-9]+$ ]]
    do
      read -p "PGID 必須是數字，請重新輸入: " PGID
    done
fi

echo "選定的 PUID: $PUID, PGID: $PGID"
echo "--- 開始依序建立 Docker Compose 檔案並啟動容器 ---"

# 函數：建立並啟動 Docker Compose
deploy_app() {
  local app_name=$1
  local compose_content=$2
  local compose_file="$DOCKER_DIR/$app_name/docker-compose.yml"

  echo -e "\n-----------------------------------------------------"
  echo "🛠️ 正在建立 **$app_name** 的 Docker Compose 檔案..."
  echo "$compose_content" > "$compose_file"

  echo "🚀 正在啟動 **$app_name** 容器..."
  cd "$DOCKER_DIR/$app_name"
  docker compose up -d
  
  if [ $? -eq 0 ]; then
    echo "✅ $app_name 啟動成功！"
  else
    echo "❌ 警告：$app_name 啟動失敗，請檢查日誌。"
  fi
  
  cd - > /dev/null
}

# Jellyfin 的 compose 檔案內容 (已變更映像檔)
jellyfin_compose=$(cat <<EOL
version: "3.5"
services:
  jellyfin:
    image: linuxserver/jellyfin
    container_name: jellyfin
    user: $PUID:$PGID
    ports:
      - "8096:8096"
    volumes:
      - "$DOCKER_DIR/jellyfin/config:/config"
      - "$MEDIA_DIR/movie:/movie"
      - "$MEDIA_DIR/tv:/tv"
    restart: "unless-stopped"
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=Asia/Taipei
EOL
)
deploy_app "jellyfin" "$jellyfin_compose"

# Jellyseerr 的 compose 檔案內容
jellyseerr_compose=$(cat <<EOL
version: "3.5"
services:
  jellyseerr:
    image: fallenbagel/jellyseerr
    container_name: jellyseerr
    volumes:
      - "$DOCKER_DIR/jellyseerr/config:/app/config"
    ports:
      - "5055:5055"
    restart: "unless-stopped"
    environment:
      - LOG_LEVEL=debug
      - TZ=Asia/Taipei
EOL
)
deploy_app "jellyseerr" "$jellyseerr_compose"

# Jackett 的 compose 檔案內容
jackett_compose=$(cat <<EOL
version: "3.5"
services:
  jackett:
    image: lscr.io/linuxserver/jackett
    container_name: jackett
    volumes:
      - "$DOCKER_DIR/jackett/config:/config"
      - "$MEDIA_DIR/downloads:/downloads"
    ports:
      - "9117:9117"
    restart: "unless-stopped"
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=Asia/Taipei
EOL
)
deploy_app "jackett" "$jackett_compose"

# qBittorrent 的 compose 檔案內容
qbittorrent_compose=$(cat <<EOL
version: "3.5"
services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent
    container_name: qbittorrent
    volumes:
      - "$DOCKER_DIR/qbittorrent/config:/config"
      - "$MEDIA_DIR/downloads:/downloads"
      - "$MEDIA_DIR:/media"
    ports:
      - "6881:6881"
      - "6881:6881/udp"
      - "8080:8080"
    restart: "unless-stopped"
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=Asia/Taipei
EOL
)
deploy_app "qbittorrent" "$qbittorrent_compose"

# Sonarr 的 compose 檔案內容
sonarr_compose=$(cat <<EOL
version: "3.5"
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr
    container_name: sonarr
    volumes:
      - "$DOCKER_DIR/sonarr/config:/config"
      - "$MEDIA_DIR/tv:/tv"
      - "$MEDIA_DIR/downloads:/downloads"
    ports:
      - "8989:8989"
    restart: "unless-stopped"
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=Asia/Taipei
EOL
)
deploy_app "sonarr" "$sonarr_compose"

# Radarr 的 compose 檔案內容
radarr_compose=$(cat <<EOL
version: "3.5"
services:
  radarr:
    image: lscr.io/linuxserver/radarr
    container_name: radarr
    volumes:
      - "$DOCKER_DIR/radarr/config:/config"
      - "$MEDIA_DIR/movie:/movie"
      - "$MEDIA_DIR/downloads:/downloads"
    ports:
      - "7878:7878"
    restart: "unless-stopped"
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=Asia/Taipei
EOL
)
deploy_app "radarr" "$radarr_compose"

# Bazarr 的 compose 檔案內容
bazarr_compose=$(cat <<EOL
version: "3.5"
services:
  bazarr:
    image: lscr.io/linuxserver/bazarr
    container_name: bazarr
    volumes:
      - "$DOCKER_DIR/bazarr/config:/config"
      - "$MEDIA_DIR/movie:/movie"
      - "$MEDIA_DIR/tv:/tv"
    ports:
      - "6767:6767"
    restart: "unless-stopped"
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=Asia/Taipei
EOL
)
deploy_app "bazarr" "$bazarr_compose"

echo -e "\n--- 🎉 所有應用程式部署並啟動完成！ 🎉 ---"
echo "現在你可以透過 NAS 的 IP 和對應的埠號來存取每個應用的網頁介面。"
echo "  - Jellyfin:     http://<NAS_IP>:8096"
echo "  - Jellyseerr:   http://<NAS_IP>:5055"
echo "  - Jackett:      http://<NAS_IP>:9117"
echo "  - qBittorrent:  http://<NAS_IP>:8080"
echo "  - Sonarr:       http://<NAS_IP>:8989"
echo "  - Radarr:       http://<NAS_IP>:7878"
echo "  - Bazarr:       http://<NAS_IP>:6767"

echo -e "\n--- 感謝使用，祝你有個愉快的影音體驗！ ---"
echo "📺 更多 NAS 教程，歡迎訂閱 Eric 的 YouTube 頻道：https://www.youtube.com/@Eric-f2v"
