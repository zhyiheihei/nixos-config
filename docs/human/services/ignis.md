# Ignis 服务接入（Web Obsidian / vault / SSO）

Ignis 是 Obsidian 的浏览器兼容层（Electron API shim）：把官方 Obsidian 跑在标准
浏览器里，vault 留在服务器上。镜像固定 `nobbe/ignis:0.8.9`（自托管容器，Obsidian
本体不打包，首次启动时由容器从官方源下载）。运行在 `opi5p`，入口
`https://ignis.opi5p.zhyi.xin`（私有 LTNET 域名，`accessibleBy = private`）。

## 与知识链的关系

Ignis 的 vault 直接挂载 opi5p 上 Syncthing 的 Documents 家庭副本
（`/mnt/storage/media/Documents`，容器内 `/vaults/Notes`；2026-08-20 Notes 并入
Documents 后 vault 指向改为此路径）。浏览器里编辑的每一份 Markdown 就是知识链
私有权威的同一份文件：

- 写回后经 Syncthing 四机分发（ml-2700 / ml-laptop / opi5p / greencloud），
- git 权威仍是 Gitea（`git.zhyi.xin`，`zhyi/notes`），
- Documents 与 nixos-config 依旧是两个独立 git 仓库，互不混用。

Obsidian 会在 vault 根目录生成 `.obsidian/` 配置目录，随 Syncthing 同步到其它
机器，这是多端 Obsidian 的固有行为（单用户可接受）。

## 容器与数据

| 项 | 值 |
| --- | --- |
| 镜像 | `docker.io/nobbe/ignis:0.8.9`（pin，自动更新 `registry`） |
| 容器端口 | `8080`，宿主只绑 `127.0.0.1:13832`（`LT.port.Ignis`） |
| 运行 UID/GID | `PUID=1000` / `PGID=1000`（= `zhyi`，vault 属主） |
| vault | `/mnt/storage/media/Documents` → `/vaults/Notes`（NFS 盘，挂载排序依赖 `mnt-storage.mount`） |
| 服务数据 | `/nix/persistent/var/lib/ignis/data` → `/app/data` |
| Obsidian 应用 | `/nix/persistent/var/lib/ignis/obsidian-app` → `/app/obsidian-app`（持久卷，避免每次重建容器重下） |
| 写合并 | `WRITE_COALESCE_MS=500`（vault 在 NFS 上，按官方建议开启） |

首次启动会从 Obsidian 官方源下载应用本体；opi5p 上该流量走 router SOCKS5 代理
（`systemd.services.podman-ignis.environment = proxyEnvironment`，与
`podman-byparr` 同款，配置在 `hosts/opi5p/configuration.nix`）。

## 认证（nginx 层 oauth2-proxy + Dex）

Ignis 无内置认证，vault 挂在共享的 oauth2-proxy 之后：

- 主 vhost `ignis.opi5p.zhyi.xin` 的 location `/` 开启 `enableOAuth = true`，
  复用已有的 oauth2-proxy → Dex（`login.zhyi.xin`）链路；
- 无需新增 Dex client/secret（oauth2-proxy 已是单一 client `oauth-proxy`），
  也不在应用层做 OIDC；
- 健康检查 vhost `ignis.localhost`（纯 HTTP、`accessibleBy = localhost`）不挂
  OAuth，供 Homepage siteMonitor 使用。

## 运维要点

- 部署/构建只在 ml-builder：`nix run .#colmena -- build --on opi5p` →
  `apply --on opi5p`。
- 模块：`nixos/optional-apps/ignis.nix`，选项 `options.lantian.ignis`
  （`enable` / `dataDir` / `vaultDir` / `uid` / `gid`）；opi5p 在
  `hosts/opi5p/home-services.nix` 中 `lantian.ignis.enable = true`，并覆盖
  `vaultDir = /mnt/storage/media/Documents`（模块默认仍为 `media/Notes`，
  随 Notes→Documents 迁移由主机级覆盖修正）。
- 验证：`systemctl status podman-ignis`、`journalctl -u podman-ignis`；
  `curl -fsS http://127.0.0.1:13832/` 应返回 Ignis UI；
  `curl -fsS https://ignis.opi5p.zhyi.xin` 应先 302 到 `/oauth2/start`。
- 备份：Documents 本体已被 Syncthing/Gitea 覆盖；`/nix/persistent/var/lib/ignis`
  是运行态数据（Obsidian 应用副本 + 服务索引），重建即恢复，不单独进 restic 清单。
- 升级 Obsidian 版本由镜像的 `OBSIDIAN_VER` 控制（未 pin 时随镜像默认），升级
  Ignis 本体 = 改镜像 tag 后 `podman-auto-update`/重建容器。
