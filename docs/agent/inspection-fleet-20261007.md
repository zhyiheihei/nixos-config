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

## 处理日志（2026-10-07 下午）

### tencent-cn LTNET 修复 ✅

- 根因：wgmesh132 的 netdev 在 tencent/hostdare/volcengine/google 四台的 `/etc/systemd/network`
  里已存在，但 systemd-networkd 自 9-21 起未重载，接口从未创建；tencent-cn 的 /32 路由指向
  从未握手的 wgmesh128 形成非对称黑洞。密钥核对无误（对端 pubkey 与本地 wg-priv 推导一致）。
- 处置：四台 `networkctl reload` → wgmesh132 全部建立，tencent↔tencent-cn 31ms；
  tencent-cn 对 hostdare/volcengine/google/greencloud/greencloud-jp/opi5p 握手全建。
- 验证：Prometheus 上 tencent-cn 5 个目标全部 up（此前自接入起全 down）；node exporter
  直接抓取 200。
- 注意：switch 不会让 networkd 自动加载新增 netdev，后续新主机接入 mesh 后需
  `networkctl reload` 或重启 networkd/主机。

### mesh 退出收尾（10-1 决定的运行时落地）✅

- tencent + rock5c + chromebox + dragon-q8b + lubancat1 五台已部署当前 HEAD：
  家庭机 wgmesh 全部消失、tencent 抓取清单收敛（down 41→28，up 107→120）。
- greencloud/greencloud-jp/hostdare/volcengine/google/tencent-cn/opi5p 的
  wgmesh1{14,23,24,29,31} 陈旧 peer 留待下次常规部署自然清除（无流量、无危害）。

### 新发现问题 ①：greencloud zerotierone 无法启动（已修复）

- zt 重启波次触发 1.16.0 迁移守卫：`FATAL: an old controller.db exists in
  /var/lib/zerotier-one`。该 db 为 0 表空壳（真控制器状态在独立的
  `/var/lib/zerotier-one-controller`，greencloud 同时跑着控制器实例，监听 9994）。
- 已归档为 `controller.db.legacy-bak-20261007` 并启动，成员 + 控制器双 active。
- 注意：greencloud 上 `pkill zerotier-one` 会连带杀掉控制器实例，处置该机 zt 时
  必须区分两个 unit（zerotierone / zerotierone-controller）。

### 新发现问题 ②：zt v4 单播家庭↔机房方向不通（v6 正常，待专项排查）

- 证据链：underlay hello 双向流动、peer 握手全绿（版本/延迟齐全）、控制器成员表全部
  authorized 且 ipAssignments 正确、flow rules 为 ACCEPT、全员 netconfRevision=37；
  v4 echo 进入对端 tap（tcpdump 实证）但对端不回、双向 v4 单播静默；同组 v6
  （fdd8::/48）全部秒通；ARP 广播帧可通（删静态 neigh 后能重新学习到 REACHABLE），
  但紧随其后的 v4 单播依然 100% 丢。控制器重启前后行为一致。
- 定性：zt 1.16.0 内部对 v4 单播的投递问题（v6 依赖 RFC4193 NDP 模拟所以幸存），
  非配置问题，本会话不具备继续下钻的成本收益。
- 影响面与规避：
  - 备份链无碍：`opi5p.zhyi.xin` 解析优先返回 fdd8::122（v6），chromebox→opi5p:22
    v6 实测通，当夜备份已验证路径。
  - rock5c homepage 的 prometheus 读取当前 200（走公网入口，不依赖 zt v4）。
  - 残余 28 个 down 目标中约 16 个为家庭机 exporter（v4 zt 不达）+ ml-builder/
    taishanpi/h28k/opi03 离线组 + google/hostdare knot（LTNET 抖动）。
- 待办选项（需用户拍板）：① 专项排查 zt v4（开 daemon debug 日志、必要时降级验证
  1.12/1.14 行为）；② 家庭机 exporter 从 tencent 抓取目标中显式豁免（登记偏离）；
  ③ 维持现状观察上游 zt 版本。

### 其他当次处置

- router miniupnpd：13:09 重启后 NAT-PMP add 全部恢复（nft 表 28 条映射、rock5c:42593
  已在实际转发）。根因仍未知（wedge 发生在 10-6 10:18，早于 15:56 的 PPPoE 重拨），
  看门狗只覆盖地址变化场景，扩展自检方案待用户决定（记忆 #197 明确否决 natpmpc
  探测式，勿回退）。
- 本机 zt restart 试图超时但老进程未死、服务 active，无影响；后续对本机 zt 操作注意
  systemctl stop 可能挂起。

## 慢性噪音清单（下轮直接跳过）

gopher/whois 6 台 VPS 告警（8-23 起：fork 服务 banner 为 zhyi 而探针 expect 仍是上游
`gopher.lantian.` / `LANTIAN-DN42`，上游对齐产物，告警常驻）；https_2xx 9 条（8-23 起：
github-pages/netlify/render/vercel/lab/sip/comments 为上游遗留探测目标且本仓 DNS 无记录，
asf/jellyfin 解析到家宽 IP 而公网 443 被 ISP 封禁）；udevd plugdev（u2f 规则）、
samba-nmbd 广播、mptcp、sshd 扫描、podman-archiveteam / podman-wallos 归因噪音、
filebeat8 cgroup 系、hydra linking 输出。
