# router（NanoPi R5C，家庭网关）

与上游 `lt-home-router` 同构：主题文件止步于 `ddns`/`dhcp`/`firewall`/`networking`，
各服务的定义与取值调整落在主配置 `configuration.nix`。`hosts/router/*.nix` 不写注释，
理由记录在本文件。

## 入站与转发

- 家庭 Web 入口只有 opi5p 一台：公网 `{80,443}`、`4000`、`8443` 与内网 hairpin 443
  全部 DNAT 到 opi5p；2222 SSH 仍落 rock5c，其余 br-lan 出站 catch-all 也落 rock5c。
- Palworld（UDP 8211）DNAT 到 chromebox，WAN 与 hairpin 两条规则都在 443/4000 之后、
  catch-all 之前。
- LAN 的 DNS 请求一律重定向到隔离的 CoreDNS client netns 地址（TCP+UDP，
  `br-lan` 与 `eth0` 两个入口名都要写）。
- `NAT_POSTROUTING` 对 `oifname "br-lan" ct status dnat` 与 `oifname != {"br-lan","lo"}`
  做 masquerade。**lo 必须豁免**（与 exam `lt-home-router` 一致）：把本机 lo 出站的
  包改写源地址会变成 ZT IP，破坏本机服务对发送方的校验，典型症状是 miniupnpd 把
  NAT-PMP 探测当成 "not from a LAN" 丢弃。
- 过滤策略是作者式 policy-accept：只写显式 drop（timestamp ICMP、ZeroTier 上的
  Avahi mDNS、WAN mDNS、never-exposed 端口经 `PUBLIC_INPUT`），clamp TCP MSS，允许
  established 与 DNATed 连接。

## 硬件的坑

- RTL8125 在 probe 时读不到板载 EEPROM MAC，两个口先拿临时地址；`eth1` 钉成
  OpenWrt 时代同款 WAN 身份（部分 ISP 把 PPPoE 会话绑 CPE MAC），`eth0` 也钉到出厂
  永久地址，避免 LAN bridge 身份依赖 udev 的 machine-id 派生策略。
- 两个 RTL8125B 口都要关 EEE（PHY 固件 `rtl8125b-2_0.0.2` 从 EEE 低功耗唤醒会失败，
  间歇掉 carrier）；NixOS 的 `linkConfig` 不暴露 EEE，用 ethtool 直接设。
- 每口 4 个 RX 队列：把 `eth0-0..3` / `eth1-0..3` 的 MSI-X IRQ 各钉到对应 CPU，
  并关掉 irqbalance——它把多个队列挤在一个核上，多流负载下产生 rx_missed/重传。
  RPS 流表按两网口 × queueCount 覆盖（`2 * queueCount`）。
- qdisc 保 `mq` + 每硬件 TX 队列一个 `fq_codel`；换成单个根 `fq_codel` 会把两个
  RTL8125 TX 队列合成一个。
- r8125 驱动 reset 或 link 重新初始化会清掉 qdisc/affinity/RPS 设置，而 systemd 仍
  认为 oneshot 是 active，所以 `router-rps` 每分钟重新断言一次。
- 队列/RPS/NAPI 取值都有 A/B 中位数依据，见
  `docs/human/research/10-router-rx-queue-4.md`。

## WAN / LAN

- 物理 WAN 是 `eth1`（PPPoE 独占寻址与默认路由），WAN 身份见上。
- pppd 持有 PPPoE 的 IPv4 地址与默认路由；`ppp0.network` 里必须显式保留它们，否则
  IPCP 完成后 networkd 应用配置时会把地址/路由丢掉，WAN 只剩 IPv6。
- IPv4 由 pppd 协商；networkd 请求 ISP 下发的 IPv6 PD，并把一个 /64 分给 br-lan。
- CAKE 只塑上行：2026-10-17 用户报的真实套餐是千兆下 / 50M 上，上行设 45M（标称
  90%）让 CAKE 在运营商缓存积压前接管队列，保游戏低延迟；下行维持 1G 不塑形，只
  保留 fq_codel 型公平调度。此前 `Bandwidth=1G` 高于真实上行，阈值形同虚设。
  （作者原方是 dual-src-host/NAT/diffserv8，实测见
  `docs/human/research/11-network-acceptance-2026-08-12.md`。）
- br-lan 承载本机 PVE 虚机与物理客户端；静态 IPv4 网关 + ULA + 下发的 IPv6 前缀，
  RA 的 M/O 置位配合 kea-dhcp6 发 ULA 地址，PD GUA 走 PIO SLAAC。
- WLAN 用 hostapd：MediaTek MT7921 是首选射频（比 Intel 7265 支持 802.11ax，mt76
  上游驱动在 AP 模式上比 RTL8852BE 的 rtw89 更合适）。信道 36 属于以 42 为中心的
  80 MHz 块。hostapd 会把 wlan0 从 managed 切到 AP 模式再加进 br-lan，networkd 不能
  抢先 enslave 仍是 managed 的接口。主机级补 `Restart`/`RestartSec ≥ 3s`：上游
  treewide `RestartSec`（b1383d16）的 ensure-service-restart 断言会拒绝更小的值或
  缺失的 Restart，hostapd 是本仓独有的消费者（上游没有 AP 主机），不偏离 nixpkgs
  hostapd 模块默认值。
- 全局 wait-online 被 minimal networking 关掉；NFS 挂载前单独等静态 LAN bridge
  （对齐 opi5p 的 lan0 做法）。
- 全舰队的 ZeroTier 接口白名单没有 `ppp` 前缀（作者的路由器用 `eth1.201` 之类的
  VLAN 子接口），ppp0 会落进生成的 blacklist，daemon 绑不上 PPPoE 上行：PLANET
  roots 一个包都回不来（每个 peer `paths=[]`），整个家庭 overlay 因为控制器不可达
  而停摆。主机级从原始白名单重新派生（排除 netns 前缀，同模块）再加 `ppp`。

## nftables 快速路径（flowtable）

- `nftables.service` 在主规则集之前加载，而 flowtable 需要真实 netdev；上游 NixOS
  issue #141802 建议在接口就绪后用独立 service 加 flow offload，失败不致命。需要
  带 `NF_FLOW_TABLE` 的新内核（分阶段重启后生效）。只 offload WAN（ppp0）流量；
  hairpin 流量留在常规 netfilter 路径，重传收益的测量见
  `docs/human/research/10-router-rx-queue-4.md`。
- 被 offload 的流会绕过 `FILTER_FORWARD` 其余部分，所以**首包之后才可能变化的策略
  必须写在 pre-forward 钩子里**。
- PPPoE 重拨会重建 ppp0，旧的 flowtable 绑定必须重建；一次性迁移先删掉无主的
  flow-add 规则再重新断言。nftables 重启会 flush 表，定时检查服务一分钟内恢复快速
  路径，pppd-wan 那边覆盖重拨场景。脚本设计成幂等，短定时器重复执行。

## NAS 挂载

- 与 opi5p 同款：`noauto` + automount（裸 mount 在 NAS 未就绪时失败且不重试），
  额外保留 `nofail`——router 是 LAN 网关，NAS 掉线也必须照常起来。
- `/mnt/storage.mount` 加 `StartLimitIntervalSec=0`，NAS 掉线窗口里的反复 mount 不会
  撞 5 次/10s 限流。
- R5C 的硬件模块会 `mkForce` 替换 `boot.supportedFilesystems`，主机级镜像它的列表
  再加 nfs；内核配置本身已有 `CONFIG_NFS_FS=y`，`nfs-utils` 提供 `mount.nfs`。

## 服务

### VaultS3（对象存储）

原生跑在 router 上（`192.168.0.1:9000`），家庭 8443 TLS 前沿在 opi5p。凭据用全舰队
约定：access key 是统一账号，secret key 取共享 `default-pw`。

### qBittorrent（下载链主力，自 opi5p 迁入）

- 公共模块保持上游对齐，router 只加主机级扩展键：官方 client、固定端口、单 WAN
  接口、统一保存路径、LAN 免鉴权。
- `Session\Interface` 保持未设置（"Any interface"）：PPPoE 重拨会重绑网卡
  （2026-08-13 的原因记录在主实例的 `qbitPreStart`）。
- 本机的 qBittorrent 构建不把 IPv4 `127.0.0.1` 当 loopback 做 WebUI 免鉴权，`[::1]`
  可以；保持作者式 vhost 结构，只改主机级后端地址。
- 主实例（bt 刷流）上传锁 2500KB/s（2026-10-17 用户定）：整夜上行峰值 87Mbps 后当天
  早晨被运营商踢线进 CGNAT（pppd/miniupnpd 日志），用全局总闸压低风控触发概率。
- PT 订阅实例 `qbittorrent-pt`（WebUI 13809、torrenting 31121）：与主实例同法的
  conf 规整 preStart，只是 conf 路径换成 pt profile 目录，并显式置零全局上下行限速
  （订阅不限速）。刷流留主实例（`bt.*`），订阅下载走 `pt.*`。接线对齐 exam
  `pve-epyc` media-center：同一统一下载路径 Bind、存储就绪 marker/NFS 挂载门控。

### miniupnpd watchdog

miniupnpd 在 PPPoE 重拨瞬间读到 ppp0 无地址后会永久卡死（journal：`ext interface
ppp0 has no IPv4 address` / `cannot get public IP address, stopping`），此后所有
NAT-PMP/UPnP 添加永远返回 Network Failure，daemon 自身没有恢复逻辑（2026-09-15 巡检
实锤）；上游模块假定静态 WAN。

旧实现用 `natpmpc` 从本机自检映射，2026-09-23 实锤两层缺陷：探测包经 lo 出站被
`NAT_POSTROUTING` masquerade 改写源地址（firewall 已补 lo 豁免），且 `natpmpc` 会按
`/proc/net/route` 顺序绑到非 LAN 接口，两者都让 miniupnpd 判定 "not from a LAN" 丢弃，
自检永久失败形成 2 分钟一次的重启循环（6 天 911 次），频繁重写 iptables 间歇性杀掉
LTNET 的 UDP 路径。现在改为事件驱动：miniupnpd 启动时记录 WAN 地址，看门狗只在
地址变化时重启，稳定状态零动作。

### Prometheus textfile 指标（邻居/DHCP/连通性）

- 没有 DHCP 租约的静态服务器也要有主机名标签：DHCP 租约仍是动态客户端的主来源，
  静态服务器用 `LT.hosts` 里 home-lan 的地址映射补。
- Kea 可能对同一租约输出多次，重复的 label set 会让 textfile collector 报错。
- 探针输出的行尾必须吞掉单位后缀（iputils 输出 `... /0.104 ms`），否则 Prometheus
  文本格式把 `ms` 当 timestamp 解析失败，整个 textfile 被丢弃。
- nginx vhost 用 exam `pve-components/nginx.nix` 同构的三件套：缺 `vhosts-default`
  时 `_default_http` 不存在，Prometheus 以 IP 作 Host 抓 `/metrics` 会掉进
  `bt.localhost` 被 localhost-only ACL 拒绝（403），形成监控盲区。

### DHCP（Kea）

- MAC → IP 的保留项放 secrets 仓（同作者 `lt-home-router/dhcp.nix`）。
- 明确指定用户，不依赖 nixpkgs 模块的 DynamicUser。
- 地址布局同作者：基础设施地址静态，普通家庭设备只从 `.100-.249` 池分配。
- 地址是环境事实：br-lan 只挂静态 ULA `fc00:192:168::/64`——运营商的 PD /64 是动态
  前缀，Kea 无法静态建子网，GUA 仍由 networkd 的 RA PIO SLAAC 承接。

## DDNS

WAN 变为可路由时触发 DDNS 更新（`ddns-gcore`）。
