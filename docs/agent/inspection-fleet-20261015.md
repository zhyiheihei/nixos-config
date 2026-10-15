# 全舰队健康巡检记录（临时文档，2026-10-15 08:00–08:40）

> 性质：临时巡检记录，方法与分级口径见 [巡检规范](inspection-playbook.md)：
> 🔴 影响功能 / 🟡 间歇或降级 / 🟢 噪音。上轮记录见 [2026-10-07](inspection-fleet-20261007.md)。
> 本轮口径（用户指定）：SSH 不通的主机直接跳过；只判定好坏，故障原因不深挖。

## 舰队快照

- 在线 14 台 + 控制机本机；**ml-2700、pve-5700u、taishanpi SSH 不通**（按要求跳过；
  pve-5700u 属人工关机常态，taishanpi 与 9-28/10-07 两轮相同，ml-2700 本轮新离线）。
  h28k / opi03 未部署照例排除。
- generation 两代并存：`26.11pre1089111.6510408d147d`（rock5c/dragon-q8b/opi5p/tencent/
  volcengine/greencloud-jp）与 `26.11pre1086391.151fa4e8ddfd`（其余 8 台）。部署波次未覆盖全舰队。
- 本轮已当场恢复 3 项：rock5c jellyfin（start ✓，对外 302）、router miniupnpd（restart ✓，
  映射重建）、opi5p journald@epd（start ✓）。其余见下。

## 🔴 本轮发现

1. **storagebox 双备份全舰队认证被拒**：chromebox/tencent-cn/opi5p/lubancat1/google/
   greencloud/tencent 的 backup-nix-persistent 全部在第二仓库
   `u378583-sub2@u378583-sub2.your-storagebox.de:23` 报 `Permission denied (publickey,password)`；
   从 chromebox 用 sops 里的 sftp-privkey 手动 ssh 同样被拒 → key 在 Hetzner 侧失效，
   非网络问题。**需用户在 Hetzner Robot/StorageBox 检查并重新登记 SSH key**，修复前
   每晚第二备份持续失败（第一仓库 snapshot 仍成功保存，整体 exit 1）。
2. **home repo 备份窗口（今晨 04:13–05:02）全舰队连不上 opi5p**：backup 的 sftp 端
   opi5p.zhyi.xin 被 ssh-harden 强制 v6，而 tencent→opi5p 当前 v6 `No route to host`
   （v4 通），greencloud↔opi5p v4/v6 双栈都不通（chromebox↔两端正常）。即
   ssh-harden.nix 注释所述「LTNET CN↔家宽方向间歇黑洞」当前 flare，今晚备份窗口
   大概率再失败。
3. **rock5c jellyfin 停机 4.5h**（03:55:16 退出，exit 0，Restart=on-failure 对干净退出
   不生效）→ jellyfin.zhyi.xin 502、moviepilot 同步报 jellyfin API 空。已 start 恢复。
   （跟进项：是否给 jellyfin 补 `Restart=always`，受上游对齐约束，留用户决定。）
4. **immich.zhyi.xin 502**：opi5p 侧 immich-server active，rock5c 443 前置回源失败。
5. **ml-builder 备份 7 天 0 次成功**：pre-start btrfs subvolume 反复 `Text file busy`
   （195 次/7d），`snapshot successfully saved` 在窗口内出现 0 次 → ml-builder 备份
   连续一周失败。
6. **tencent Prometheus blackbox 告警 9 域名 firing**（asf/comments/github-pages/jellyfin/
   lab/netlify/render/sip/vercel 的 https_2xx）：jellyfin 已随第 3 项恢复；其余域名本机
   解析多失败——homepage/vaultwarden/comments/archivebox/atti 在
   `dns/domains/zhyi.xin.nix` 无登记，探针目标疑似弃用/漂移待清理。另有
   `sglang-sakura-llm / sakura-llm.ml-builder.zhyi.xin` 目标后端已无对应服务单元（陈旧目标）。
7. **exporter down 集（LTNET 抓取链）**：dragon-q8b/rock5c/opi5p 的
   coredns-authoritative/knot/wireguard/nginx、smartctl/pve-5700u、node/taishanpi、
   node/opi03、coredns/h28k 等 ~17 个目标 down（未深挖，与主机侧退出 mesh 的既有
   状态相关）。

## 🟡 降级/间歇

- **router miniupnpd wedge 复发**（10-14 22:01 `ioctl SIOCGIFADDR` 之后 add 全失败，
  195 次/24h，NAT-PMP 目标含 ml-2700 syncthing、chromebox）；今晨 restart 后 0 失败、
  5 条映射在位。10-07 同型问题，看门狗只覆盖 ppp 地址变化、覆盖不到本次形态，
  扩展方案仍待用户决定。
- **opi5p hydra-update-gc-roots 每日失败**（02:15，exit 13 `cannot create GC root`）。
- **opi5p/chromebox podman-auto-update exit 125**（00:19 / 01:39 一轮），容器本体均 running。
- **opi5p journald@epd watchdog 被 kill**（02:27:56，伴随内存压力；已 start 恢复 active）。
- **greencloud-jp vaults3-init-nix-cache 10-13 失败**（exit 254）；vaults3.service 与
  atticd 均 running，S3 网关可用，仅一次性 bucket-init 保障缺失，观察。
- **rock5c chinesesubfinder**：assrt SubtitleBestApi / a4k 外部 API 报错（字幕源问题）。

## 🟢 噪音（记录避免重复排查）

- podman 容器 stdout 全部以 err 优先级进 journal：moviepilot 4.5 万、chinesesubfinder
  1.8 万、byparr、archiveteam 的「错误计数」绝大多数是 INFO 行误分；真实错误见上。
- bird「Inferring function … return type」（hostdare/lubancat1/tencent-cn 等，bird 3 配置推断）。
- sshd 扫描器 kex reset（hostdare/volcengine/tencent-cn/各 VPS，对外端口常态）。
- mptcpd add/remove 地址告警（dragon-q8b/router/rock5c，2–10 条/24h）。
- opi5p samba-nmbd LTNET 网段 NetBIOS 多响应（198.18.0.118 侧 WORKGROUP<1d> 双响应）。
- ml-builder systemd-networkd 配置解析警告（IPv4 gateway for IPv6 route / eth0 模糊匹配）。
- greencloud matrix-synapse federation 404（外部服务器 myelin.dacrib.net）。
- 各备份机的 rsync@…@873 瞬时 per-connection 实例 failed 属客户端超时残留。

## 待办（按优先级）

1. 用户：Hetzner StorageBox SSH key 检查/重新登记（🔴-1）。
2. 观察 LTNET v6 到 opi5p 黑洞是否自行消退，决定 home repo 备份是否需要绕行（🔴-2）。
3. rock5c jellyfin 加 `Restart=always` 偏移登记（需用户认可，🔴-3）。
4. immich 前置回源失败排查（🔴-4，下轮或专项）。
5. ml-builder btrfs Text file busy 修复（🔴-5，可参考 10-07 本机快照修复方式）。
6. Prometheus blackbox 陈旧目标清理（🔴-6，清单：comments/github-pages/netlify/render/
   sip/vercel/lab/asf 中已不存在域名的、sglang-sakura-llm）。
