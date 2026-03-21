# ohome

`ohome` 是一个面向家庭场景的个人/家庭资源管理项目，仓库包含：

- `end/`：Go + Gin 后端服务
- `app/`：Flutter 客户端

## 主要功能

### 1. 家庭影音资源中心

- 影视、短剧、音乐、有声书等资源入口
- 媒体播放与播放历史记录
- 最近观看记录回显
- 基于夸克网盘文件流的在线播放

### 2. 夸克网盘能力

- 夸克登录配置
- 夸克目录配置管理
- 网盘文件浏览、重命名、移动、上传、删除、流式播放
- 夸克资源搜索
- 自动转存/同步任务
- 转存任务列表管理

### 3. 家庭事务管理

- 待办事项管理
- “点滴”物资管理
- 物资临期提醒
- 重要日期提醒
- 站内消息与提醒中心

### 4. 系统能力

- 用户登录、JWT 鉴权、刷新 token
- 用户管理、头像上传、密码修改/重置
- 局域网发现能力（HTTP + mDNS）

## 仓库结构

```text
.
├── .github/workflows/    # GitHub Actions
├── app/                  # Flutter 客户端
├── end/                  # Go 后端
│   ├── conf/             # 配置文件
│   ├── data/             # SQLite 数据库、实例数据
│   ├── log/              # 日志目录
│   ├── router/           # 路由定义
│   ├── service/          # 业务逻辑
│   ├── sql/              # 初始化 SQL
│   ├── Dockerfile         # 后端镜像构建文件
│   └── docker-compose.yml # 本地构建用 compose
```

## Docker 部署

仓库内用于本地构建后端的 Compose 文件位于 `end/docker-compose.yml`。可以在仓库根目录执行：

```bash
docker compose -f end/docker-compose.yml up -d --build
```

或者进入 `end/` 目录后直接执行：

```bash
docker compose up -d --build
```

### 推荐方式：直接拉取 Docker Hub 已发布镜像

如果你部署的是正式环境，推荐不要使用仓库自带的 `build` 方式，而是直接拉取 Docker Hub 已发布镜像。

Docker Hub 仓库：`hanlinwang0606/ohome`

可以新建一个 `docker-compose.release.yml`：

```yaml
services:
  server:
    image: hanlinwang0606/ohome:latest
    container_name: ohome-server
    environment:
      GIN_MODE: release
      PORT: 18090
    volumes:
      - ./end/conf/config.yaml:/app/conf/config.yaml:ro
      - ./end/data:/app/data
      - ./end/log:/app/log
    ports:
      - "18090:18090"
    restart: unless-stopped
```

启动命令：

```bash
docker compose -f docker-compose.release.yml pull
docker compose -f docker-compose.release.yml up -d
```

如果你不想额外维护 `compose` 文件，也可以直接用 `docker run`：

```bash
docker pull hanlinwang0606/ohome:latest

mkdir -p ./end/data ./end/log

docker run -d \
  --name ohome-server \
  -e GIN_MODE=release \
  -e PORT=18090 \
  -p 18090:18090 \
  -v "$(pwd)/end/conf/config.yaml:/app/conf/config.yaml:ro" \
  -v "$(pwd)/end/data:/app/data" \
  -v "$(pwd)/end/log:/app/log" \
  --restart unless-stopped \
  hanlinwang0606/ohome:latest
```

说明：

- `hanlinwang0606/ohome:latest` 只是示例；如果你已经推送了版本标签，建议替换成具体 tag，例如 `hanlinwang0606/ohome:v0.0.3-rc4`
- 上面的 `docker run` 命令默认在仓库根目录执行；如果你在别的目录执行，请把 `$(pwd)/end/...` 改成实际绝对路径

容器启动后，默认可访问：

- 后端 API：`http://<你的主机IP>:18090/api/v1`
- 发现接口：`http://<你的主机IP>:18090/api/v1/public/discovery`

## 配置说明

主配置文件是 [`end/conf/config.yaml`](./end/conf/config.yaml)，默认关键配置如下：

- `server.port`：服务端口，默认 `18090`
- `DB.driver`：默认 `sqlite`
- `DB.dsn`：默认 `./data/ohome.db`
- `DB.AutoMigrate`：自动建表
- `DB.InitData`：启动时导入初始化数据
- `jwt.signKey`：JWT 签名密钥
- `config.defaultPassword`：重置密码后的默认密码
- `drops.itemReminderDays` / `drops.eventReminderDays`：提醒提前天数

如果你想改端口或数据库，优先改这个配置文件。  
后端也支持通过环境变量覆盖部分配置，环境变量命名遵循 Viper 规则，例如：

- `SERVER_PORT`
- `DB_DRIVER`
- `DB_DSN`
- `JWT_SIGNKEY`

### 切换到 MySQL

代码层面已经支持 MySQL。如果你不想使用 SQLite，可以配置：

```yaml
DB:
  driver: mysql
  dsn: user:password@tcp(mysql:3306)/ohome?charset=utf8mb4&parseTime=True&loc=Local
```

然后在你的部署环境里自行补充 MySQL 服务。

## 数据持久化

Docker 部署时，下面几个目录最重要：

- [`end/conf/config.yaml`](./end/conf/config.yaml)：运行配置
- [`end/data`](./end/data)：数据库和实例标识
- [`end/log`](./end/log)：日志文件

建议在生产环境中定期备份 `end/data/` 和 `end/conf/config.yaml`。

## Android 安装包下载

Android Release 工作流会把安装包发布到 GitHub Releases。

### 最新版下载地址

- Release 页面：[https://github.com/leftScience/ohome/releases](https://github.com/leftScience/ohome/releases)
- 最新 APK：[https://github.com/leftScience/ohome/releases/latest/download/ohome-release.apk](https://github.com/leftScience/ohome/releases/latest/download/ohome-release.apk)
- 最新更新清单：[https://github.com/leftScience/ohome/releases/latest/download/android.json](https://github.com/leftScience/ohome/releases/latest/download/android.json)

## 后端便携包下载

后端 Server Release 工作流会把 Windows 和 macOS 便携包发布到 GitHub Releases。

### 最新版下载地址

- Release 页面：[https://github.com/leftScience/ohome/releases](https://github.com/leftScience/ohome/releases)
- Windows x64：[https://github.com/leftScience/ohome/releases/latest/download/ohome-server_windows_amd64.zip](https://github.com/leftScience/ohome/releases/latest/download/ohome-server_windows_amd64.zip)
- macOS Intel：[https://github.com/leftScience/ohome/releases/latest/download/ohome-server_darwin_amd64.zip](https://github.com/leftScience/ohome/releases/latest/download/ohome-server_darwin_amd64.zip)
- macOS Apple Silicon：[https://github.com/leftScience/ohome/releases/latest/download/ohome-server_darwin_arm64.zip](https://github.com/leftScience/ohome/releases/latest/download/ohome-server_darwin_arm64.zip)
- SHA256 校验：[https://github.com/leftScience/ohome/releases/latest/download/checksums.txt](https://github.com/leftScience/ohome/releases/latest/download/checksums.txt)

## 参考项目

本项目在设计和实现过程中参考了以下开源项目：

- [fish2018/pansou](https://github.com/fish2018/pansou)
- [OpenListTeam/OpenList](https://github.com/OpenListTeam/OpenList)
- [Cp0204/quark-auto-save](https://github.com/Cp0204/quark-auto-save)

## 免责声明

本项目为个人兴趣开发，旨在通过程序自动化提高网盘使用效率。

程序没有任何破解行为，只是对于夸克已有的 API 进行封装，所有数据来自于夸克官方 API；本人不对网盘内容负责，不对夸克官方 API 未来可能的变动导致的影响负责，请自行斟酌使用。

源码公开仅供学习与交流使用，未授权商业使用，严禁用于非法用途。
