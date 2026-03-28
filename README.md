# ohome

`ohome` 是一个面向家庭场景的个人/家庭资源管理项目，分为两个部分：

- `end/`：Go + Gin 服务端，负责 API、数据存储、局域网发现和业务处理
- `app/`：Flutter 客户端，负责家庭影音、网盘和家庭事务等功能入口

## 功能概览

### 家庭影音资源中心

- 影视、短剧、音乐、有声书等资源入口
- 媒体播放与播放历史记录
- 最近观看记录回显
- 基于夸克网盘文件流的在线播放

### 夸克网盘能力

- 夸克登录配置
- 夸克目录配置管理
- 网盘文件浏览、重命名、移动、上传、删除、流式播放
- 夸克资源搜索
- 自动转存/同步任务
- 转存任务列表管理

### 家庭事务管理

- 待办事项管理
- “点滴”物资管理
- 物资临期提醒
- 重要日期提醒
- 站内消息与提醒中心

### 系统能力

- 用户登录、JWT 鉴权、刷新 token
- 用户管理、头像上传、密码修改/重置
- 局域网发现能力（HTTP + mDNS）

## 快速上手

1. 先启动服务端
2. 再安装 Android 客户端
3. 在客户端登录页通过局域网发现或手动输入服务端地址完成连接

## 仓库结构

```text
.
├── .github/workflows/    # GitHub Actions
├── app/                  # Flutter 客户端
│   ├── assets/env/       # dev/prod 环境配置
│   └── build_prod.sh     # Android 一键打包脚本
├── end/                  # Go 后端
│   ├── conf/             # 配置文件
│   ├── data/             # SQLite 数据库、实例数据
│   ├── log/              # 日志目录
│   ├── router/           # 路由定义
│   ├── service/          # 业务逻辑
│   ├── sql/              # 初始化 SQL
│   ├── Dockerfile        # 后端镜像构建文件
│   └── docker-compose.yml # 本地构建用 compose
└── scripts/              # 仓库辅助脚本
```

## 服务端

### 服务端适合做什么

服务端负责提供业务 API、Swagger 文档、局域网发现接口和数据库存储。默认端口是 `18090`，默认数据库是 SQLite。

默认访问地址：

- API：`http://<你的主机IP>:18090/api/v1`
- 发现接口：`http://<你的主机IP>:18090/api/v1/public/discovery`
- Swagger：`http://127.0.0.1:18090/swagger/index.html`

### 服务端 Docker Hub 镜像部署（Docker + updater sidecar）

Docker Hub 仓库：`hanlinwang0606/ohome`

推荐直接使用仓库中的 [`end/docker-compose.release.yml`](./end/docker-compose.release.yml)。它会同时启动：

- `server`：主服务
- `updater`：本地更新执行器 sidecar

示例：

```yaml
services:
  server:
    image: ${OHOME_SERVER_IMAGE:-hanlinwang0606/ohome:latest}
    container_name: ohome-server
    environment:
      GIN_MODE: release
      PORT: 18090
      UPDATE_UPDATER_BASEURL: http://updater:18091
    volumes:
      - /opt/ohome/conf:/app/conf
      - /opt/ohome/data:/app/data
      - /opt/ohome/log:/app/log
    ports:
      - "18090:18090"
    restart: unless-stopped

  updater:
    image: ${OHOME_UPDATER_IMAGE:-hanlinwang0606/ohome-updater:latest}
    container_name: ohome-updater
    environment:
      UPDATE_UPDATER_LISTENADDR: :18091
      UPDATE_DEPLOYMODE: docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/ohome:/workspace
      - /opt/ohome/conf:/app/conf
      - /opt/ohome/data:/app/data
      - /opt/ohome/log:/app/log
    restart: unless-stopped
```

启动命令：

```bash
mkdir -p /opt/ohome/conf /opt/ohome/data /opt/ohome/log
cp ./end/docker-compose.release.yml /opt/ohome/docker-compose.release.yml
cd /opt/ohome
docker compose -f docker-compose.release.yml pull
docker compose -f docker-compose.release.yml up -d
```

Docker 更新依赖 sidecar，因此不再推荐仅用单独的 `docker run` 启动主服务。

### 服务端更新接口与客户端入口

- 管理员公开接口：
  - `GET /api/v1/system/update/info`
  - `POST /api/v1/system/update/check`
  - `POST /api/v1/system/update/apply`
  - `GET /api/v1/system/update/tasks/:taskId`
  - `POST /api/v1/system/update/rollback`
- Flutter 客户端入口：`设置 → 服务端更新`
- 发布清单：`server-manifest.json`
- 当前仅支持 Docker 部署链路更新，不再提供 Windows/macOS 服务端便携包

### 服务端配置说明

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

#### 切换到 MySQL

代码层面已经支持 MySQL。如果你不想使用 SQLite，可以配置：

```yaml
DB:
  driver: mysql
  dsn: user:password@tcp(mysql:3306)/ohome?charset=utf8mb4&parseTime=True&loc=Local
```

然后在你的部署环境里自行补充 MySQL 服务。

### 服务端数据持久化

服务端部署时，下面几个目录最重要：

- [`end/conf/config.yaml`](./end/conf/config.yaml)：运行配置
- [`end/data`](./end/data)：数据库和实例标识
- [`end/log`](./end/log)：日志文件

建议定期备份 `end/data/` 和 `end/conf/config.yaml`。

## 客户端

### 客户端适合做什么

客户端是 Flutter 应用，当前主要面向 Android 使用，负责登录、资源浏览、播放、网盘管理、待办和提醒等交互能力。

### 客户端界面预览

#### 首页与资源能力

<table>
  <tr>
    <td align="center">
      <img src="./.github/assets/首页.jpg" width="220" alt="首页" />
      <br />
      首页
    </td>
    <td align="center">
      <img src="./.github/assets/资源管理.jpg" width="220" alt="资源管理" />
      <br />
      资源管理
    </td>
    <td align="center">
      <img src="./.github/assets/夸克资源全网搜索.jpg" width="220" alt="夸克资源全网搜索" />
      <br />
      夸克资源全网搜索
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="./.github/assets/转存任务.jpg" width="220" alt="转存任务" />
      <br />
      转存任务
    </td>
    <td align="center">
      <img src="./.github/assets/设置界面.jpg" width="220" alt="设置界面" />
      <br />
      设置界面
    </td>
    <td></td>
  </tr>
</table>

#### 播放体验

<table>
  <tr>
    <td align="center">
      <img src="./.github/assets/短剧播放.jpg" width="220" alt="短剧播放" />
      <br />
      短剧播放
    </td>
    <td align="center">
      <img src="./.github/assets/影视播放可全屏.jpg" width="220" alt="影视播放可全屏" />
      <br />
      影视播放可全屏
    </td>
    <td align="center">
      <img src="./.github/assets/音乐播放.jpg" width="220" alt="音乐播放" />
      <br />
      音乐播放
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="./.github/assets/有声书播放.jpg" width="220" alt="有声书播放" />
      <br />
      有声书播放
    </td>
    <td></td>
    <td></td>
  </tr>
</table>

#### 家庭事务与提醒

<table>
  <tr>
    <td align="center">
      <img src="./.github/assets/物资管理.jpg" width="220" alt="物资管理" />
      <br />
      物资管理
    </td>
    <td align="center">
      <img src="./.github/assets/重要日期提醒.jpg" width="220" alt="重要日期提醒" />
      <br />
      重要日期提醒
    </td>
    <td align="center">
      <img src="./.github/assets/消息中心提醒.jpg" width="220" alt="消息中心提醒" />
      <br />
      消息中心提醒
    </td>
  </tr>
</table>

### 客户端如何连接服务端

客户端和服务端配合使用，推荐连接顺序如下：

1. 先确认服务端已经启动
2. 手机和服务端尽量处于同一局域网
3. 在客户端登录页优先使用局域网发现
4. 如果自动发现失败，手动输入服务端地址，例如 `http://192.168.1.10:18090`

## 参考项目

本项目在设计和实现过程中参考了以下开源项目：

- [fish2018/pansou](https://github.com/fish2018/pansou)
- [OpenListTeam/OpenList](https://github.com/OpenListTeam/OpenList)
- [Cp0204/quark-auto-save](https://github.com/Cp0204/quark-auto-save)

## 免责声明

本项目为个人兴趣开发，旨在通过程序自动化提高网盘使用效率。

程序没有任何破解行为，只是对于夸克已有的 API 进行封装，所有数据来自于夸克官方 API；本人不对网盘内容负责，不对夸克官方 API 未来可能的变动导致的影响负责，请自行斟酌使用。

源码公开仅供学习与交流使用，未授权商业使用，严禁用于非法用途。
