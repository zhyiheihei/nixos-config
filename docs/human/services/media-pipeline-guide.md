# 下载与媒体链路使用指南

最后整理：2026-08-16

导航页入口：<https://homepage.rock5c.zhyi.xin>（"下载链路"与"媒体链路"分组）

## 链路总览

```text
┌──────────────────── 发现与订阅 ────────────────────┐
│  MoviePilot（搜索、订阅、整理、刮削、字幕）          │
└────────────────────────┬───────────────────────────┘
                         │ 推送到单一 qBittorrent
                         ▼
┌──────────────────── 下载层 ────────────────────────┐
│  qBittorrent（router 单实例）                       │
│  统一保存路径：/mnt/storage/downloads               │
│  标签：个人 / 刷流-<任务>                            │
└────────────────────────┬───────────────────────────┘
                         │ 下载完成后 hardlink 入库
                         ▼
┌──────────────────── 媒体库 ────────────────────────┐
│  /mnt/storage/media-radarr（电影）                  │
│  /mnt/storage/media-sonarr（剧集）                  │
│  MoviePilot 中文刮削 → Jellyfin 播放                 │
└────────────────────────────────────────────────────┘
```

运行位置：

| 主机 | 服务 |
| --- | --- |
| router | qBittorrent 单实例（WebUI：<https://bt.router.zhyi.xin>） |
| rock5c | MoviePilot（v3）、Jellyfin、HandBrake、ChineseSubFinder、Homepage |
| opi5p | PeerBanHelper、BitMagnet、Tachidesk |
| NAS | NFS 导出 `/mnt/storage` |

旧链路（Sonarr、Radarr、Prowlarr、Bazarr、FlexGet、IYUUPlus、JProxy、
Byparr、Vertex、qbittorrent-pt、qbittorrent-seedbox）已由 MoviePilot 与
单一 qBittorrent 替代并停止。

## 场景一：找电影 / 剧集

1. 打开 [MoviePilot](https://moviepilot.rock5c.zhyi.xin)，搜索电影或剧集。
2. 添加订阅；未发布或站内暂无资源的条目会保持订阅，发布后自动搜索。
3. MoviePilot 从馒头 / PT时间索引搜索，推送到 qBittorrent，保存到
   `/mnt/storage/downloads`。
4. 下载完成后 hardlink 到 `media-radarr` / `media-sonarr`，自动中文刮削。
5. 字幕双通道自动补齐：SubtitleAssistant 事件触发 + ChineseSubFinder 周期
   扫库（详见[字幕链路](#字幕链路)）。
6. Jellyfin 刷新后即可观看。

## 场景二：刷流

BrushFlow 的 M-Team 与 PTTime 任务都只下载免费种子，使用独立标签
`刷流-<任务ID>`，保存到同一个 `/mnt/storage/downloads`，但不会进入媒体库，
也不会被 MoviePilot 整理。

## 场景三：手动传种

- WebUI：<https://bt.router.zhyi.xin>
- 个人下载打标签 `个人`；刷流下载打标签 `刷流-<任务ID>`。
- 已入库媒体如需继续做种，把种子保存路径指向对应媒体库目录即可。

## 辅助服务

| 服务 | 地址 | 作用 |
| --- | --- | --- |
| MoviePilot | <https://moviepilot.rock5c.zhyi.xin> | 订阅、搜索、整理、刮削、字幕 |
| Jellyfin | <https://jellyfin.zhyi.xin:8443> | 媒体服务器 |
| qBittorrent | <https://bt.router.zhyi.xin> | 统一下载器 |
| BitMagnet | <https://bitmagnet.opi5p.zhyi.xin/webui/> | 磁力搜索 |
| PeerBanHelper | <https://peerbanhelper.opi5p.zhyi.xin> | 反吸血保护 |
| Tachidesk | <https://tachidesk.zhyi.xin:8443> | 漫画 |
| HandBrake | rock5c 本机 `http://127.0.0.1:13814` | 硬件转码 |
| ChineseSubFinder | rock5c 本机 `http://127.0.0.1:19035` | 周期扫描媒体库补齐中文字幕 |

## 字幕链路

字幕由两个服务互补（双通道），均已接入媒体库目录：

| 服务 | 机制 | 源 |
| --- | --- | --- |
| MoviePilot SubtitleAssistant（插件） | 事件触发，入库/订阅完成时补充 | moviepilot（站点字幕）、assrt、opensubtitles |
| ChineseSubFinder（容器） | 每 6 小时扫描 media-radarr / media-sonarr | assrt、xunlei、shooter、a4k（已死） |

已知状态（2026-08-16 实测）：

- assrt 免费 API 每日配额约 5 次，只能作兜底源；
- a4k.net、字幕库（zimuku）站点已下线；
- ChineseSubFinder 镜像停在 v0.55.3（2023-12），项目停止维护；
- opensubtitles 源已于 2026-08-16 启用（源优先级 moviepilot → opensubtitles →
  assrt），详见[字幕源扩展调研](../research/subtitle-sources-expansion.md)。

## 存储路径

| 路径 | 用途 |
| --- | --- |
| `/mnt/storage/downloads` | 统一下载目录（qBittorrent） |
| `/mnt/storage/media-radarr/` | 电影媒体库 |
| `/mnt/storage/media-sonarr/` | 剧集媒体库 |
| `/mnt/storage/.downloads-auto/` | 保留空目录，兼容旧自动化脚本 |

## 常见问题

### 订阅没有入库？

1. 确认 MoviePilot「目录管理」的下载路径为 `/mnt/storage/downloads`。
2. 确认 qBittorrent 任务标签包含 `MOVIEPILOT`，且没有被标记 `已整理`。
3. 在 MoviePilot 手动执行一次「立即整理」。

### 订阅剧集显示不全？

MoviePilot 按 TMDB 季集口径统计，媒体库旧目录若按 TVDB 的 S1/S2 组织，
MP 会把另一半集数判为缺失。2026-08-09 已对齐：

- 胆大党：S1 合并为 24 集（TMDB 口径），Jellyfin 索引 24/24，订阅完成。
- 吊带袜天使 / 新吊带袜天使：实际媒体库各 13 集，订阅总集数手动锁定为 13
  （`manual_total_episode`），避免被 TMDB 的 28/30 错误计数覆盖，订阅完成。
- 旧 Sonarr 生成的剧集 `.nfo` 带 TVDB 集 ID，移动/改名后会让 Jellyfin 拒绝
  写入新集号；本次已把这类 nfo 移出媒体库（备份在
  `/mnt/storage/.jf-meta-backup-20260809/ddd`），Jellyfin 按文件名 + TMDB
  重新索引。以后移动或改名剧集文件时，同步删除或重写对应 `.nfo`，再对剧集
  执行 Jellyfin FullRefresh；若仍出现「未知季/无集号」，用 Jellyfin 官方接口
  `POST /Items/{id}` 修正 `IndexNumber` / `ParentIndexNumber`，最后全库扫描验证。
- 本次整改后已做全库扫描复验：胆大党 S1 24 集、吊带袜天使 S1 13 集、
  新吊带袜天使 S1 13 集，全部带集号，无「未知季」残留。

### 字幕没有下载？

1. 先确认字幕链路整体状态（见[字幕链路](#字幕链路)）：assrt 每日配额约 5 次，
   耗尽后当天不再搜索，属正常限制而非故障。
2. 检查 SubtitleAssistant 插件源状态（moviepilot / assrt / opensubtitles）。
3. 对已入库文件可在字幕助手页面手动搜索并下载。
4. 也可在 ChineseSubFinder 管理页（rock5c 本机 19035）手动触发补全。

### 刷流种子会不会进媒体库？

不会。BrushFlow 任务使用 `刷流-*` 标签，MoviePilot 只处理带 `MOVIEPILOT`
标签且未标记 `已整理` 的任务。

## MoviePilot 插件状态与 qBittorrent 标签

快照核对：2026-08-16（巡检刷新）。下载器为单一 qBittorrent
（`192.168.0.1:13808`，用户名 `zhyi`，`path_mapping` 空）；目录为
`/mnt/storage/downloads` → `media-radarr`/`media-sonarr`，整理方式 hardlink
（同设备硬链接不复制），中文刮削与重命名开启；订阅默认站点 [1,2]（馒头、
PT时间）、IMDb ID 搜索、未开洗版。

### 插件

| 插件 | 状态 | 说明 |
| --- | --- | --- |
| BrushFlow | 启用 | M-Team / PTTime 刷流，仅免费种子，下载器 qBittorrent，分类 `brush`；每 30 分钟刷新、每 10 分钟检查（2026-08-09 由 6/10 分钟调低，避免站点限流与空转） |
| AutoSignIn | 启用 | 每日 11:55 / 23:55 签到站点 [1,2] |
| SiteStatistic | 启用 | 站点数据统计 |
| MediaServerRefresh | 启用 | Jellyfin 入库刷新 |
| IYUUAutoSeed | 停用 | 单下载器 qBittorrent；辅种按用户要求暂停，后续需要时再启用 |
| CleanInvalidSeed | 启用 | 仅标记，不删除 |
| SubtitleAssistant | 启用 | moviepilot 站点字幕 + ASSRT（每日配额约 5 次，兜底）+ opensubtitles（2026-08-16 启用，凭据已配，healthy）；源优先级 `[moviepilot, opensubtitles, assrt]` |
| TorrentRemover | 启用 | 每 6 小时；仅 `刷流` 标签，ratio>3、做种>2h、低速且停滞/错误才删除种子及文件 |
| RssSubscribe | 停用 | 旧 FlexGet 替代，暂无 RSS 源 |
| AutoClean | 停用 | 未使用 |

### qBittorrent 标签

- `个人`：个人下载/已入库做种
- `MOVIEPILOT`：MoviePilot 下载任务
- `刷流-<任务ID>`：BrushFlow 刷流
- `已整理`：已入库，MoviePilot 不再重复整理

分类：`personal`（个人）、`brush`（刷流）。
