# Docker 服务一键部署器

一个基于 Bash 的 Docker 服务一键部署脚本,支持:

- 基础安装 Docker / Docker Compose
- 单应用安装
- 组合服务安装
- 安装前端口冲突检测
- 冲突时可手动修改端口
- 安装完成后自动显示访问地址
- 应用卸载
- 当前状态查看

适合在 Linux 服务器上快速部署常用 Docker 服务,并方便后续扩展。

---

## 功能说明

### 1. 基础安装

脚本可一键安装:

- Docker
- Docker Compose

### 2. 单应用安装

当前支持:

- Portainer
- qBittorrent
- FileBrowser

### 3. 组合服务安装

当前支持:

- AV 媒体订阅服务
- 影视订阅服务

### 4. 冲突处理

脚本在安装前会检查端口是否已被占用:

- 若端口空闲,则直接安装
- 若端口冲突,则提示用户修改端口
- 用户可手动输入新端口继续安装

### 5. 安装完成自动提示访问地址

安装完成后,脚本会自动输出各服务的访问地址,方便直接打开网页使用。

---

## 支持环境

```
- Debian / Ubuntu / CentOS / Rocky Linux / AlmaLinux / Fedora 等主流 Linux 发行版
- 支持 Docker Compose v2
- 需要 root 权限运行
```

---

## 项目目录

建议如下:

```
docker-service-installer/
├── docker-app-installer.sh
├── README.md
├── LICENSE
└── .gitignore
```

---

## 快速开始

### 1. 下载脚本

将 docker-app-installer.sh 保存到服务器本地,例如:

```
wget -O docker-app-installer.sh https://raw.githubusercontent.com/skywrt/docker-app-installer/main/docker-app-installer.sh
```

或者手动创建文件并粘贴脚本内容。

### 2. 授权执行

```
chmod +x docker-app-installer.sh
```

### 3. 运行脚本

```
sudo ./docker-app-installer.sh
```
---

## 菜单说明

启动脚本后,会看到主菜单:

1) 基础安装(Docker + Docker Compose)
2) 单应用安装
3) 组合服务安装
4) 应用卸载
5) 查看当前状态
6) 退出

---

## 单应用安装说明

### Portainer

默认端口:

- 9000

访问地址示例:

```
http://服务器IP:9000
```

### qBittorrent

默认端口:

- WebUI: 8080
- BT: 6881

访问地址示例:

```
http://服务器IP:8080
```

### FileBrowser

默认端口:

- 1234

访问地址示例:

```
http://服务器IP:1234
```

---

## 组合服务说明

### 1. AV 媒体订阅服务

该组合服务包含以下组件:

```
- postgres_db_online
- postgres_avdb
- db_online
- avdb
- mdc
- filebrowser
- qbittorrent
- emby
```

#### 默认端口

```
- db_online: 9090
- avdb: 8000
- mdc: 9208
- filebrowser: 1234
- qBittorrent WebUI: 8080
- qBittorrent BT: 6881
- Emby: 8096
- Emby HTTPS: 8920
```

#### 访问示例

```
http://服务器IP:9090
http://服务器IP:8000
http://服务器IP:9208
http://服务器IP:1234
http://服务器IP:8080
http://服务器IP:8096
https://服务器IP:8920
```

### 2. 影视订阅服务

该组合服务包含以下组件:

```
- portainer-zh
- filebrowser
- dockercopilot
- qbittorrent
- emby
- moviepilot
- cookiecloud
- watchtower
```

#### 默认端口

```
- portainer-zh: 9000
- filebrowser: 1234
- dockercopilot: 12712
- qBittorrent WebUI: 8080
- qBittorrent BT: 6881
- Emby: 8096
- MoviePilot: 3000
- CookieCloud: 8088
```

#### 访问示例

```
http://服务器IP:9000
http://服务器IP:1234
http://服务器IP:12712
http://服务器IP:8080
http://服务器IP:8096
http://服务器IP:3000
http://服务器IP:8088
```

---

## 端口冲突处理

脚本会自动检测常用端口是否被占用。

如果发现冲突,会提示类似:

```
端口 8080 已被占用。
是否修改 qBittorrent WebUI 端口?[Y/n]
```

你可以:

```
- 输入 Y 修改端口
- 输入 n 取消安装
- 直接回车表示默认选择修改
```

如果手动修改端口,脚本会自动写入新的 compose 配置并继续安装。

---

## 安装完成后自动显示访问地址

这是脚本的一个重要增强功能。

例如安装完成后,脚本会输出:

影视订阅服务安装完成。
访问地址:

```
- Portainer: http://服务器IP:9000
- FileBrowser: http://服务器IP:1234
- Dockercopilot: http://服务器IP:12712
- qBittorrent WebUI: http://服务器IP:8080
- Emby: http://服务器IP:8096
- MoviePilot: http://服务器IP:3000
- CookieCloud: http://服务器IP:8088
```

这样可以快速确认服务入口。

---

## 卸载功能

脚本支持按组合服务卸载:

- 卸载 AV 媒体订阅服务
- 卸载 影视订阅服务

卸载逻辑会执行:

```
docker compose down
```

然后停止对应服务。

注意:

- 卸载只会停止容器
- 不会自动删除数据目录
- 如需彻底清理,请手动删除相关目录

---

## 数据目录说明

### AV 媒体订阅服务

数据通常保存在:

- /docker/av-stack/
- /media/

其中数据库、应用缓存、日志等都在对应子目录中。

### 影视订阅服务

数据通常保存在:

- /docker/movie-stack/
- /media/

---

## 注意事项

### 1. 镜像来源

脚本中部分镜像使用了你提供的自定义镜像,例如:

- ysx88/filebrowser:latest
- ysx88/qbittorrent:latest
- ysx88/embyserver:latest
- ysx88/moviepilot:latest
- ysx88/cookiecloud:latest

如果镜像仓库不可用,请根据实际情况替换镜像地址。

### 2. 敏感配置

部分服务包含占位符配置,例如:

- SUPERUSER
- SUPERUSER_PASSWORD
- API_TOKEN
- IYUU_SIGN
- WECHAT_*
- secretKey

请在正式部署前替换为真实值。

### 3. 端口冲突

如果你已经部署过其他服务,可能会与本项目端口冲突。
脚本支持安装前修改端口,建议根据自己的服务器环境合理规划端口。

### 4. 影视与 AV 栈不要随意重复安装

由于两个组合服务中有一些相同应用,例如:

- FileBrowser
- qBittorrent
- Emby

如果同时安装多个服务,请务必确认端口已调整,避免冲突。

---

## 推荐使用方式

建议先按以下顺序操作:

1. 基础安装 Docker
2. 安装单应用或组合服务
3. 如遇端口冲突,修改端口
4. 安装完成后按脚本输出地址访问

---

## 常见问题

### Q1: 脚本提示 Docker 未安装怎么办?

先运行脚本中的基础安装选项,或者手动安装 Docker 后再继续。

### Q2: 端口冲突了怎么处理?

脚本会提示你输入新的端口,修改后继续安装。

### Q3: 如何查看当前运行状态?

在主菜单选择:

5) 查看当前状态

### Q4: 安装后如何访问服务?

脚本会在安装完成后自动显示访问地址。

---

## 贡献方式

欢迎你提交 Issue 或 Pull Request 来完善脚本功能,例如:

- 新增更多单应用
- 新增更多组合服务
- 优化端口检查逻辑
- 增加 .env 配置支持
- 优化卸载清理逻辑

---

## 免责声明

本项目仅用于学习、测试和个人服务器环境部署。
使用者需自行承担因配置错误、端口冲突、镜像不可用或环境差异导致的风险。

---

## 许可证

建议使用 MIT 许可证,便于开源发布。

---

## 作者

由skywrt维护和持续扩展的 Docker 服务部署脚本项目。
