# MoviePilot 配置快照（脱敏）

生成时间：2026-08-09

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
- 整理方式：hardlink（`link`），刮削与中文重命名开启。

## 媒体服务器

- Jellyfin：`http://jellyfin-api.rock5c.zhyi.cc`，同步全部媒体库。

## 插件

| 插件 | 状态 | 说明 |
| --- | --- | --- |
| BrushFlow | 启用 | M-Team / PTTime 刷流，仅免费种子，下载器 qBittorrent，分类 `brush` |
| AutoSignIn | 启用 | 每日 11:55 / 23:55 签到站点 [1,2] |
| SiteStatistic | 启用 | 站点数据统计 |
| MediaServerRefresh | 启用 | Jellyfin 入库刷新 |
| IYUUAutoSeed | 停用 | 单下载器 qBittorrent；辅种按用户要求暂停，后续需要时再启用 |
| CleanInvalidSeed | 启用 | 仅标记，不删除 |
| SubtitleAssistant | 启用 | ASSRT + MoviePilot 站点字幕源，中文简繁字幕 |
| TorrentRemover | 停用 | 仅保留 BrushFlow 标签配置，防误删 |
| RssSubscribe | 停用 | 旧 FlexGet 替代，暂无 RSS 源 |
| AutoClean | 停用 | 未使用 |

## qBittorrent 标签

- `个人`：个人下载/已入库做种
- `MOVIEPILOT`：MoviePilot 下载任务
- `刷流-<任务ID>`：BrushFlow 刷流
- `已整理`：已入库，MoviePilot 不再重复整理

分类：`personal`（个人）、`brush`（刷流）。
