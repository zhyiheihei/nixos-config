# 全舰队健康巡检记录（临时文档，2026-10-07）

> 性质：临时巡检记录，方法与分级口径见 [巡检规范](inspection-playbook.md)：
> 🔴 影响功能 / 🟡 间歇或降级 / 🟢 噪音。上轮记录见 [2026-09-28](inspection-fleet-20260928.md)。
> 本轮以 SSH 2222 连通性为先：不通直接标离线，不做后续排查。

## 舰队快照（2026-10-07 13:00 前后采集）

- 在线 15 台 + 控制机本机；**ml-builder 离线**（LTNET 2222 超时，与 9-28 相同，连续两轮）；
  **taishanpi 离线**（LTNET 2222 超时，与 9-28 相同）。h28k / opi03 未部署照例排除。
- 全部在线主机 generation 已统一到 `26.11pre1076192.20b1ddd1aa5a`（20b1dd）。
- 多台主机在 9-22～9-26 部署波次中重启过（router 9-22、opi5p 9-23、rock5c 9-25、dragon 9-26 等）。
  注意：**router/rock5c 的 `uptime` 命令输出不可信**（busybox uptime 显示 3349 天/203 天，
  与 `/proc/uptime`、`/proc/stat btime`、PID1 启动时间三方矛盾），真实启动时间以 btime 为准；
  上一轮记录的「router uptime 3340 天未重启」同为该假象，router 实际 9-22 就重启过。
- 监控链：tencent 四件套（prometheus/alertmanager/grafana/nginx）全 active；
  148 目标 107 up / 41 down。down 集合构成本轮排查主线（见下）。
- 上一轮全部舰队级 🔴 均已闭环：tencent nginx ✓（已部署修复）、opi5p `/run/sftp` ✓（视图健康）、
  pve/google nginx-config-reload + acme 目录 ✓（failed 清零）、本机备份 btrfs 快照修复 ✓（两备份单元今晨 Finished）、
  greencloud radicale LDAP 超时 ✓（12h 内 0 条）。

### 批次状态

| 批次 | 范围 | 状态 |
| --- | --- | --- |
| 连通性 + 监控概览 | 全主机 + tencent Prometheus | ✅ 已写入 |
| B0 本机 | ml-laptop | ✅ 已写入 |
| B1 家庭 LAN | router、opi5p、rock5c、dragon-q8b、lubancat1、chromebox、ml-2700 | ✅ 已写入 |
| B2 VPS | tencent、greencloud、greencloud-jp、hostdare、volcengine、google、tencent-cn、pve-5700u | ✅ 已写入 |
| LTNET 抓取链 | tencent → 6 主机 exporter down 根因 | ✅ 已写入 |

---

## 🔴 本轮发现（按优先级）

### 1. router qbittorrent 瘫痪 6 天，已被今晨部署自愈（无需动作，留档）

- 单元引用 `user = 'lantian'`（上游用户名，本机无此用户）→ 状态 217/USER 重启循环，
  计数器 88636+，从 ~10-1 持续到 10-7 03:25，下载链瘫痪约 6 天。
- 根因：上游同步（9-26 ed75473fc / 10-6 a0f701585）把上游 `services.qbittorrent.user = "lantian"`
  原样带回，router 中间几代 gen（99/100/101，9-28 22:49 ～ 10-6 15:56）携带回归态；
  10-7 认可替换 46129d2b1（lantian→zhyi）+ 今晨 03:25 gen 102 部署修复。
- 现状：qbittorrent active（User=zhyi），9 条活跃 socket，downloads 今日有新内容 ✓。

### 2. router miniupnpd NAT-PMP add 全失败 27h，重启已修复（留观察项）

- 10-6 10:18 起 miniupnpd 对所有 NAT-PMP/UPnP 添加请求报 `Failed to add`（~782 条/h，
  目标 rock5c:42593），nft `inet miniupnpd` 三条链全空，无一成功；ppp0 本体健康。
- 13:09 重启 miniupnpd 后恢复：nft 表新增 28 条映射，rock5c:42593 的 dnat 已在工作。
- 已知局限：事件驱动看门狗（记忆 #197）只在 **ppp0 地址变化**时重启，本次 daemon wedge
  发生在重拨**之前**且地址未变（115.215.8.74），看门狗覆盖不到。待办（需用户决定，router
 受上游对齐约束）：看门狗扩展「定期自检一条探测映射」或失败计数重启。
- 同窗口（10-6 15:56）PPPoE 重拨过一次，重拨与 wedge 的因果关系未定，勿当结论。

### 3. LTNET 抓取链：tencent 侧 4 台家庭机 exporter 永久 down（待用户决定清理）

tencent 的 wg 隧道实况：wgmesh123(rock5c) 握手停在 9-22、wgmesh129(dragon) 9-22、
wgmesh131(chromebox) 10-1、wgmesh124(lubancat1) 从未握手、wgmesh114(ml-builder) 9-22。
这与 10-1「家庭机退出 BGP mesh」的决定吻合：**主机侧已按决定退出，tencent 侧 wg peer 与
Prometheus 抓取目标未清理**，造成约 24 个目标的永久 down。清理属 repo 配置变更
（删 mesh-exited 主机的 exporter 声明/wg peer），按约束 #64 不擅自执行，待用户确认。

### 4. tencent-cn LTNET 自接入（9-23）起未打通过（bring-up 缺口）

- 本机服务全健康（备份/rsync 走公网正常，今晨备份 Finished）。
- 去 tencent 的 LTNET /32 路由指向 **从未握手的 wgmesh128**（handshake=0），
  而 zt 链路活着（ping router 198.18.0.112 通 105ms）→ 非对称路由黑洞，
  tencent ↔ tencent-cn 双向 ping 均不通，6 个 exporter 目标全部 down。
- zerotierone.service 本体 active，zt 网络已授权拿到达配地址；wg 隧道为何从未建立
 （对端 key 登记/endpoint/传输方式）待 bring-up 排查。按约束不动线上配置。

### 5. ml-builder / taishanpi 离线（连续第二轮）

- 双机 LTNET 2222/ICMP 全断，按用户指示标离线跳过。
- 下游影响：opi5p hydra-queue-runner 持续报 `failed to start SSH connection to ml-builder`
 （构建派发目标不可达）；sglang-sakura-llm 黑盒目标连带 down。

---

## 🟡 观察项

| 项 | 现象 | 判断 |
| --- | --- | --- |
| google LTNET 抖动 | 3 天 node 抓取健康度仅 40%，当前通（exporter curl 200、wg 握手新鲜）；knot exporter 连带 down，本机 knot-exporter active 且 :9433 正常监听 | 跨境隧道质量，非主机故障 |
| opi5p 备份 exit 1 | 今晨快照成功（e9712ccc，369MiB 入库）但收尾删 `/nix/.snapshot` 阶段 exit 1，单元记 failed | 数据安全，属收尾卫生问题；历史日志已被 journald 回收，无法定位起始日 |
| opi5p hydra-attic-repush exit 1 | 工作全部完成（各批 "All done, 0 in upstream"）后脚本以 1 退出 | 同类收尾卫生问题 |
| opi5p 负载 | load 6.08（immich ML / frigate rknn / reDroid / One-KVM 常驻满载），内存 10.7/16G | 板子忙而非异常，巡检勿再压测 |
| greencloud 今晨备份失败 | `Could not resolve hostname greencloud-jp.ltnet.zhyi.xin`（LTNET DNS 瞬断，跨境抖动受害者），04:13 失败 | timer 会自愈，明晨复核 |
| rock5c 媒体链 | moviepilot 24h 87×ConnectionRefused（traceback 无目标端口，TMDB 识别正常）+ chinesesubfinder 每小时 `www.a4k.net EOF`（源站问题） | 应用侧，同上轮待用户决定 |
| greencloud-jp 昨夜重启 | 10-6 15:19，与 router gen 101（15:56）同属 10-6 15 点部署波次（推定 kernel 更新重启）；journal 非持久无法留痕 | 部署伴随行为，非故障 |
| tencent whois-go | inactive、:43 无监听（nginx 43 口 upstream 半残，上轮已知状态未变） | 慢性，记录在案 |

## 🟢 各机结论速览

| 主机 | 结论 | 要点 |
| --- | --- | --- |
| router | 🟢（处理后） | failed 无；qbittorrent/miniupnpd 已修复；rsync Finished |
| opi5p | 🟡 | 见观察项三条；/run/sftp 视图健康；/run/nfs/storage 挂载正常（**上轮记录的「/run/nfs-storage 目录不存在」系路径笔误，实际路径为 /run/nfs/storage，一直健康**） |
| rock5c | 🟡 | 备份 Finished；媒体链见观察项；qnap NFS 51% 正常；failed 仅 rsync（跨境） |
| dragon-q8b | 🟢 | 备份 Finished；failed 仅 rsync；wallos 1446 条为归因噪音 |
| lubancat1 | 🟢 | 备份 Finished；failed 仅 rsync |
| chromebox | 🟢 | 备份 Finished；failed 仅 rsync；byparr 10 条噪音 |
| ml-2700 | 🟢 | failed 无；备份 Finished；rsync Finished；udevd plugdev 噪音 |
| tencent | 🟢 | 监控栈全 active；备份 Finished；archiveteam 噪音 |
| greencloud | 🟡 | 备份今晨 DNS 瞬断失败；其余干净（上轮 5 个 rsync@* 瞬态 failed 清零） |
| greencloud-jp | 🟢 | 最干净（err 18）；昨夜重启为部署波次 |
| hostdare | 🟢 | err 13，全噪音 |
| volcengine | 🟢 | 备份 Finished；sshd 扫描噪音 |
| google | 🟡 | LTNET 抖动（见观察项）；本机备份 Finished |
| tencent-cn | 🟡 | 本机全绿，LTNET bring-up 缺口（见 🔴 4） |
| pve-5700u | 🟢 | failed 无；上轮 acme/reload 问题消失 |
| ml-laptop（本机） | 🟢 | 10-6 11:15 重启；failed 无；两个备份单元今晨 Finished（9-28 btrfs 修复生效）；err 10190 全为已知噪音（udevd plugdev 8268 + samba-nmbd 1617） |

## 慢性噪音清单（下轮直接跳过）

gopher/whois 6 台 VPS 告警（8-23 起：fork 服务 banner 为 zhyi 而探针 expect 仍是上游
`gopher.lantian.` / `LANTIAN-DN42`，上游对齐产物，告警常驻）；https_2xx 9 条（8-23 起：
github-pages/netlify/render/vercel/lab/sip/comments 为上游遗留探测目标且本仓 DNS 无记录，
asf/jellyfin 解析到家宽 IP 而公网 443 被 ISP 封禁）；udevd plugdev（u2f 规则）、
samba-nmbd 广播、mptcp、sshd 扫描、podman-archiveteam / podman-wallos 归因噪音、
filebeat8 cgroup 系、hydra linking 输出。
