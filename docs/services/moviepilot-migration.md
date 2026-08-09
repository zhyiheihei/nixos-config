# MoviePilot 媒体链路迁移

状态：2026-08-09，主链路已切换并验证。

## 当前链路

- MoviePilot v2.15.5 运行在 rock5c，登录用户 `zhyi`，M-Team 用户认证通过。
- 站点：馒头（API Key）、PT时间（Cookie），均使用单一 qBittorrent。
- 下载器：router 单一 qBittorrent，`/mnt/storage/downloads` 统一保存路径。
- 媒体库：`/mnt/storage/media-radarr`、`/mnt/storage/media-sonarr`，
  MoviePilot 整块挂载 `/mnt/storage` 后使用 hardlink 入库并中文刮削，不复制占空间。
- 字幕：SubtitleAssistant（ASSRT + MoviePilot 站点字幕源），不依赖新服务。
- Jellyfin 已接入 MoviePilot，订阅完成自动刷新媒体库。

## 已迁移/停止的服务

| 旧服务 | 替代 | 状态 |
| --- | --- | --- |
| Sonarr / Radarr | MoviePilot 订阅/整理 | 已停止 |
| Prowlarr | MoviePilot 站点索引 | 已停止 |
| Bazarr | SubtitleAssistant | 已停止 |
| FlexGet | MoviePilot 订阅 | 已停止 |
| IYUUPlus | IYUUAutoSeed | 已停止；辅种按用户要求暂停 |
| JProxy / Byparr | MoviePilot 整理命名 | 已停止 |
| Vertex | BrushFlow + AutoSignIn | 已停止 |
| Decluttarr / qbittorrent-pt-cleanup | BrushFlow / CleanInvalidSeed | 已停止 |
| qbittorrent-pt / qbittorrent-seedbox | 单一 qBittorrent | 已停止 |

保留运行：Jellyfin、HandBrake、PeerBanHelper、BitMagnet、Tachidesk。

## 订阅迁移

- Radarr 全部 10 部电影已导入 MoviePilot 订阅；已有文件的自动识别为完成，
  无资源的保持订阅等待发布。
- Sonarr 全部 6 部剧集已导入 MoviePilot 订阅；缺失集继续搜索，未发布季保持订阅。
- 已配置电影/剧集订阅默认项：站点 [1,2]、下载器 qBittorrent、
  保存路径 `/mnt/storage/downloads`、IMDb ID 搜索。

## 下载器合并

- 122 个旧种子（60 个 PT + 62 个 Seedbox）已导出并导入单一 qBittorrent。
- 数据文件统一迁移到 `/mnt/storage/downloads`。
- 分类：`personal` 85 个、`brush` 37 个。
- 标签：个人 `个人`（MoviePilot 下载另有 `MOVIEPILOT`）；刷流
  `刷流-<任务ID>`；已入库种子标记 `已整理`，不会被重复整理。

## 刷流

- M-Team 与 PTTime 刷流任务都限制为免费种子。
- 使用独立标签和 `brush` 分类，不进入媒体库。

## 字幕

- SubtitleAssistant 1.1 启用，ASSRT Token 已从 Bazarr 迁移并验证健康。
- 实测 `星际穿越 (2014)` 搜索到 15 个 ASSRT 候选，简体中文字幕已落盘为
  `星际穿越 (2014) - 1080p.chi.zh-cn.srt`。
- MoviePilot 站点字幕搜索（M-Team / PTTime 字幕区）当前返回 0，仍以 ASSRT
  为主字幕源；站点字幕解析待站点索引配置完善。

## 风险登记

| 风险 | 状态 | 处置 |
| --- | --- | --- |
| IYUU 辅种 | 暂停 | 用户暂不启用辅种；IYUUPlus 保持停止，后续需要时再绑定推荐站点并启用 |
| M-Team 站点字幕搜索 0 结果 | 待观察 | 使用 ASSRT 主源，继续跟进索引字幕配置 |
| 大体积种子 qB 首次检查耗时 | 进行中 | 122 个种子在 `checkingDL`，完成后自动做种 |

## 验证记录

1. MoviePilot API/站点测试通过，订阅搜索-下载-入库-刮削链路已实测
   （`星际穿越` 完成入库并生成中文 nfo/海报）。
2. SubtitleAssistant 人工搜索与下载实测成功。
3. 旧服务均已停止且 NixOS 配置禁用，重启不会自动拉起。
4. 修复容器 bind 挂载后，`料理仙姬` 10 集与 `奥德赛` 蓝光原盘 hardlink
   入库成功，qB 做种保留；订阅剧集不再显示“有资源但集数不全”。
