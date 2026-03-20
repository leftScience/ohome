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
│   └── Dockerfile        # 后端镜像构建文件
└── docker-compose.yml    # 本地构建用 compose
```

## Docker 部署

### 推荐方式：直接拉取已发布镜像

如果你部署的是正式环境，推荐不要使用仓库自带的 `build` 方式，而是直接拉取 GHCR 已发布镜像。

可以新建一个 `docker-compose.release.yml`：

```yaml
services:
  server:
    image: ghcr.io/leftscience/ohome:v0.0.3-rc4
    container_name: ohome-server
    environment:
      GIN_MODE: release
      PORT: 8090
    volumes:
      - ./end/conf/config.yaml:/app/conf/config.yaml:ro
      - ./end/data:/app/data
      - ./end/log:/app/log
    ports:
      - "8090:8090"
    restart: unless-stopped
```

启动命令：

```bash
docker compose -f docker-compose.release.yml pull
docker compose -f docker-compose.release.yml up -d
```

如果你不想额外维护 `compose` 文件，也可以直接用 `docker run`：

```bash
docker pull ghcr.io/leftscience/ohome:v0.0.3-rc4

mkdir -p ./end/data ./end/log

docker run -d \
  --name ohome-server \
  -e GIN_MODE=release \
  -e PORT=8090 \
  -p 8090:8090 \
  -v "$(pwd)/end/conf/config.yaml:/app/conf/config.yaml:ro" \
  -v "$(pwd)/end/data:/app/data" \
  -v "$(pwd)/end/log:/app/log" \
  --restart unless-stopped \
  ghcr.io/leftscience/ohome:v0.0.3-rc4
```

更新到新版本：

```bash
docker compose -f docker-compose.release.yml pull
docker compose -f docker-compose.release.yml up -d
```

对应的 `docker run` 更新方式：

```bash
docker pull ghcr.io/leftscience/ohome:v0.0.3-rc4
docker rm -f ohome-server

docker run -d \
  --name ohome-server \
  -e GIN_MODE=release \
  -e PORT=8090 \
  -p 8090:8090 \
  -v "$(pwd)/end/conf/config.yaml:/app/conf/config.yaml:ro" \
  -v "$(pwd)/end/data:/app/data" \
  -v "$(pwd)/end/log:/app/log" \
  --restart unless-stopped \
  ghcr.io/leftscience/ohome:v0.0.3-rc4
```

查看状态：

```bash
docker compose -f docker-compose.release.yml ps
docker compose -f docker-compose.release.yml logs -f server
```

对应的 `docker run` 查看方式：

```bash
docker ps --filter "name=ohome-server"
docker logs -f ohome-server
```

停止服务：

```bash
docker compose -f docker-compose.release.yml down
```

对应的 `docker run` 停止和删除方式：

```bash
docker stop ohome-server
docker rm ohome-server
```

说明：

- `ghcr.io/leftscience/ohome:v0.0.3-rc4` 只是示例，请替换成你要部署的 Release tag
- 如果你已配置 Docker Hub，也可以改成 Docker Hub 地址拉取
- 上面的 `docker run` 命令默认在仓库根目录执行；如果你在别的目录执行，请把 `$(pwd)/end/...` 改成实际绝对路径

容器启动后，默认可访问：

- 后端 API：`http://<你的主机IP>:8090/api/v1`
- Swagger：`http://<你的主机IP>:8090/swagger/index.html`
- 发现接口：`http://<你的主机IP>:8090/api/v1/public/discovery`

## 配置说明

主配置文件是 [`end/conf/config.yaml`](./end/conf/config.yaml)，默认关键配置如下：

- `server.port`：服务端口，默认 `8090`
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

### 指定版本下载地址

把下面 URL 里的 tag 替换成你想下载的版本即可：

```text
https://github.com/leftScience/ohome/releases/download/<tag>/ohome-release.apk
https://github.com/leftScience/ohome/releases/download/<tag>/android.json
```

例如：

```text
https://github.com/leftScience/ohome/releases/download/v0.0.3-rc4/ohome-release.apk
```

### 客户端在线更新说明

生产环境配置文件 [`app/assets/env/prod.json`](./app/assets/env/prod.json) 已经指向：

```text
https://github.com/leftScience/ohome/releases/latest/download/android.json
```

这意味着：

- 生产版 Android 客户端可以直接读取 GitHub Release 的更新清单
- 当你发布新的 tag 并生成新的 Release 后，客户端可检测到更新
- 手动下载安装时直接下载 `ohome-release.apk` 即可

## 参考项目

本项目在设计和实现过程中参考了以下开源项目：

- [fish2018/pansou](https://github.com/fish2018/pansou)
- [OpenListTeam/OpenList](https://github.com/OpenListTeam/OpenList)
- [Cp0204/quark-auto-save](https://github.com/Cp0204/quark-auto-save)

## 免责声明

本项目为个人兴趣开发，旨在通过程序自动化提高网盘使用效率。

程序没有任何破解行为，只是对于夸克已有的 API 进行封装，所有数据来自于夸克官方 API；本人不对网盘内容负责，不对夸克官方 API 未来可能的变动导致的影响负责，请自行斟酌使用。

源码公开仅供学习与交流使用，未授权商业使用，严禁用于非法用途。
