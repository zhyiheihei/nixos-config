# 巡检规范（Inspection Playbook）

> 原则：**巡检 ≠ 看服务是否 running**。服务在跑但内部可能持续报错、限流、静默失败。
> 真正的巡检是看**内部日志的报错/警告**、**监控指标中的失败计数**、**数据链路的实际流转**。

## 三层巡检方法

| 层 | 做什么 | 为什么 |
|---|---|---|
| ① 服务状态 | `systemctl is-active` / `list-units` / `--failed` | 入口筛查，**只看有没有大范围宕机**，不作为巡检结论 |
| ② 日志报错 | `journalctl -u <svc> --since "24 hours ago" \| grep -icE "error\|warning\|failed\|exception\|panic"`，再 `tail` 看具体内容 | **核心**：发现限流、连接被拒、超时、静默失败 |
| ③ 监控指标 | Prometheus 查失败计数/趋势（`/api/v1/query`、`label/__name__/values`） | 量化问题：失败是否增长、是否影响成功率 |
| ④ 数据流转 | 链路实际产物：下载目录新文件、备份索引、同步状态 | 确认链路"真的在工作"，而非"进程活着" |

问题分级：🔴 影响功能（下载失败/同步中断）→ 🟡 间歇/降级 → 🟢 噪音（可接受）。

## 通用检查命令

```bash
# 服务状态（入口，不深究）
systemctl --failed | head -20
systemctl list-units --type=service | grep <关键词>

# 日志错误计数（24h），先数再抽样看内容
journalctl -u <svc> --since "24 hours ago" --no-pager | grep -icE "error|warning|failed|exception|panic"
journalctl -u <svc> --since "6 hours ago" --no-pager | grep -iE "error|failed" | tail -10

# 监控链：目标抓取健康 + 失败指标
curl -sS http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health=="down") | .scrapePool + " / " + .labels.instance'
curl -sS http://127.0.0.1:9090/api/v1/label/__name__/values | jq -r '.data[] | select(test("<前缀>"))'
curl -sS "http://127.0.0.1:9090/api/v1/query" --data-urlencode 'query=<指标>' | jq '.data.result'
```

> 注意：`systemctl is-active` 只回答"进程活着"；`journalctl` 才回答"服务是否健康"。
> 一切巡检结论必须以 ②③④ 层的证据为准。

## 各链路巡检清单

### 1. 监控链（colocrossing）
- **入口**：prometheus / alertmanager / grafana 服务 active
- **日志**：各服务 journalctl 的 error/warn（如 Grafana datasource 报错、Prometheus 抓取失败）
- **监控指标**：
  - `up{job!="blackbox"}` 的 down 目标（排除已知离线机：jpvm 流量耗尽、opi03/h28k 未部署）
  - `scrape_samples_scraped` / 抓取成功率（router 国际 ZT 链路丢包，node job 已调 2m/110s）
  - 关键 exporter：blackbox、wireguard、coredns（knot）、bird、mysql、exportarr（radarr/sonarr/bazarr/prowlarr）
- **面板**：Grafana 各面板非空（「设备性能」「链路速率」「各接口实时吞吐」等），注意 panel 的 refId 不能重复（Grafana 13+）

### 2. 下载链路（opi5p）与媒体应用（rock5c）
- **入口**：opi5p 上 qbittorrent{,-pt,-seedbox} / bitmagnet / iyuuplus / jproxy /
  peerbanhelper / byparr / tachidesk / vertex，以及 rock5c 上 sonarr / radarr /
  prowlarr / bazarr / jellyfin / decluttarr / handbrake 均 running（仅入口）
- **日志（重点）**：
  - **sonarr/radarr/prowlarr**：`grep -iE "429|TooManyRequests|Indexer is disabled|Download failed|SSL"` → PT 索引器限流（MTeamTp 等），反复 429 会禁用索引器影响下载成功率；对策：prowlarr 调低该索引器抓取频率
  - **radarr**：`Connection refused (pt.opi5p.zhyi.cc:443)` → qbittorrent-pt WebUI 瞬时不可达，注意频率
  - **bazarr**：`Run time of job "Sync with Sonarr/Radarr" exceeded` → 媒体库大导致同步超时（🟡）
  - **decluttarr pre-start**：curl 7878 失败 = 启动顺序（radarr 未就绪，🟢）；`Removing failed downloads` 是正常清理
  - **jellyfin**：WS 断开/请求取消 = 客户端行为（🟢）
  - **prowlarr**：`Missing translation resource` = Nix 打包缺本地化文件（🟢 噪音）
- **监控指标**：`radarr_movie_downloaded_total`、`prowlarr_indexer_failed_grabs_total`（失败是否增长）、`prowlarr_indexer_unavailable`、`bazarr_subtitles_downloaded_total`、`sonarr_*`
- **数据流转**：`ls /mnt/storage/downloads`（有新下载）、`df -h /mnt/storage`（NAS 挂载健康，<90%）、Jellyfin 媒体库可播放

### 3. 家庭网络 / 边缘链路（rock5c）
- **入口**：nginx、homepage-dashboard、rsshub（若启用）、zerotier、wgmesh
- **日志**：nginx error.log 的 5xx 比例；homepage-dashboard 的 `Error calling`（siteMonitor 失败）；zerotier 的 peer 丢包
- **监控指标**：`router_dhcp_active_leases`（textfile，注意重复序列会致整个 gather 失败）、`node_network_*`（router 国际 ZT 链路）、homepage 的 66 个 siteMonitor
- **数据流转**：`nix-sync-servers` 定时任务 Finished（router → colocrossing 经 rock5c 网关）

### 4. AI 链路（colocrossing / UniAPI 网关）
- 参考 `docs/infrastructure/ai-api-gateway-chain.md`（UniAPI 是唯一 Provider 汇聚点，禁止反向配置网关）
- **日志**：UniAPI / LibreChat / n8n 的 error/warn；OAuth token 刷新失败
- **监控指标**：请求量、错误率（若有 exporter）

### 5. 备份链路（7 台 → opi5p）
- **入口**：backup 服务/timer 状态
- **日志**：restic/rustic backup 的 error（sftp 连接、索引读取、上传失败）
- **数据流转**：`backup-nix-persistent` 手动触发一次，确认 sftp 连通 + 索引 + 上传（参考：ml-home-vm 退役后 sftpEndpoint 已统一为 opi5p.zhyi.cc）
- **验证**：目标机索引份数增长（`restic snapshots` / rustic 索引）

### 6. DNS 链路
- **入口**：coredns / knot 服务
- **日志**：解析失败、区域传输失败
- **监控指标**：`coredns_dns_requests_total`（按 server/zone）、knot exporter
- **数据流转**：`dig` 抽查公网域名（注意 DNS 发布走 GitHub Actions dnscontrol，生效有 TTL 延迟；国内网络可能 UDP 53 劫持，用 DoH 交叉验证）

### 7. 分布式构建链（ml-builder / opi5p / pve-5700u）
- **入口**：nix daemon、buildMachines（ml-builder 通告 x86_64+aarch64，opi5p 仅 native aarch64、无 big-parallel）
- **日志**：`Cannot build ... (no substituter)` = 远程 builder 缺输入（`builders-use-substitutes=false` 所致）；对策：`nix copy --to ssh://nix-builder@<builder> --derivation <drv>` 或 qemu 本机构建
- **注意**：opi5p 负载敏感，巡检/部署时不要连续压它（此前多次重试导致 SSH 无响应）；qemu TCG 编译 arm 慢但可用（binfmt 已注册）

## 巡检记录规范

每次巡检记录到会话/文档，格式：

```
## 巡检 <日期> <链路>
- 入口状态：<异常才写>
- 日志错误计数：<svc> <n>（24h）——抽样内容：...
- 监控指标：<指标> <值>（是否增长）
- 数据流转：<证据>
- 结论：🔴/🟡/🟢 + 处理项
```

- 🔴 必须当次处理或明确排期；🟡 记录并观察；🟢 说明为何是噪音（避免下次重复排查）
- 已知离线/噪音清单（巡检时直接排除，节省时间）：
  - jpvm（流量耗尽离线，blackbox/node 告警属预期）
  - opi03 / h28k（未部署，或用户工作中）
  - prowlarr `Missing translation`、decluttarr pre-start、jellyfin WS 断开 = 噪音
