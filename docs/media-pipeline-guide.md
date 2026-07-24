# 下载与媒体链路使用指南

最后整理：2026-07-23

本文档描述 ml-home-vm 上完整的下载与媒体链路：从 PT 站找片、自动追番、音乐同步，
到最终在 Jellyfin 观看的全流程。

导航页入口：<https://homepage.ml-home-vm.zhyi.cc>（"下载与媒体链路"分组）

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

音乐（独立链路）：
  手机/电脑 网易云音乐下载 → Syncthing 同步
  → /mnt/storage/media/CloudMusic
  → rsgain 定时标准化响度（每小时）
```

## 场景一：从 PT 站找电影

### 自动化方式（推荐）

1. 打开 [Radarr](https://radarr.ml-home-vm.zhyi.cc)
2. 搜索电影名（英文/中文均可，依赖 Prowlarr 中配置的索引器）
3. 点击"添加"，选择质量配置（Quality Profile）
4. Radarr 自动：查询索引器 → 选最优种子 → 推送到 qBittorrent PT
5. 下载到 `/mnt/storage/.downloads-qb-pt`
6. 下载完成后 Radarr 自动导入到 `/mnt/storage/media-radarr/<电影名> (<年份>)`
7. Bazarr 自动匹配字幕
8. Jellyfin 刮削元数据，可观看

### 手动方式

1. 打开 [qBittorrent PT](https://qbittorrent-pt.ml-home-vm.zhyi.cc)
2. 粘贴磁力链接或上传 .torrent 文件
3. 保存路径选 `/mnt/storage/downloads`（通用下载目录）
4. 下载完成后文件在 `/mnt/storage/downloads/` 中，自行处理

### 追更已有电影系列

在 Radarr 中把电影标记为"Monitored"，当新质量版本发布时（如从 1080p 升级到
2160p），Radarr 会自动重新下载并替换。

## 场景二：找剧集 / 追番

### 自动化方式（推荐）

1. 打开 [Sonarr](https://sonarr.ml-home-vm.zhyi.cc)
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
ssh ml-home-vm 'journalctl -u flexget-runner --since "1 hour ago"'
```

### 手动追番

同电影手动方式，用 qBittorrent PT 手动添加，下载完成后如需入库：
在 Sonarr 中选择"Manual Import"指定下载目录。

## 场景三：找音乐

音乐走独立链路，不经过 BT 下载：

1. 在手机/电脑上用网易云音乐下载歌曲
2. Syncthing 自动同步到 ml-home-vm 的 `/mnt/storage/media/CloudMusic`
3. rsgain 定时任务（每小时）自动标准化响度（-14 LUFS，跳过已处理的）
4. 归档目录：`/mnt/storage/media/CloudMusicArchive`

注意：rsgain 直接修改文件 tag，Syncthing 会将变更同步回其他设备。

## 场景四：刷流（Seedbox）

独立的刷流链路，与 PT 追剧链路隔离：

1. 打开 [Seedbox](https://qbittorrent-seedbox.ml-home-vm.zhyi.cc)
2. 添加种子，固定下载到 `/mnt/storage/.downloads-qb-seedbox`
3. 配合 [Vertex](https://vertex.ml-home-vm.zhyi.cc) 管理站点数据和刷流任务
4. [IYUUPlus](https://iyuuplus.ml-home-vm.zhyi.cc) 自动辅种到其他站点，提升上传量

## 辅助服务说明

| 服务 | 地址 | 作用 |
| --- | --- | --- |
| Prowlarr | <https://prowlarr.ml-home-vm.zhyi.cc> | 索引器管理：Sonarr/Radarr 通过它查询 PT 站 |
| Bazarr | <https://bazarr.ml-home-vm.zhyi.cc> | 自动匹配/下载字幕 |
| JProxy | <https://jproxy.ml-home-vm.zhyi.cc> | Sonarr/Radarr 与下载器之间的资源代理 |
| PeerBanHelper | <https://peerbanhelper.ml-home-vm.zhyi.cc> | 反吸血：自动封禁不回报的 peer |
| BitMagnet | <https://bitmagnet.ml-home-vm.zhyi.cc> | DHT 磁力搜索，不依赖 PT 站找资源 |
| HandBrake | <https://handbrake.ml-home-vm.zhyi.cc> | 视频转码（NVENC 硬编），存储路径 /mnt/storage/handbrake-server/ |
| IYUUPlus | <https://iyuuplus.ml-home-vm.zhyi.cc> | 辅种工具：自动将已有文件匹配到其他站点种子 |
| Vertex | <https://vertex.ml-home-vm.zhyi.cc> | PT 站点数据面板 + 刷流任务管理 |
| Jellyfin | <https://jellyfin.zhyi.xin> | 媒体服务器：链路终点，观看电影/剧集 |

### 无 WebUI 的后台组件

| 组件 | 触发方式 | 作用 |
| --- | --- | --- |
| FlexGet | 每 10 分钟 | HDHome RSS 自动下载 |
| qbittorrent-pt-cleanup | 每小时 | 清理 .downloads-auto 中的过期种子 |
| Decluttarr | 常驻 | 清理 Sonarr/Radarr 中卡住/停滞的下载任务 |
| rsgain-cloudmusic | 每小时 | CloudMusic 响度标准化 |
| exportarr (×4) | 常驻 | Sonarr/Radarr/Prowlarr/Bazarr 指标导出到 Prometheus |

## 存储路径速查

所有路径位于 NFS 挂载 `/mnt/storage`（来自 192.168.2.93）：

| 路径 | 用途 | 可写服务 |
| --- | --- | --- |
| `downloads/` | 通用手动下载 | qbittorrent, qbittorrent-pt |
| `.downloads-qb/` | qBittorrent 专属（Sonarr 可导入） | qbittorrent, sonarr, radarr |
| `.downloads-qb-pt/` | qBittorrent PT 专属（Sonarr 可导入） | qbittorrent-pt, sonarr, radarr |
| `.downloads-auto/` | FlexGet 自动下载（定时清理） | qbittorrent-pt |
| `.downloads-qb-seedbox/` | 刷流专用 | qbittorrent-seedbox |
| `media-radarr/` | 电影媒体库 | radarr, bazarr(读), jellyfin(读) |
| `media-sonarr/` | 剧集媒体库 | sonarr, bazarr(读), jellyfin(读) |
| `media/CloudMusic/` | 音乐（Syncthing 同步） | syncthing |
| `media/CloudMusicArchive/` | 音乐归档 | syncthing |
| `handbrake-server/` | 转码工作区 | podman-handbrake |

隐藏目录（`.` 前缀）的设计意图：与用户主动使用的 `downloads/` 隔离，
避免自动化链路的中间文件污染手动下载目录。

## 常见问题

### Sonarr/Radarr 搜不到资源？

1. 检查 Prowlarr 中索引器是否正常（Test 按钮）
2. 部分站点需要 FlareSolverr 绕过 Cloudflare（已自动配置）
3. 确认搜索语言设置（Settings → Indexers → 搜索语言）

### 下载完成但没有自动导入？

1. 检查 Sonarr/Radarr 的 Activity 页面错误信息
2. 常见原因：文件权限问题、磁盘空间不足、质量不匹配
3. Decluttarr 会自动清理卡住的任务，也可以手动在 Activity 中移除

### Jellyfin 没有显示新内容？

1. 控制台 → 媒体库 → 扫描所有媒体库
2. 确认媒体库路径包含 media-radarr 和 media-sonarr

### 磁盘空间不足？

```bash
ssh ml-home-vm 'df -h /mnt/storage'
```

清理优先级：`.downloads-auto`（自动清理）> `downloads/` 中的旧文件 >
seedbox 中已完成的老种子。

## 配置来源

| 配置 | 位置 |
| --- | --- |
| 路径与 BindPaths 编排 | `hosts/ml-home-vm/media-center.nix` |
| 下载器模块 | `nixos/optional-apps/qbittorrent*.nix` |
| *arr 套件 | `nixos/optional-apps/sonarr/` |
| FlexGet | `nixos/optional-cron-jobs/flexget/` |
| PT 清理 | `nixos/optional-cron-jobs/qbittorrent-pt-cleanup/` |
| 响度标准化 | `nixos/optional-cron-jobs/rsgain-cloudmusic.nix` |
| 导航页卡片 | secrets 仓库 `homepage-dashboard-config.nix` |
