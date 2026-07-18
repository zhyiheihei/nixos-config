# Homepage 链接与监测检查

最后验证：2026-07-18

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
| 家庭服务 | n8n | 200 (OAuth) | 200 |
| 迁移服务 | Halo | 200 (OAuth) | 200 |
| 迁移服务 | Linkwarden | 200 (OAuth) | 200 |
| 迁移服务 | Excalidraw | 200 (OAuth) | 200 |
| 迁移服务 | FreshRSS | 200 (OAuth) | 200 |
| 迁移服务 | Memos | 200 (OAuth) | 200 |
| 迁移服务 | Vertex | 200 (OAuth) | 200 (`/user/login`) |
| 迁移服务 | MetaCubeXD | 仅私有入口 | 200 |
| 媒体管理 | Sonarr | 200 (登录页) | 200 |
| 媒体管理 | Radarr | 200 (登录页) | 200 |
| 媒体管理 | Prowlarr | 200 (登录页) | 200 |
| 媒体管理 | Bazarr | 200 | 200 |
| 媒体管理 | PeerBanHelper | 200 | 200 |
| 媒体管理 | BitMagnet | 200 (`/webui/`) | 200 |

## 本次修正

- 为 `n8n` 增加 `n8n.localhost`，监测 `/healthz`。
- 为 Halo、Linkwarden、Excalidraw、FreshRSS、Memos、Vertex 和 MetaCubeXD
  增加 Homepage 卡片及本机 `*.localhost` 监测；Vertex 检查其登录页。
- `n8n` 和前六个迁移服务的正式域名经 `twvm:443` 进入 LTNET，再由
  colocrossing 转发至 `ml-home-vm:8443`；均受 OAuth 保护。
- MetaCubeXD 保持私有，仅通过 `metacubexd.ml-home-vm.zhyi.cc:8443` 访问。
- BitMagnet 用户链接改为实际存在的 `/webui/`。
- Hydra、Element 和 IT Tools 在承载机上走本机 `8443` 监测。
- colocrossing 上的服务通过 `192.168.2.52` 内网地址监测。

Gcore 免费套餐拒绝为同一名称创建多条动态 GEO 记录，因此当前正式入口为
静态 `twvm` CNAME，不提供 `jpvm` 自动主备切换。后续若需要自动故障转移，需
更换或升级支持该能力的 DNS 方案，再变更记录；不要在当前套餐上重复尝试。

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
