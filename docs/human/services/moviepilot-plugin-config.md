# MoviePilot 配置快照（脱敏）

生成时间：2026-08-16（巡检刷新快照）

## 下载器

单一 qBittorrent：

```json
[
  {
    "name": "qBittorrent",
    "type": "qbittorrent",
    "default": true,
    "enabled": true,
    "config": {
      "host": "192.168.0.1",
      "port": 13808,
      "username": "zhyi",
      "password": "<redacted>",
      "category": true,
      "sequentail": false,
      "force_resume": false,
      "first_last_piece": false,
      "incomplete_files_ext": true
    },
    "path_mapping": []
  }
]
```

## 目录

- 电影：下载 `/mnt/storage/downloads` → 媒体库 `/mnt/storage/media-radarr`
- 剧集：下载 `/mnt/storage/downloads` → 媒体库 `/mnt/storage/media-sonarr`
- 整理方式：hardlink（`link`），容器整块挂载 `/mnt/storage`，同设备硬链接不复制；
  刮削与中文重命名开启。

## 订阅默认配置

- 电影 / 剧集均使用站点 [1,2]（馒头、PT时间），下载器 `qBittorrent`，
  保存路径 `/mnt/storage/downloads`。
- 使用 IMDb ID 搜索，未开启洗版，未配置额外过滤词。

## 媒体服务器

- Jellyfin：`http://jellyfin-api.rock5c.zhyi.xin`，同步全部媒体库。

## 插件

| 插件 | 状态 | 说明 |
| --- | --- | --- |
| BrushFlow | 启用 | M-Team / PTTime 刷流，仅免费种子，下载器 qBittorrent，分类 `brush`；每 30 分钟刷新、每 10 分钟检查（2026-08-09 由 6/10 分钟调低，避免站点限流与空转） |
| AutoSignIn | 启用 | 每日 11:55 / 23:55 签到站点 [1,2] |
| SiteStatistic | 启用 | 站点数据统计 |
| MediaServerRefresh | 启用 | Jellyfin 入库刷新 |
| IYUUAutoSeed | 停用 | 单下载器 qBittorrent；辅种按用户要求暂停，后续需要时再启用 |
| CleanInvalidSeed | 启用 | 仅标记，不删除 |
| SubtitleAssistant | 启用 | moviepilot 站点字幕 + ASSRT（每日配额约 5 次，兜底）+ opensubtitles（2026-08-16 启用，凭据已配，healthy）；源优先级 `[moviepilot, opensubtitles, assrt]` |
| TorrentRemover | 启用 | 每 6 小时；仅 `刷流` 标签，ratio>3、做种>2h、低速且停滞/错误才删除种子及文件；`brush` 仅作 qB 分类归组 |
| RssSubscribe | 停用 | 旧 FlexGet 替代，暂无 RSS 源 |
| AutoClean | 停用 | 未使用 |

## qBittorrent 标签

- `个人`：个人下载/已入库做种
- `MOVIEPILOT`：MoviePilot 下载任务
- `刷流-<任务ID>`：BrushFlow 刷流
- `已整理`：已入库，MoviePilot 不再重复整理

分类：`personal`（个人）、`brush`（刷流）。
