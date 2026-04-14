#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="/docker"
LOG_FILE="/var/log/docker-app-installer.log"

# =========================
# 通用函数
# =========================
log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

pause() {
  read -rp "按回车继续..."
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "请使用 root 执行此脚本。"
    exit 1
  fi
}

ensure_base_dir() {
  mkdir -p "$BASE_DIR"
}

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  else
    echo "docker-compose"
  fi
}

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

get_server_ip() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -z "${ip:-}" ]]; then
    ip="127.0.0.1"
  fi
  echo "$ip"
}

port_in_use() {
  local port="$1"
  ss -lntup 2>/dev/null | awk '{print $5}' | grep -E "[:.]${port}$" >/dev/null 2>&1
}

prompt_port() {
  local name="$1"
  local default_port="$2"
  local value

  while true; do
    read -rp "请输入 ${name} 端口 [默认 ${default_port}]: " value
    value="${value:-$default_port}"
    if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 && value <= 65535 )); then
      echo "$value"
      return 0
    else
      echo "端口格式不合法，请重新输入。"
    fi
  done
}

check_and_prompt_port() {
  local name="$1"
  local default_port="$2"
  local port="$default_port"

  while port_in_use "$port"; do
    echo "端口 ${port} 已被占用。"
    read -rp "是否修改 ${name} 端口？[Y/n] " ans
    ans="${ans:-Y}"
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      port=$(prompt_port "$name" "$default_port")
    else
      echo "已取消安装。"
      exit 1
    fi
  done

  echo "$port"
}

install_docker() {
  if ! check_cmd docker; then
    echo "正在安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
  else
    echo "Docker 已安装。"
  fi

  if ! docker compose version >/dev/null 2>&1 && ! check_cmd docker-compose; then
    echo "正在安装 Docker Compose 插件..."
    if check_cmd apt-get; then
      apt-get update
      apt-get -y install docker-compose-plugin
    elif check_cmd yum; then
      yum -y install docker-compose-plugin || true
    elif check_cmd dnf; then
      dnf -y install docker-compose-plugin || true
    fi
  fi
}

check_required_dirs() {
  mkdir -p "$BASE_DIR"
  mkdir -p /media/downloads
}

show_service_url() {
  local name="$1"
  local port="$2"
  local ip
  ip="$(get_server_ip)"
  echo "- ${name}: http://${ip}:${port}"
}

show_service_url_https() {
  local name="$1"
  local port="$2"
  local ip
  ip="$(get_server_ip)"
  echo "- ${name}: https://${ip}:${port}"
}

# =========================
# 单应用安装
# =========================
install_portainer() {
  local dir="$BASE_DIR/portainer"
  local port
  port=$(check_and_prompt_port "Portainer" 9000)
  mkdir -p "$dir/data"

  cat > "$dir/docker-compose.yml" <<EOF
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    ports:
      - "${port}:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${dir}/data:/data
    restart: always
EOF

  (cd "$dir" && $(compose_cmd) up -d)
  echo
  echo "Portainer 安装完成。"
  echo "访问地址："
  show_service_url "Portainer" "$port"
}

install_filebrowser() {
  local dir="$BASE_DIR/filebrowser"
  local port
  port=$(check_and_prompt_port "FileBrowser" 1234)
  mkdir -p "$dir/config" "$dir/data"

  cat > "$dir/docker-compose.yml" <<EOF
services:
  filebrowser:
    image: ysx88/filebrowser:latest
    container_name: filebrowser
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
    ports:
      - "${port}:80"
    volumes:
      - /:/srv
      - ${dir}/config:/etc/config.json
      - ${dir}/data:/etc/database.db
    restart: always
EOF

  (cd "$dir" && $(compose_cmd) up -d)
  echo
  echo "FileBrowser 安装完成。"
  echo "访问地址："
  show_service_url "FileBrowser" "$port"
}

install_qbittorrent() {
  local dir="$BASE_DIR/qbittorrent"
  local webui bt
  webui=$(check_and_prompt_port "qBittorrent WebUI" 8080)
  bt=$(check_and_prompt_port "qBittorrent BT" 6881)
  mkdir -p "$dir/config"

  cat > "$dir/docker-compose.yml" <<EOF
services:
  qbittorrent:
    image: ysx88/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
      - WEBUI_PORT=${webui}
    ports:
      - "${webui}:8080"
      - "${bt}:6881"
      - "${bt}:6881/udp"
    volumes:
      - ${dir}/config:/config
      - /media/downloads:/downloads
    restart: always
EOF

  (cd "$dir" && $(compose_cmd) up -d)
  echo
  echo "qBittorrent 安装完成。"
  echo "访问地址："
  show_service_url "qBittorrent WebUI" "$webui"
  echo "- qBittorrent BT: ${bt}/tcp, ${bt}/udp"
}

# =========================
# AV 媒体订阅服务
# =========================
install_av_stack() {
  local dir="$BASE_DIR/av-stack"
  mkdir -p "$dir"

  local db_online_port avdb_port mdc_port filebrowser_port qb_webui qb_bt emby_port emby_https_port
  db_online_port=$(check_and_prompt_port "db_online" 9090)
  avdb_port=$(check_and_prompt_port "avdb" 8000)
  mdc_port=$(check_and_prompt_port "mdc" 9208)
  filebrowser_port=$(check_and_prompt_port "filebrowser" 1234)
  qb_webui=$(check_and_prompt_port "qBittorrent WebUI" 8080)
  qb_bt=$(check_and_prompt_port "qBittorrent BT" 6881)
  emby_port=$(check_and_prompt_port "Emby" 8096)
  emby_https_port=$(check_and_prompt_port "Emby HTTPS" 8920)

  cat > "$dir/docker-compose.yml" <<EOF
services:
  postgres_db_online:
    image: postgres:16-alpine
    container_name: postgres_db_online
    restart: unless-stopped
    volumes:
      - ./postgres_db_online/data:/var/lib/postgresql/data
    environment:
      - TZ=Asia/Shanghai
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=db_online
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d db_online"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - internal_network

  postgres_avdb:
    image: postgres:16-alpine
    container_name: postgres_avdb
    restart: unless-stopped
    shm_size: 128mb
    volumes:
      - ./postgres_avdb/data:/var/lib/postgresql/data
    environment:
      - TZ=Asia/Shanghai
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=avdb
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d avdb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - internal_network

  db_online:
    image: dbonline/db_online:latest
    container_name: db_online
    restart: unless-stopped
    ports:
      - "${db_online_port}:9090"
    volumes:
      - ./db_online/data:/app/data
      - ./db_online/cache:/app/cache
      - ./db_online/logs:/app/logs
      - /media:/media
    environment:
      - TZ=Asia/Shanghai
      - DB_HOST=postgres_db_online
      - DB_PORT=5432
      - DB_USER=postgres
      - DB_PASSWORD=postgres
      - DB_NAME=db_online
      - DATABASE_URL=postgresql://postgres:postgres@postgres_db_online:5432/db_online
      - POSTGRES_HOST=postgres_db_online
      - POSTGRES_PORT=5432
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=db_online
    depends_on:
      postgres_db_online:
        condition: service_healthy
    networks:
      - internal_network

  avdb:
    image: leolitaly/avdb:latest
    container_name: avdb
    restart: unless-stopped
    ports:
      - "${avdb_port}:8000"
    volumes:
      - ./avdb:/data
      - /media:/media
    environment:
      - TZ=Asia/Shanghai
      - DATABASE_URL=postgresql://postgres:postgres@postgres_avdb:5432/avdb
    depends_on:
      postgres_avdb:
        condition: service_healthy
    networks:
      - internal_network

  mdc:
    image: mdcng/mdc:latest
    container_name: mdc
    restart: unless-stopped
    ports:
      - "${mdc_port}:9208"
    volumes:
      - ./mdc/data:/config
      - /media:/media
    networks:
      - internal_network

  filebrowser:
    image: ysx88/filebrowser:latest
    container_name: filebrowser-av
    restart: unless-stopped
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
    ports:
      - "${filebrowser_port}:80"
    volumes:
      - /:/srv
      - ./filebrowser/config:/etc/config.json
      - ./filebrowser/data:/etc/database.db
    networks:
      - internal_network

  qbittorrent:
    image: ysx88/qbittorrent:latest
    container_name: qbittorrent-av
    restart: unless-stopped
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
      - WEBUI_PORT=${qb_webui}
    ports:
      - "${qb_webui}:8080"
      - "${qb_bt}:6881"
      - "${qb_bt}:6881/udp"
    volumes:
      - ./qbittorrent/config:/config
      - /media/downloads:/downloads
    networks:
      - internal_network

  emby:
    image: ysx88/embyserver:latest
    container_name: emby-av
    restart: unless-stopped
    environment:
      - UID=0
      - GID=0
      - TZ=Asia/Shanghai
    ports:
      - "${emby_port}:8096"
      - "${emby_https_port}:8920"
    volumes:
      - ./emby/config:/config
      - ./emby/cache:/cache
      - /media:/media
    devices:
      - /dev/dri:/dev/dri
    networks:
      - internal_network

networks:
  internal_network:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: "172.20.0.0/16"
EOF

  (cd "$dir" && $(compose_cmd) up -d)
  echo
  echo "AV 媒体订阅服务安装完成。"
  echo "访问地址："
  show_service_url "db_online" "$db_online_port"
  show_service_url "avdb" "$avdb_port"
  show_service_url "mdc" "$mdc_port"
  show_service_url "filebrowser" "$filebrowser_port"
  show_service_url "qBittorrent WebUI" "$qb_webui"
  show_service_url "Emby" "$emby_port"
  echo "- Emby HTTPS: https://$(get_server_ip):${emby_https_port}"
}

# =========================
# 影视订阅服务
# =========================
install_movie_stack() {
  local dir="$BASE_DIR/movie-stack"
  mkdir -p "$dir"

  local portainer_port filebrowser_port dockercopilot_port qb_webui qb_bt emby_port moviepilot_port cookiecloud_port
  portainer_port=$(check_and_prompt_port "portainer-zh" 9000)
  filebrowser_port=$(check_and_prompt_port "filebrowser" 1234)
  dockercopilot_port=$(check_and_prompt_port "dockercopilot" 12712)
  qb_webui=$(check_and_prompt_port "qBittorrent WebUI" 8080)
  qb_bt=$(check_and_prompt_port "qBittorrent BT" 6881)
  emby_port=$(check_and_prompt_port "Emby" 8096)
  moviepilot_port=$(check_and_prompt_port "MoviePilot" 3000)
  cookiecloud_port=$(check_and_prompt_port "CookieCloud" 8088)

  cat > "$dir/docker-compose.yml" <<EOF
services:
  portainer-zh:
    image: ysx88/portainer-ce
    container_name: portainer-zh
    ports:
      - "${portainer_port}:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always

  filebrowser:
    image: ysx88/filebrowser:latest
    container_name: filebrowser-movie
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
    ports:
      - "${filebrowser_port}:80"
    volumes:
      - /:/srv
      - /docker/filebrowser-movie/config:/etc/config.json
      - /docker/filebrowser-movie/data:/etc/database.db
    restart: always

  dockercopilot:
    container_name: dockercopilot
    restart: always
    privileged: true
    network_mode: bridge
    ports:
      - "${dockercopilot_port}:12712"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /docker/dockercopilot/data:/data
    environment:
      - TZ=Asia/Shanghai
      - DOCKER_HOST=unix:///var/run/docker.sock
      - secretKey=change_me
    image: 0nlylty/dockercopilot:latest

  qbittorrent:
    image: ysx88/qbittorrent:latest
    container_name: qbittorrent-movie
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
      - WEBUI_PORT=${qb_webui}
    ports:
      - "${qb_webui}:8080"
      - "${qb_bt}:6881"
      - "${qb_bt}:6881/udp"
    volumes:
      - /docker/qbittorrent-movie/config:/config
      - /media/downloads:/downloads
    restart: always

  emby:
    image: ysx88/embyserver:latest
    container_name: Emby
    environment:
      - UID=0
      - GID=0
      - TZ=Asia/Shanghai
      - PROXY_HOST=http://10.18.18.2:7890
    ports:
      - "${emby_port}:8096"
    volumes:
      - /docker/emby/config:/config
      - /docker/emby/config/cache:/cache
      - /media:/media
    devices:
      - /dev/dri:/dev/dri
    restart: always

  moviepilot:
    stdin_open: true
    tty: true
    image: ysx88/moviepilot:latest
    container_name: moviePilot
    hostname: moviepilot
    environment:
      - NGINX_PORT=3000
      - PORT=3001
      - UID=0
      - GID=0
      - UMASK=000
      - TZ=Asia/Shanghai
      - SUPERUSER=change_me
      - SUPERUSER_PASSWORD=change_me
      - API_TOKEN=change_me
      - AUTH_SITE=iyuu
      - IYUU_SIGN=change_me
      - PROXY_HOST=http://change_me
      - MESSAGER=wechat
      - WECHAT_CORPID=change_me
      - WECHAT_APP_SECRET=change_me
      - WECHAT_APP_ID=change_me
      - WECHAT_TOKEN=change_me
      - WECHAT_ENCODING_AESKEY=change_me
      - WECHAT_PROXY=http://change_me
    ports:
      - "${moviepilot_port}:3000"
    volumes:
      - /media:/media
      - /docker/moviepilot/config:/config
      - /docker/moviepilot/core:/moviepilot/.cache/ms-playwright
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/hosts:/etc/hosts
    restart: always

  cookiecloud:
    image: ysx88/cookiecloud:latest
    container_name: cookiecloud
    environment:
      - API_ROOT=/skywrt
    ports:
      - "${cookiecloud_port}:8088"
    volumes:
      - /docker/cookiecloud/data:/data/api/data
    restart: always

  watchtower:
    command: "-i 3600 --cleanup moviePilot"
    container_name: watchtower
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=Asia/Shanghai
    restart: always
EOF

  (cd "$dir" && $(compose_cmd) up -d)
  echo
  echo "影视订阅服务安装完成。"
  echo "访问地址："
  show_service_url "Portainer" "$portainer_port"
  show_service_url "FileBrowser" "$filebrowser_port"
  show_service_url "Dockercopilot" "$dockercopilot_port"
  show_service_url "qBittorrent WebUI" "$qb_webui"
  show_service_url "Emby" "$emby_port"
  show_service_url "MoviePilot" "$moviepilot_port"
  show_service_url "CookieCloud" "$cookiecloud_port"
  echo "- qBittorrent BT: ${qb_bt}/tcp, ${qb_bt}/udp"
}

# =========================
# 状态与卸载
# =========================
show_status() {
  echo "Docker: $(docker --version 2>/dev/null || echo 未安装)"
  echo "Compose: $(docker compose version 2>/dev/null || docker-compose version 2>/dev/null || echo 未安装)"
  echo
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true
}

uninstall_stack() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    (cd "$dir" && $(compose_cmd) down) || true
    echo "已停止：$dir"
  else
    echo "目录不存在：$dir"
  fi
}

# =========================
# 菜单
# =========================
single_app_menu() {
  while true; do
    clear
    cat <<EOF
========== 单应用安装 ==========

1) Portainer
2) qBittorrent
3) FileBrowser
4) 返回主菜单
EOF
    read -rp "请选择: " choice
    case "$choice" in
      1) install_portainer; pause ;;
      2) install_qbittorrent; pause ;;
      3) install_filebrowser; pause ;;
      4) return ;;
      *) echo "无效选择"; pause ;;
    esac
  done
}

stack_menu() {
  while true; do
    clear
    cat <<EOF
========== 组合服务安装 ==========

1) AV 媒体订阅服务
2) 影视订阅服务
3) 返回主菜单
EOF
    read -rp "请选择: " choice
    case "$choice" in
      1) install_av_stack; pause ;;
      2) install_movie_stack; pause ;;
      3) return ;;
      *) echo "无效选择"; pause ;;
    esac
  done
}

uninstall_menu() {
  while true; do
    clear
    cat <<EOF
========== 卸载菜单 ==========

1) 卸载 AV 媒体订阅服务
2) 卸载 影视订阅服务
3) 返回主菜单
EOF
    read -rp "请选择: " choice
    case "$choice" in
      1) uninstall_stack "$BASE_DIR/av-stack"; pause ;;
      2) uninstall_stack "$BASE_DIR/movie-stack"; pause ;;
      3) return ;;
      *) echo "无效选择"; pause ;;
    esac
  done
}

main_menu() {
  while true; do
    clear
    cat <<EOF
========================================
       Docker 服务一键部署器
========================================

1) 基础安装（Docker + Docker Compose）
2) 单应用安装
3) 组合服务安装
4) 应用卸载
5) 查看当前状态
6) 退出
EOF
    read -rp "请选择: " choice
    case "$choice" in
      1) install_docker; pause ;;
      2) single_app_menu ;;
      3) stack_menu ;;
      4) uninstall_menu ;;
      5) show_status; pause ;;
      6) exit 0 ;;
      *) echo "无效选择"; pause ;;
    esac
  done
}

# =========================
# 主入口
# =========================
require_root
ensure_base_dir
check_required_dirs
main_menu
