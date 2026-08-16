# 下载与媒体链路迁移到 OPI5P

状态：已完成（2026-08-02）。下载、索引、整理、字幕、漫画和下载管理服务已从
`ml-home-vm` 迁到 `opi5p`。Jellyfin 继续使用 `jellyfin-rockchip.nix`；
`ml-home-vm` 只保留家庭公网 TLS/认证入口和旧私有域名的反向代理。

> 2026-08-06 后续：qBittorrent 三实例与 qbittorrent-pt-cleanup 已从 opi5p
> 迁到 router，本文档保留为历史迁移记录。当前下载器位置与调用方见
> `docs/migrations/router-qbittorrent-migration.md`。

## 2026-08-05 后续拆分：媒体应用迁到 rock5c

用户确认将媒体播放层从 `opi5p` 拆到 `rock5c`：Sonarr、Radarr、Bazarr、
Prowlarr、Jellyfin、HandBrake、Decluttarr 及对应 exportarr exporter 现在运行在
`rock5c`（`hosts/rock5c/media-apps.nix`）。下载链路与数据库不动：

- `opi5p` 继续运行：qBittorrent x3、FlexGet、BitMagnet、IYUU、JProxy、
  PeerBanHelper、Tachidesk、Vertex、PostgreSQL、MariaDB。
- `opi5p` 不再运行：Sonarr、Radarr、Bazarr、Prowlarr、Jellyfin、
  HandBrake、Decluttarr 及其 exporter（unit 已移除）。
- `rock5c` 通过 `pt.opi5p.zhyi.cc:443` 连接 qBittorrent PT；JProxy/FlexGet
  通过 `sonarr/radarr/prowlarr.rock5c.zhyi.cc` 访问新后端。
- Sonarr/Radarr 启用 Kodi/Emby `.nfo` 元数据写入，Jellyfin 扫描时读取
  `.nfo` 里的 TVDB/TMDB/IMDb ID；Jellyfin 的 `MetadataSavers=[]`，媒体目录
  仍保持只读，不写回 `.nfo`。

`rock5c` 新服务用 `/nix/persistent/var/lib/media-apps/ready` 门闩控制，
避免部署时用空数据抢跑。

## 不变量

- NAS 始终由两台机器直接挂载为 `/mnt/storage`，源为
  `192.168.0.40:/nixos`；媒体文件和下载数据不复制。
- qBittorrent、Sonarr、Radarr 等写服务不能在两台机器同时运行。
- `/var/lib/postgresql` 和 `/var/lib/mysql` 不能整目录复制；只迁移各自的
  `bitmagnet` 与 `iyuu` 数据库。
- 切换失败时先停止 OPI5P 的写服务并删除激活标记，再恢复旧机服务；旧机状态在
  验收完成前不得删除。

## 预部署

OPI5P 的写服务受以下文件保护：

```text
/nix/persistent/var/lib/media-automation/ready
```

后续追加迁移的有状态容器各有独立门闩，避免部署配置时以空数据库抢跑：

```text
/nix/persistent/var/lib/media-automation/tachidesk-ready
/nix/persistent/var/lib/media-automation/vertex-ready
```

文件不存在时可以安全部署配置，PostgreSQL、MySQL、用户、密钥和 Nginx 配置会
准备好，但下载器和自动化服务不会启动。

```bash
nix run .#colmena -- apply --on opi5p

ssh -p 2222 root@192.168.0.62 \
  'test ! -e /nix/persistent/var/lib/media-automation/ready &&
   systemctl is-active jellyfin &&
   lsattr -d /nix/persistent/var/lib/postgresql'
```

PostgreSQL 目录必须显示 `C`（NOCOW）属性。OPI5P 的 Jellyfin package 必须仍是
Rockchip override，且 `LD_LIBRARY_PATH` 包含 `libmali-rockchip-g610`。

## 冻结源服务

先停止定时器和上游任务，再停止下载器；qBittorrent 的停止超时为 30 分钟，以便
完整写回 fastresume。

```bash
ssh -p 2222 root@192.168.0.51 '
  systemctl stop flexget-runner.timer qbittorrent-pt-cleanup.timer
  systemctl stop \
    decluttarr.service jproxy.service peerbanhelper.service \
    sonarr.service radarr.service bazarr.service prowlarr.service \
    bitmagnet-dht.service bitmagnet-queue.service bitmagnet-http.service \
    iyuuplus.service podman-byparr.service \
    podman-tachidesk.service podman-vertex.service
  systemctl stop \
    qbittorrent.service qbittorrent-pt.service qbittorrent-seedbox.service
'
```

确认没有写服务残留：

```bash
ssh -p 2222 root@192.168.0.51 '
  systemctl is-active \
    qbittorrent qbittorrent-pt qbittorrent-seedbox sonarr radarr bazarr \
    prowlarr bitmagnet-dht iyuuplus | grep -v inactive && exit 1 || exit 0
'
```

## 迁移文件状态

以下命令从控制机执行，数据经 SSH 流式传输，不落到 NAS：

```bash
ssh -p 2222 root@192.168.0.51 \
  'tar --acls --xattrs --numeric-owner -C /var/lib -cpf - \
    qbittorrent qbittorrent-pt qbittorrent-seedbox \
    sonarr radarr bazarr prowlarr jproxy peerbanhelper flexget iyuu \
    tachidesk vertex' |
ssh -p 2222 root@192.168.0.62 \
  'tar --acls --xattrs --numeric-owner -C /var/lib -xpf -'
```

## 迁移数据库

Bitmagnet 只迁移自身 PostgreSQL 数据库：

```bash
ssh -p 2222 root@192.168.0.51 \
  'runuser -u postgres -- pg_dump --format=custom bitmagnet' |
ssh -p 2222 root@192.168.0.62 '
  runuser -u postgres -- dropdb --if-exists bitmagnet
  runuser -u postgres -- createdb --owner=bitmagnet bitmagnet
  runuser -u postgres -- pg_restore \
    --exit-on-error --no-owner --role=bitmagnet --dbname=bitmagnet
'
```

IYUU 只迁移自身 MariaDB 数据库：

```bash
ssh -p 2222 root@192.168.0.51 \
  'mariadb-dump --single-transaction --add-drop-table iyuu' |
ssh -p 2222 root@192.168.0.62 'mariadb iyuu'
```

## 激活与验收

```bash
ssh -p 2222 root@192.168.0.62 '
  install -Dm600 /dev/null /nix/persistent/var/lib/media-automation/ready
  install -Dm600 /dev/null /nix/persistent/var/lib/media-automation/tachidesk-ready
  install -Dm600 /dev/null /nix/persistent/var/lib/media-automation/vertex-ready
  systemctl start media-automation.target
'
```

新的 qBittorrent 入站端口为：

| 实例 | 端口 |
| --- | ---: |
| qBittorrent | 31220 |
| qBittorrent PT | 31221 |
| qBittorrent Seedbox | 31222 |

验收项目：

1. 三个 qBittorrent 实例的任务数量、保存路径和完成进度与旧机一致。
2. Sonarr/Radarr 根目录仍为 `/mnt/storage/media-sonarr` 与
   `/mnt/storage/media-radarr`，下载客户端测试通过。
3. Prowlarr 索引器、Byparr、JProxy、Bazarr 与 PeerBanHelper 健康。
4. Bitmagnet 数据库大小和搜索结果正常，IYUU 能读取三个下载器。
5. 新下载能完成、导入、匹配字幕，并被 OPI5P 的 Rockchip Jellyfin 扫描到。
6. Prometheus 的 Sonarr/Radarr/Prowlarr/Bazarr exporter 恢复为 `up=1`。
7. Tachidesk 的 H2 数据库、漫画库和阅读进度存在，`tachidesk.zhyi.xin`
   仍要求 Basic Auth；Vertex 的站点、下载器和种子历史存在。

本次实际切换校验：Tachidesk 共 1242 个文件，源/目标逐文件哈希汇总均为
`9a7fafe19f7672e6128de051004b28cb92075f43a8ca1aeffae8ea867588479a`；
ARM64 容器启动后 H2 schema 从 58 正常迁移到 60。正式入口返回 401、内部边缘与
OPI5P 私有后端均返回 200。Vertex 共 18006 个文件，源/目标逐文件哈希汇总均为
`d0613dbc6f1e639b38710c848eecb8829fc736d943b3269791e91d4574b7de16`，ARM64
容器和经旧域名访问的登录跳转均正常。

FlexGet 的 SOPS 文件目前只有占位项，没有 `HDHOME_AUTO_RSS_URL`。模块会安全跳过
本轮任务而不是持续失败；恢复 RSS 自动下载前必须通过 SOPS 补入真实变量。

## 回滚

```bash
ssh -p 2222 root@192.168.0.62 '
  systemctl stop media-automation.target \
    qbittorrent qbittorrent-pt qbittorrent-seedbox \
    sonarr radarr bazarr prowlarr podman-tachidesk podman-vertex
  rm -f /nix/persistent/var/lib/media-automation/ready
  rm -f /nix/persistent/var/lib/media-automation/tachidesk-ready
  rm -f /nix/persistent/var/lib/media-automation/vertex-ready
'

ssh -p 2222 root@192.168.0.51 '
  systemctl start \
    qbittorrent qbittorrent-pt qbittorrent-seedbox \
    sonarr radarr bazarr prowlarr jproxy decluttarr peerbanhelper \
    bitmagnet-http bitmagnet-queue bitmagnet-dht iyuuplus podman-byparr \
    podman-tachidesk podman-vertex
  systemctl start flexget-runner.timer qbittorrent-pt-cleanup.timer
'
```

回滚后不能把 OPI5P 运行期间产生的新状态反向覆盖旧机；应先确定需要保留的任务，
再单独处理。
