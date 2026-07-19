# Homepage 链接与监测检查

最后验证：2026-07-19

## 复刻结构

作者公开的 `nixos-secrets` 将 `homepage-dashboard-config.nix` 保留为空占位，
真实服务清单不在公开仓库。可以从主仓库确认并复刻的结构是：

- Homepage 模块只负责页面、Nginx vhost 和 secrets 导入。
- 卡片的 `href` 使用用户实际访问的正式域名。
- 本机服务另建 `*.localhost` HTTP vhost，供 `siteMonitor` 绕过 OAuth、TLS
  和公网 DNS 后检查真实后端。
- 跨主机服务通过内网地址或内部 DNS 访问，不让健康检查绕公网一圈。
- 正式 vhost 继续使用 `public`、`private` 和 OAuth 控制访问边界；健康检查
  地址不能替代用户链接。

当前实现沿用这个结构。`ml-home-vm` 上的 hosts 条目是内部 DNS 尚未完整复刻时
的确定性替代，避免代理 DNS 返回 `198.18.*` 后让 Homepage 误报服务离线。

## 当前结果

状态含义：

- `200/204`：直接可用。
- `200 (OAuth)`：已正常跳转到 Dex 或 Pocket ID 登录页。
- `200 (登录页)`：服务可达，并显示应用自己的登录页。
- 家庭服务的内部 HTTPS 入口使用 `:8443`；公网入口统一使用标准 `443`，再按 SNI 转发到对应主机。

| 分组 | 服务 | 用户链接结果 | 内部监测结果 |
| --- | --- | --- | --- |
| 基础设施 | Hydra | 200 | 200 |
| 基础设施 | Attic | 200 | 200 |
| 基础设施 | Gitea | 200 | 200 |
| 基础设施 | NetBox | 200 (OAuth) | 200 (OAuth) |
| 公开服务 | Dex | 200 | 200 |
| 公开服务 | Pocket ID | 200 | 204 |
| 公开服务 | Miniflux | 200 (OAuth) | 200 (OAuth) |
| 公开服务 | Radicale | 200 | 200 |
| 公开服务 | Element | 200 | 200 |
| 公开服务 | Plausible | 200 | 200 |
| 公开服务 | IT Tools | 200 | 200 |
| 公开服务 | Posts | 200 | 200 |
| 家庭服务 | qBittorrent | 200 | 200 |
| 家庭服务 | qBittorrent PT | 200 | 200 |
| 家庭服务 | Syncthing | 200 (OAuth) | 200 |
| 家庭服务 | ArchiveBox | 200 (OAuth) | 200 |
| 公开服务 | n8n | 200 (OAuth) | 200 |
| 公开服务 | Halo | 200 | 200 |
| 家庭服务 | Linkwarden | 200 (OAuth) | 200 |
| 家庭服务 | Excalidraw | 200 (OAuth) | 200 |
| 家庭服务 | FreshRSS | 200 (OAuth) | 200 |
| 家庭服务 | Memos | 200 (OAuth) | 200 |
| 媒体管理 | Vertex | 200 (OAuth) | 200 (`/user/login`) |
| 本机工具 | MetaCubeXD | 仅私有入口 | 200 |
| 媒体管理 | Sonarr | 200 (登录页) | 200 |
| 媒体管理 | Radarr | 200 (登录页) | 200 |
| 媒体管理 | Prowlarr | 200 (登录页) | 200 |
| 媒体管理 | Bazarr | 200 | 200 |
| 媒体管理 | PeerBanHelper | 200 | 200 |
| 媒体管理 | BitMagnet | 200 (`/webui/`) | 200 |

## 2026-07-19 补充卡片

以下原本在 `ml-home-vm` 运行、但未显示在 Homepage 的 Web 服务已补齐。用户链接
均使用实际正式域名；`siteMonitor` 均从承载机的 `*.localhost` 或私有 HTTPS
入口验证。WebDAV 保留无监测，因为正常访问需要 Basic Auth。

| 分组 | 服务 | 用户链接 | 监测地址 | 结果 |
| --- | --- | --- | --- | --- |
| 公开服务 | Vaultwarden | `bitwarden.zhyi.xin` | `bitwarden.localhost` | 200 |
| 公开服务 | Home Assistant | `ha.zhyi.cc` | `127.0.0.1:8123` | 200 |
| 公开服务 | Open WebUI | `ai.zhyi.xin` | `ai.localhost` | 200 |
| 公开服务 | Sun Panel | `index.zhyi.xin` | `sun-panel.localhost` | 200 |
| 公开服务 | FileCodeBox | `filebox.zhyi.xin` | `filebox.localhost` | 200 |
| 公开服务 | Zitadel | `sso.zhyi.xin` | `sso.localhost/healthz` | 200 |
| 家庭服务 | ArchiveTeam | `archiveteam.ml-home-vm.zhyi.cc` | `archiveteam.localhost` | 200 |
| 家庭服务 | HandBrake | `handbrake.ml-home-vm.zhyi.cc` | 私有 HTTPS | 200 |
| 家庭服务 | IYUUPlus | `iyuu.ml-home-vm.zhyi.cc` | `iyuu.localhost` | 200 |
| 家庭服务 | OpenSpeedTest | `openspeedtest.ml-home-vm.zhyi.cc` | `openspeedtest.localhost` | 200 |
| 家庭服务 | WebDAV | `dav.ml-home-vm.zhyi.cc` | 无（Basic Auth） | 不适用 |
| 家庭服务 | Calibre COPS | `books.ml-home-vm.zhyi.cc` | `books.localhost/ping.php` | 200 |
| 家庭服务 | Immich | `immich.ml-home-vm.zhyi.cc` | `immich.localhost` | 200 |
| 家庭服务 | Jellyfin | `jellyfin.ml-home-vm.zhyi.cc` | `jellyfin.localhost` | 200 |
| 家庭服务 | Tachidesk | `tachidesk.ml-home-vm.zhyi.cc` | `tachidesk.localhost` | 200 |
| 本机工具 | AxonHub | `axonhub.ml-home-vm.zhyi.cc` | 私有 HTTPS | 200 |
| 本机工具 | FastAPI DLS | `fastapi-dls.ml-home-vm.zhyi.cc` | 私有 HTTPS | 200 |
| 本机工具 | MetaAPI | `metapi.ml-home-vm.zhyi.cc` | 私有 HTTPS | 200 |
| 本机工具 | Uni API | `uni-api.ml-home-vm.zhyi.cc` | `uni-api.localhost/healthz` | 200 |
| 本机工具 | SearxNG | `searx.ml-home-vm.zhyi.cc` | `searx.localhost` | 200 |
| 本机工具 | ArchiSteamFarm | `asf.ml-home-vm.zhyi.cc` | `asf.localhost` | 200 |

## 其他在线主机

2026-07-19 从 `ml-builder` 探测当前部署节点：`ml-builder`、`ml-home-vm`、
`colocrossing`、`pve-5700u`、`cnvm` 和 `jpvm` 在线；`pve-2700`
离线，因此本轮不为它增加入口。

以下在线服务原先未显示在 Homepage，现按实际用途并入已有分组：

| 分组 | 承载节点 | 服务 | 用户链接 | 检查结果 |
| --- | --- | --- | --- | --- |
| 基础设施 | pve-5700u | Proxmox VE | `https://192.168.2.54` | 200，仅内网 |
| 基础设施 | colocrossing | Bird Looking Glass | `https://lg.zhyi.cc` | 200 |
| 基础设施 | colocrossing | FlapAlerted | `https://flapalerted.zhyi.cc` | 200 |
| 基础设施 | NAS，经 colocrossing | CouchDB Fauxton | `https://couchdb.zhyi.cc/_utils/` | 401，需登录 |
| 基础设施 | colocrossing | Matrix Synapse | `https://matrix-client.zhyi.xin/_matrix/client/versions` | 200 |
| 基础设施 | ml-home-vm | NCPS | `http://192.168.2.51:13851/` | 200，仅内网 |
| 公开服务 | colocrossing | Bepasty | `https://pb.zhyi.xin` | 200 |
| 公开服务 | colocrossing | RSSHub | `https://rsshub.zhyi.xin` | 200 |
| 公开服务 | colocrossing | Waline | `https://comments.zhyi.xin` | 200 |
| 公开服务 | colocrossing | Lemmy API | `https://lemmy.zhyi.xin` | 200，无 Web UI |
| 家庭服务 | NAS，经 colocrossing | QNAP | `https://qnap.zhyi.cc` | 200 |
| 家庭服务 | colocrossing | Syncthing | `https://syncthing.colocrossing.zhyi.cc` | 200 |
| 家庭服务 | ml-home-vm | CUPS | `http://192.168.2.51:631` | 200，仅内网 |
| 媒体管理 | ml-home-vm | JProxy | `https://jproxy.ml-home-vm.zhyi.cc` | 200 |
| 本机工具 | ml-home-vm | ClawEmail | `https://clawemail.ml-home-vm.zhyi.cc` | 200 |
| 本机工具 | ml-home-vm | OpenAI Edge TTS | `https://openai-edge-tts.ml-home-vm.zhyi.cc/voices` | 200 |
| 本机工具 | colocrossing | 网络信息 API | `https://api.zhyi.xin/geoip` | 200 |
| 本机工具 | colocrossing | Avatar API | `https://avatar.zhyi.xin/?s=256` | 200 |

PVE 使用作者防火墙模块已有的 `443 -> 8006` 本机重定向，卡片不直接暴露
`8006`。CouchDB 需要认证且没有无认证健康端点，因此只保留入口、不配置
`siteMonitor`。

`ml-home-vm` 将上述 colocrossing/NAS 服务域名固定解析到 `192.168.2.52`。
这只影响 Homepage 承载机的内部监测路径；用户链接仍按正式 DNS 经 CNVM 或
JPVM 入口访问，避免监测受公网 DNS 缓存、NAT 回环和入口访问策略影响。

Lemmy 虽按作者配置禁用了 Web UI，但保留 API 状态卡；Matrix 同时保留 Element
客户端卡和 Synapse 服务端状态卡。未加入卡片的 Glauth、Maddy、Quassel、
Byparr、ZeroTier Controller、Rsync CI、Samba、NFS、SFTP、Yggdrasil/Alfis
都是协议、后端或自动化服务，没有可点击的 Web 页面。S3 根路径返回 403，Lab
目录为空，UM 当前公开入口返回 403，JPVM 只有 OpenResty 默认页，也不加入。

## 本次修正

- 为 `n8n` 增加 `n8n.localhost`，监测 `/healthz`。
- 为 Halo、Linkwarden、Excalidraw、FreshRSS、Memos、Vertex 和 MetaCubeXD
  增加 Homepage 卡片及本机 `*.localhost` 监测；Vertex 检查其登录页。
- `n8n` 和 Halo 使用 `zhyi.xin` 的 CNVM 公开入口；其余 `zhyi.cc` Web 服务经
  `jpvm:443` 进入 LTNET，再由 colocrossing 转发至 `ml-home-vm:8443`。
- MetaCubeXD 保持私有，仅通过 `metacubexd.ml-home-vm.zhyi.cc` 访问。
- BitMagnet 用户链接改为实际存在的 `/webui/`。
- Hydra、Element 和 IT Tools 在承载机上走本机 `8443` 监测。
- colocrossing 上的服务通过 `192.168.2.52` 内网地址监测。
- 迁移了仍硬编码 `xuyh0120.win` 的 ASF、Calibre COPS、Immich、Jellyfin、SearxNG
  和 Tachidesk：正式入口统一改为 `*.ml-home-vm.zhyi.cc`。
- ASF 当前镜像的 IPC 默认仅绑定容器内部 localhost；采用同仓库 Tachidesk 已使用的
  host-network 方式，由 Nginx 反代主机 `127.0.0.1:1242`，避免将 IPC 端口暴露到
  ltnet，同时保留 OAuth 保护的正式入口。
- Calibre COPS 的健康检查使用 PHP-FPM 的 `/ping.php`，不再因应用的正式 URL
  重定向而误报离线。

正式入口统一静态指向 `jpvm`，不配置公网自动故障转移。TWVM 已退出生产拓扑，
默认 Mihomo 订阅只发布 JPVM 节点。

## 复测命令

在 `ml-home-vm` 检查 Homepage 使用的所有 `siteMonitor`：

```bash
awk '
  /^  - [^:]+:$/ {
    name = $0
    sub(/^  - /, "", name)
    sub(/:$/, "", name)
  }
  /siteMonitor:/ {
    url = $0
    sub(/^.*siteMonitor: /, "", url)
    print name "\t" url
  }
' /etc/homepage-dashboard/services.yaml |
while IFS="$(printf '\t')" read -r name url; do
  curl -k -sS -L --max-redirs 5 \
    --connect-timeout 4 --max-time 12 \
    -o /dev/null \
    -w "$name\t%{http_code}\t%{remote_ip}\t%{time_total}\t%{url_effective}\n" \
    "$url"
done
```

检查用户链接时要从其预期网络执行：公开服务从公网节点检查，家庭与媒体服务
从家庭 LAN 或 ZeroTier 检查。不要把 `private` 服务从普通公网不可达误判为故障。
