# 下载与媒体链路使用指南

最后整理：2026-08-05

本文档描述完整的下载与媒体链路：从 PT 站找片、自动追番、漫画阅读，到最终在
Rockchip Jellyfin 观看。2026-08-05 起链路拆成两层：下载与数据库继续留在
`opi5p`，Sonarr/Radarr/Bazarr/Prowlarr/Jellyfin/HandBrake 等媒体应用迁到
`rock5c`；媒体文件两边都直接挂载同一份 NAS 路径，不复制。

导航页入口：<https://homepage.rock5c.zhyi.cc>（"下载与媒体链路"分组）

## 链路总览

```text
┌─────────────────── 发现与请求 ───────────────────┐
│  Radarr(电影) / Sonarr(剧集) / FlexGet(RSS 自动) │
│  BitMagnet(磁力搜索) / Vertex(刷流面板)          │
└──────────────────────┬───────────────────────────┘
                       │ 通过 Prowlarr 查询索引器
                       ▼
┌─────────────────── 下载层 ───────────────────────┐
│  qBittorrent PT   → /mnt/storage/downloads       │
│                     /mnt/storage/.downloads-qb-pt │
│                     /mnt/storage/.downloads-auto  │
│  qBittorrent      → /mnt/storage/downloads       │
│                     /mnt/storage/.downloads-qb    │
│  qBittorrent Seedbox → /mnt/storage/.downloads-qb-seedbox │
└──────────────────────┬───────────────────────────┘
                       │ 下载完成通知
                       ▼
┌─────────────────── 整理与入库 ───────────────────┐
│  Sonarr/Radarr 导入 → media-sonarr / media-radarr │
│  Bazarr 匹配字幕                                  │
│  Decluttarr 清理卡住的任务                        │
│  qbittorrent-pt-cleanup 清理 .downloads-auto 旧种 │
└──────────────────────┬───────────────────────────┘
                       ▼
┌─────────────────── 播放 ─────────────────────────┐
│  Jellyfin ← /mnt/storage/media-radarr            │
│           ← /mnt/storage/media-sonarr            │
└──────────────────────────────────────────────────┘

漫画（独立链路）：
  Tachidesk/Suwayomi → 漫画源与扩展 → 章节下载/书库/阅读进度

运行位置：
  router      → qBittorrent x3、qbittorrent-pt-cleanup（下载器）
  opi5p       → FlexGet、BitMagnet、IYUU、JProxy、PeerBanHelper、Tachidesk、
                Vertex、PostgreSQL/MariaDB
  rock5c      → 家庭边缘 + Sonarr、Radarr、Bazarr、Prowlarr、Jellyfin、
                HandBrake、Decluttarr（媒体应用）
  NAS         → 192.168.0.40:/nixos，router、opi5p 与 rock5c 都直接挂载 /mnt/storage

音乐（独立链路）：
  手机/电脑 网易云音乐下载 → Syncthing 同步
  → /mnt/storage/media/CloudMusic
  → rsgain 定时标准化响度（每小时）
```

## 场景一：从 PT 站找电影

### 自动化方式（推荐）

1. 打开 [Radarr](https://radarr.rock5c.zhyi.cc)
2. 搜索电影名（英文/中文均可，依赖 Prowlarr 中配置的索引器）
3. 点击"添加"，选择质量配置（Quality Profile）
4. Radarr 自动：查询索引器 → 选最优种子 → 推送到 qBittorrent PT
5. 下载到 `/mnt/storage/.downloads-qb-pt`
6. 下载完成后 Radarr 自动导入到 `/mnt/storage/media-radarr/<电影名> (<年份>)`
7. Bazarr 自动匹配字幕
8. Jellyfin 刮削元数据，可观看

### 手动方式

1. 打开 [qBittorrent PT](https://pt.router.zhyi.cc)
2. 粘贴磁力链接或上传 .torrent 文件
3. 保存路径选 `/mnt/storage/downloads`（通用下载目录）
4. 下载完成后文件在 `/mnt/storage/downloads/` 中，自行处理

### 追更已有电影系列

在 Radarr 中把电影标记为"Monitored"，当新质量版本发布时（如从 1080p 升级到
2160p），Radarr 会自动重新下载并替换。

## 场景二：找剧集 / 追番

### 自动化方式（推荐）

1. 打开 [Sonarr](https://sonarr.rock5c.zhyi.cc)
2. 搜索剧集名
3. 添加并设置监控（Monitor）：
   - "All Episodes"：全季追更
   - "Future Episodes"：只追新集
4. Sonarr 自动：查询索引器 → 推送到 qBittorrent PT → 下载到
   `/mnt/storage/.downloads-qb-pt`
5. 每集完成后自动导入 `/mnt/storage/media-sonarr/<剧名>/Season XX/`
6. Bazarr 自动下载字幕
7. Jellyfin 中观看

### RSS 自动下载（FlexGet）

FlexGet 每 10 分钟执行一次，自动抓取 HDHome RSS 中的新种子：

- 下载到 `/mnt/storage/.downloads-auto`
- 适用于站点官种刷流 + 自动追更
- 清理策略（qbittorrent-pt-cleanup，每小时执行）：
  - 未完成且超过 36 小时 → 删除
  - 已完成且超过 5 天 → 删除（含文件）

查看状态：

```bash
ssh -p 2222 root@opi5p.zhyi.cc \
  'journalctl -u flexget-runner --since "1 hour ago"'
```

### 手动追番

同电影手动方式，用 qBittorrent PT 手动添加，下载完成后如需入库：
在 Sonarr 中选择"Manual Import"指定下载目录。

## 场景三：找音乐

音乐走独立链路，不经过 BT 下载：

1. 在手机/电脑上用网易云音乐下载歌曲
2. Syncthing 自动同步到 opi5p 的 `/mnt/storage/media/CloudMusic`
3. rsgain 定时任务（每小时）自动标准化响度（-14 LUFS，跳过已处理的）
4. 归档目录：`/mnt/storage/media/CloudMusicArchive`

注意：rsgain 直接修改文件 tag，Syncthing 会将变更同步回其他设备。

## 场景四：刷流（Seedbox）

独立的刷流链路，与 PT 追剧链路隔离：

1. 打开 [Seedbox](https://seedbox.router.zhyi.cc)
2. 添加种子，固定下载到 `/mnt/storage/.downloads-qb-seedbox`
3. 配合 [Vertex](https://vertex.opi5p.zhyi.cc) 管理站点数据和刷流任务
4. [IYUUPlus](https://iyuu.opi5p.zhyi.cc) 自动辅种到其他站点，提升上传量

## 辅助服务说明

| 服务 | 地址 | 作用 |
| --- | --- | --- |
| Prowlarr | <https://prowlarr.rock5c.zhyi.cc> | 索引器管理：Sonarr/Radarr 通过它查询 PT 站 |
| Bazarr | <https://bazarr.rock5c.zhyi.cc> | 自动匹配/下载字幕 |
| JProxy | <https://jproxy.opi5p.zhyi.cc> | Sonarr/Radarr 与下载器之间的资源代理 |
| PeerBanHelper | <https://peerbanhelper.opi5p.zhyi.cc> | 反吸血：自动封禁不回报的 peer |
| BitMagnet | <https://bitmagnet.opi5p.zhyi.cc> | DHT 磁力搜索，不依赖 PT 站找资源 |
| HandBrake | rock5c 本机 `http://127.0.0.1:13814` | RKMPP/RGA 硬件转码，存储路径 /mnt/storage/handbrake-server/ |
| IYUUPlus | <https://iyuu.opi5p.zhyi.cc> | 辅种工具：自动将已有文件匹配到其他站点种子 |
| Vertex | <https://vertex.opi5p.zhyi.cc> | PT 站点数据面板 + 刷流任务管理 |
| Jellyfin | <https://jellyfin.zhyi.xin:8443> | 媒体服务器：链路终点，观看电影/剧集 |
| Tachidesk | <https://tachidesk.zhyi.xin:8443> | 漫画源、书库、章节下载与阅读进度（Basic Auth） |

### HandBrake Rockchip 后端

HandBrake 应用后端运行在 rock5c，使用
`emcd39/handbrake-rk3588` 的 RKMPP/RGA 实验分支。目前只提供
rock5c 本机 `http://127.0.0.1:13814` 入口，尚未恢复公网域名。
输入、监视与输出目录位于 NAS 上的
`/mnt/storage/handbrake-server/`。

运行状态和硬件编码器可用以下命令验证：

```bash
ssh -p 2222 root@rock5c.zhyi.cc \
  'systemctl status podman-handbrake --no-pager'

ssh -p 2222 root@rock5c.zhyi.cc \
  'podman exec handbrake HandBrakeCLI --help | grep -i rkmpp'
```

2026-08-02 已实测 H.264 1280×720 输入通过 `h264_rkmpp` 输出
60 帧 MP4，HandBrake 返回 `work result = 0`。该 fork 仍为实验项目，
复杂滤镜、字幕烧录与长时间批量转码需要继续观察。

### 无 WebUI 的后台组件

| 组件 | 触发方式 | 作用 |
| --- | --- | --- |
| FlexGet | 每 10 分钟 | HDHome RSS 自动下载 |
| qbittorrent-pt-cleanup | 每小时 | 清理 .downloads-auto 中的过期种子（router） |
| Decluttarr | 常驻 | 清理 Sonarr/Radarr 中卡住/停滞的下载任务 |
| rsgain-cloudmusic | 每小时 | CloudMusic 响度标准化 |
| exportarr (×4) | 常驻 | Sonarr/Radarr/Prowlarr/Bazarr 指标导出到 Prometheus |

## 存储路径速查

所有媒体与下载路径位于 NAS 的 NFS 挂载 `/mnt/storage`（直接来自
`192.168.0.40:/nixos`），router、opi5p 与 rock5c 都直接挂载。Tachidesk 与 Vertex
的应用数据库位于 OPI5P 本机 `/var/lib/tachidesk`、`/var/lib/vertex`；
Sonarr/Radarr/Bazarr/Prowlarr/Jellyfin 的状态位于 rock5c 本机
`/var/lib/{sonarr,radarr,bazarr,prowlarr,jellyfin}`，HandBrake 配置位于
`/nix/persistent/var/lib/handbrake-rk3588/config`：

| 路径 | 用途 | 可写服务 |
| --- | --- | --- |
| `downloads/` | 通用手动下载 | qbittorrent, qbittorrent-pt（router） |
| `.downloads-qb/` | qBittorrent 专属（Sonarr 可导入） | qbittorrent, sonarr, radarr |
| `.downloads-qb-pt/` | qBittorrent PT 专属（Sonarr 可导入） | qbittorrent-pt, sonarr, radarr |
| `.downloads-auto/` | FlexGet 自动下载（定时清理） | qbittorrent-pt |
| `.downloads-qb-seedbox/` | 刷流专用 | qbittorrent-seedbox |
| `media-radarr/` | 电影媒体库 | radarr(rock5c), bazarr(读), jellyfin(读) |
| `media-sonarr/` | 剧集媒体库 | sonarr(rock5c), bazarr(读), jellyfin(读) |
| `media/CloudMusic/` | 音乐（Syncthing 同步） | syncthing |
| `media/CloudMusicArchive/` | 音乐归档 | syncthing |
| `handbrake-server/` | 转码工作区 | podman-handbrake(rock5c) |

隐藏目录（`.` 前缀）的设计意图：与用户主动使用的 `downloads/` 隔离，
避免自动化链路的中间文件污染手动下载目录。

## 常见问题

### Sonarr/Radarr 搜不到资源？

1. 检查 Prowlarr 中索引器是否正常（Test 按钮）
2. 部分站点需要 FlareSolverr 绕过 Cloudflare（已自动配置）
3. 确认搜索语言设置（Settings → Indexers → 搜索语言）

### 英文标题在 M-Team/PTTime 搜不到，但站内中文标题有？

这两个 PT 站对老剧/中剧常以中文标题为主，Sonarr 只按英文标题和 IMDb ID
搜索会漏掉。rock5c 已启用中文 Scene Mapping：

1. 打开 `hosts/rock5c/sonarr-scene-mappings.nix`，在 `mappings` 中按现有格式
   添加对应剧集的 `tvdbId` 与中文标题
2. 部署后 Sonarr 会同时搜索英文标题和该中文别名
3. 在 Sonarr 中对目标剧集执行 `Search Monitored` 验证

### 下载完成但没有自动导入？

1. 检查 Sonarr/Radarr 的 Activity 页面错误信息
2. 常见原因：文件权限问题、磁盘空间不足、质量不匹配
3. Decluttarr 会自动清理卡住的任务，也可以手动在 Activity 中移除

### Jellyfin 没有显示新内容？

1. 控制台 → 媒体库 → 扫描所有媒体库
2. 确认媒体库路径包含 media-radarr 和 media-sonarr

### Jellyfin 搜刮不全或识别错标题？

Sonarr/Radarr 已启用 Kodi/Emby `.nfo` 元数据写入，会往媒体目录写
`tvshow.nfo`、`movie.nfo`、分集 `.nfo`，包含 TVDB/TMDB/IMDb ID；Jellyfin
扫描时优先读取这些本地 ID，不再依赖目录名在线匹配。若新剧仍识别失败：

1. 确认 Sonarr/Radarr 已完成 Refresh/Scan，媒体目录已生成 `.nfo`
2. 在 Jellyfin 对该剧手动 Identify，把结果应用到 series
3. 重新扫描 Jellyfin 媒体库

### 磁盘空间不足？

```bash
ssh -p 2222 root@opi5p.zhyi.cc 'df -h /mnt/storage'
```

清理优先级：`.downloads-auto`（自动清理）> `downloads/` 中的旧文件 >
seedbox 中已完成的老种子。

## 配置来源

| 配置 | 位置 |
| --- | --- |
| 路径与 BindPaths 编排 | `nixos/optional-apps/media-automation.nix` |
| Router 下载链路编排 | `hosts/router/qbittorrent.nix` |
| OPI5P 消费方编排 | `hosts/opi5p/media-automation.nix`、`hosts/opi5p/media-download-chain.nix`、`hosts/opi5p/qbittorrent-router.nix` |
| rock5c 媒体应用编排 | `hosts/rock5c/media-apps.nix`、`hosts/rock5c/media-edge.nix` |
| 下载器模块 | `nixos/optional-apps/qbittorrent*.nix` |
| *arr 套件 | `nixos/optional-apps/sonarr/` |
| FlexGet | `nixos/optional-cron-jobs/flexget/` |
| PT 清理 | `nixos/optional-cron-jobs/qbittorrent-pt-cleanup/` |
| 响度标准化 | `nixos/optional-cron-jobs/rsgain-cloudmusic.nix` |
| 导航页卡片 | secrets 仓库 `homepage-dashboard-config.nix` |
