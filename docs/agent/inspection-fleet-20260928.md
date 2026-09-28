# 全舰队健康巡检记录（临时文档，2026-09-28）

> 性质：临时巡检记录，按批次分次补齐后归档或删除。
> 方法与分级口径见 [巡检规范](inspection-playbook.md)：🔴 影响功能 / 🟡 间歇或降级 / 🟢 噪音。
> 只记录现状，不做诊断；每批次完成后在「批次状态」打勾。

## 舰队快照（2026-09-28 15:35 前后采集）

- 全舰队已切换到新 generation `26.11pre1076192.20b1dd`（9-26 巡检时多数主机仍在 `pre-git` 旧 gen）。
- 在线 15 台 + 控制机本机；**ml-builder 离线**（LTNET ping / 2222 全断，9-26 时尚在线）；**taishanpi 离线**（LTNET + LAN 全断，9-26 LTNET 口可达）。h28k / opi03 未部署照例排除。
- 舰队级 🔴：① tencent nginx down（缺 `/nix/sync-servers/acme/zerossl-xuyh0120.win-rsa/fullchain.pem`，start-limit-hit）；② 该 acme 目录在 google / pve 同样缺失，`nginx-config-reload` 双双 timeout；③ rsync-nix-sync-servers 链路部分主机最近一次仍失败；④ 备份链今晨 04:07–05:02 在 9 台失败（greencloud 报 sftp `connection request: timeout`，opi5p `/run/sftp` 空视图）。
- 舰队级 🟡：Prometheus 148 目标 / 100 up / 48 down（9-26 为 139/103/36）；rock5c moviepilot 报「无法连接 TheMovieDb」+ chinesesubfinder 15407 条 assrt 源报错。
- 连接性备注：ml-2700 与 pve-5700u 的 LTNET 口 2222 连接被 reset（SSH 本体健康，LAN/IPv6 口正常）。

### 批次状态

| 批次 | 范围 | 状态 |
| --- | --- | --- |
| B0 本机 | ml-laptop | ✅ 已写入 |
| B1 家庭 LAN | router、opi5p、rock5c、dragon-q8b、lubancat1、chromebox、ml-2700 | ✅ 已写入 |
| B2 VPS | tencent、greencloud、greencloud-jp、hostdare、volcengine、google、tencent-cn、pve-5700u | ✅ 已写入 |
| B3 离线确认 | ml-builder、taishanpi（+h28k/opi03 复核） | ✅ 已写入 |

---

## B1 · 家庭 LAN

采集时间：2026-09-28 15:35 前后（SSH 口，全部 2222）。

### router

- 结论：🟢。uptime 3340 天（未重启，**generation 仍是 `pre-git` 旧版**，全舰队唯一切完 gen 后未更新的非离线主机）。
- failed：无。err 24h 共 19 条（18 条 init.scope + 1 条 mptcp），无行动项。
- rsync-nix-sync-servers：12h 内 122 次 Finished，但 14:03 有一次 `Failed with result 'exit-code'`——间歇失败，非全断。

### opi5p

- 结论：🟡（负载回落、failed 清零，但 sftp 视图与 rsync 链未恢复）。
- uptime 5 天 2h；generation 已更新；load 2.2 / 3.3 / 3.4（9-26 为 5.5–7.2）；内存 8.9 / 16 GiB；磁盘 1%。
- failed：昨日 5 个（backup-nix-persistent / backup-prune / hydra-attic-repush / podman-auto-update / rsync-nix-sync-servers）全部清零。
- err 24h 共 63989：hydra-queue-runner 63786 条经抽样全部为 `linking "...system-units..."` 构建输出（journal 分级噪音，**非真错误**）；samba-nmbd 144 条。
- 🔴 事实未变：`/run/sftp` 目录 ls 仍为空视图（bindfs 失效实例特征，见 ARCHITECTURE #200）；`/run/nfs-storage` 目录不存在。
- rsync-nix-sync-servers 最近一次 15:30 失败（`rsync error: error in socket IO (code 10)`）。

### rock5c

- 结论：🟡（下载/整理链实际受阻）。
- uptime 194 天；generation 已更新；load 0.08；内存 3.3 / 7.9 GiB；磁盘 2%。failed 清零（昨日的 backup-nix-persistent、filebeat 均不在列）。
- err 24h 共 34517：
  - podman-moviepilot 19086 条，**15:36 起连续报 `连接TMDB出错：无法连接TheMovieDb`**——真错误，识别/整理链受阻；
  - podman-chinesesubfinder 15407 条，`SubtitleBestApi.GetMediaInfo failed`（assrt 源，逐集反复）。
- 数据链：qnap NFS `/mnt/storage` 正常（49%，12T）；downloads 今日有新内容（brush 9-26 10:38 更新，后续批次未复查到 9-28 当日新文件）。

### dragon-q8b

- 结论：🟢。uptime 1 天 17h（9-26 0:05 重启后又经历一次重启/部署）；generation 已更新；load 1.5；内存 2.6 / 7.3 GiB；磁盘 1%。
- failed：无。err 24h 共 1247：podman-wallos 1126 条（12h 抽样 journal 无 err/fail 内容行，属计数归因噪音）+ init.scope 113。

### lubancat1

- 结论：🟢。uptime 194 天；generation 已更新；failed 清零（**mnt-storage.mount 已不再 failed**，qnap 挂载恢复）；err 24h 共 31（mptcp 13 + user 会话 12 + dbus 2）。

### chromebox

- 结论：🟡。uptime 5 天 16h；generation 已更新；内存 4.4 / 9.8 GiB。
- failed：rsync-nix-sync-servers（最近一次 15:34 失败，code 10）。
- 备份：今晨 04:58 `backup-nix-persistent` 失败（exit-code）。
- err 24h 共 164：init.scope 144（即上述两个 unit 的反复失败记录）+ podman-byparr 10。

### ml-2700

- 结论：🟢（内容），🟡（LTNET 口）。uptime 5 天 16h；generation 已更新；failed 清零（昨日的 backup-home / backup-nix-persistent 不在列）；近 12h 无备份日志。
- err 24h 共 1260：systemd-udevd 1070（同类 plugdev 规则噪音）。
- rsync-nix-sync-servers：12h 内 132 次 Finished，但 14:04 一次失败。
- 连接性：LAN 口 SSH 正常；LTNET 口（198.18.0.113 / zhyi.cc 域名）2222 连接被 reset——SSH 本体健康，通道异常待 B3 一并核。

---

## B2 · VPS / 公网

采集时间：2026-09-28 15:35 前后。

### tencent（🔴 本批次重点）

- **nginx down**：15:10 起 pre-start 报 `cannot load certificate /nix/sync-servers/acme/zerossl-xuyh0120.win-rsa/fullchain.pem`，5 连败后 `start-limit-hit`，至今 failed；15:13/15:23/15:35 有人/进程尝试 reload 均报 unit inactive。
- 连带：whois-go inactive → nginx 0.0.0.0:43 upstream `whois.sock` 持续 connect 失败（crit 级，12:34 起多条）。
- grafana 本体运行，但 Grafana 13 拒载 angular 插件（piechart-panel / worldmap-panel validation failed）。
- podman-archiveteam 153 条 err（抽样无 err/fail 内容行，噪音归因）；rsync-nix-sync-servers 21 条 err，最近一次 13:53 失败。
- 备份：今晨 04:41 backup-nix-persistent 失败。
- Prometheus 栈本体（prometheus/grafana/alertmanager 进程）运行中。

### greencloud

- 结论：🟡。uptime 28 天；generation 已更新；load 0.4；内存 4.0 / 7.9 GiB。
- failed：5 个 `rsync@*` 瞬态 unit（来源 198.18.0.118 / .112 / .127，其中 .127 为已离线的 taishanpi）。
- radicale：12h 内 36 次 `Errno 110 Connection timed out`（OPTIONS /zhyi/）——与 9-26 相同模式，仍在持续。
- 备份：今晨 05:02 失败，后端报 `[ERROR] service=sftp ... stat => connection request: timeout`。
- 其他：podman-byparr 10 条、matrix-synapse 3 条 err。

### greencloud-jp

- 结论：🟢 最干净。uptime 28 天；generation 已更新；failed 无；err 24h 共 13；备份近 12h 无日志（无失败记录）。
- 15 分钟负载 1.85 偏高（均值 0.76/1.55/1.85），无对应 err。

### hostdare

- 结论：🟢。uptime 17 天；generation 已更新；failed 无；err 14 条（user 会话 8 + sshd 3）；备份无日志。

### volcengine

- 结论：🟡。uptime 59 天；generation 已更新；failed：rsync-nix-sync-servers（最近一次 15:26 失败）。
- err 84 条：init.scope 57 + sshd 5 + podman-halo 5；备份近 12h 无日志。

### google

- 结论：🟡。uptime 28 天；generation 已更新；failed：nginx-config-reload（08:57 timeout）。
- nginx / nginx-proxy 本体 active（跑旧配置）；`/nix/sync-servers/acme/zerossl-xuyh0120.win-rsa/` 目录缺失——证书续期后 reload 将不可用。
- 备份：今晨 04:16 失败。err 21 条（sshd 10 + user 4 + init.scope 3）。

### pve-5700u

- 结论：🟡。uptime 4 天 14h（重启过）；generation 已更新；内存 21.9 / 47.6 GiB。
- failed：nginx-config-reload（10:31 timeout）；nginx active、nginx-proxy inactive；acme 目录同缺。
- 昨日的 lvm-activate-local-lvm failed 已清零。err 40 条（mptcp 27 + init.scope 7）。
- 连接性：IPv4 LTNET 2222 连接被 reset，IPv6（fdd8:1938:4e88::116）正常。

### tencent-cn

- 结论：🟢。uptime 4 天 7h；generation 已更新；failed 无；err 17 条（sshd 5 + rsync 2 + user 8）；备份近 12h 无日志但今晨 04:45 有一轮失败记录（12h 窗口内可见）。

---

## B3 · 离线主机确认（2026-09-28 15:20 前后）

| 主机 | 探测 | 结果 |
| --- | --- | --- |
| ml-builder | LTNET 198.18.0.114 ping | 🔴 100% 丢包，2222 nc 无响应——主机下电/断网；9-26 还在线（当时 uptime 22h） |
| taishanpi | LTNET 198.18.0.127 ping + LAN 192.168.0.136 ssh | 🔴 双通道均不通——设备离线；9-26 LTNET 口可达（192 天 uptime） |
| h28k | 192.168.30.1 / h28k.zhyi.cc | ⬜ 不可达（staging 未部署，照例排除，不追究） |
| opi03 | opi03.zhyi.cc / .zhyi.xin | ⬜ 不可达（未部署，照例排除） |

---

## 汇总优先级（跨批次，仅排期未动手）

1. 🔴 rsync-nix-sync-servers 同步链（tencent nginx 起不来的直接前提条件；google/pve reload timeout 同源）。
2. 🔴 tencent nginx 恢复（证书文件就位后 `systemctl start nginx`）。
3. 🔴 备份链：opi5p `/run/sftp` 空视图 + 本机 btrfs 快照前置失败 + greencloud sftp timeout。
4. 🟡 rock5c：TMDB 不通 + chinesesubfinder 持续报错；libvirtd / podman-byparr 本机异常。
5. 🟡 ml-builder / taishanpi 离线，需人工确认（下电 or 携带外出）。
6. 🟢 全部噪音项（udevd plugdev、samba-nmbd、mptcp、sshd 扫描、hydra linking）下轮巡检直接跳过。

## B0 · ml-laptop（控制机本机）

- 采集时间：2026-09-28 15:40；结论：🟡（备份链本地失败 + libvirtd 异常退出，其余为噪音）

### 基本状态

| 项 | 值 |
| --- | --- |
| 当前 generation | `26.11pre1076192.20b1ddd1aa5a`（Zokor，已随 9-28 部署更新） |
| 本次启动 | 2026-09-28 14:51（kernel 6.12.110），累计 0:49 |
| 上次启动 | 2026-09-23 23:10 起，至 14:11 关机（4 天 15 小时） |
| 磁盘 | `/nix`（nvme0n1p2）954G，44% 已用（410G/954G），充裕 |
| 内存 | 11.0 / 31.6 GiB |
| 负载 | 0.71 / 0.65 / 0.80 |
| failed unit | 仅 `libvirtd.service`（昨天的 backup-nix-persistent / backup-home / podman-auto-update / smart-check 均已不在此列） |

### 24h 日志 err 级计数（总量 5240）

| unit | 条数 | 定性 |
| --- | ---: | --- |
| systemd-udevd | 3751 | 🟢 `70-u2f.rules` 各行反复报 `Failed to resolve group 'plugdev'`（每设备 10+ 行），规则文件噪音 |
| samba-nmbd | 204 | 🟢 `Packet send failed to 192.168.0.255(138)/10.88.255.255(138) ERRNO=网络不可达`，广播口无路由噪音 |
| user@1000 / user@0 | 191 / 142 | 🟢 会话级，未见可行动内容 |
| dbus-broker | 37 | 🟢 |
| podman-byparr | 30 | 🟡 见下 |
| samba-winbindd | 10 | 🟢 抽样无实质错误行 |

### 🔴 备份链（本地失败，未恢复）

- `backup-nix-persistent`：2026-09-28 00:43:38 失败。pre-start 报 **`ERROR: Not a Btrfs subvolume: Invalid argument`**，post-stop 报 `ERROR: Could not statfs: No such file or directory`。
- `backup-home`：2026-09-28 00:56:13 失败，同样一对报错（Not a Btrfs subvolume + statfs 失败）。
- 9-26 那轮失败时表现为 `Control process exited, status=1` 无本地 btrfs 报错；本轮在本地 pre-start 即失败，本地快照前置步骤本身已不成立。
- ⚠️ 与全舰队 sftp 超时并存：本地这次是「本地快照失败」，其余 9 台是「sftp→opi5p 后端 timeout」，两段都可能卡在备份链不同位置，待 B1 批次对照 opi5p `/run/sftp` 后再合并结论。

### 🟡 libvirtd

- 本次启动（14:51）后由 socket 触发拉起，15:07:33 start → 15:10:03 exit status=1（Duration 2min）。
- 无明确错误日志行，仅 `Main process exited, code=exited, status=1/FAILURE`；unit 处于 failed，三个 libvirtd socket 仍挂起等待激活。

### 🟡 podman-byparr

- 9-28 10:15 与 14:11（重启后）两次 `Failed with result 'exit-code'`；14:11 pre-stop 报 `no container with ID 9e30... found in database: no such container`——容器记录与 unit 状态不一致。

### 🟢 已恢复正常项

- `smart-check`：9-28 00:00:02 Finished（昨轮失败已不再出现）。
- `podman-auto-update`：failed 列表已清（9-26 的 byparr 镜像 TLS timeout 未复现，但 byparr 本身见上）。

### 待处理清单（本机）

1. 🔴 backup-nix-persistent / backup-home 的本地 btrfs 快照前置失败——本机 `/persist` 或对应快照源的子卷状态需要现场核对（未动手）。
2. 🟡 libvirtd 启动后 2 分钟退出 status=1，需带日志现场重启验证。
3. 🟡 podman-byparr 容器记录丢失，需重建容器或 `systemctl start` 验证。
4. 🟢 udevd plugdev（u2f 规则）与 samba-nmbd 广播噪音，无需处理，下轮巡检直接按噪音跳过。
