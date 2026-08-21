# R5C 家庭路由器调优记录

> 对象：家庭核心 router（NanoPi R5C / RK3568 / 4 核 / PPPoE + br-lan / nftables）。
> 本文合并 2026-08-11~12 的 flowtable、r8125 事故、RSS 与 RX 队列四轮调优记录。

## 1. flowtable + RPS 启用（2026-08-11，部署 `ca84caad`）

### 结论

- 受控 hairpin iperf3 回路中，开启 flowtable/RPS 后吞吐小幅提升约 2-3%，TCP 重传下降 97-99%。
- 软中断采样偏高（RPS 分散 + ingress hook 混淆），不作为提速证据；真实 WAN 对照未完成。
- 部署、PPPoE 重拨自愈、回滚路径均已验证，一次成功上线。

### 对照方法

公网 iperf3 测试点不可用，改用受控 hairpin 回路：rock5c `iperf3 -s -B 192.168.0.64`，router 临时 hairpin DNAT WAN IP → rock5c，客户端连 WAN IP 往返。对照组为同一内核（6.18.42）下 fast path 开/关，`-P 1` 与 `-P 4`。

### 结果

| 场景 | 基线（关闭） | 开启 | 变化 |
| --- | ---: | ---: | ---: |
| Forward P4（receiver） | 889 Mbit/s | 913 Mbit/s | +2.7% |
| Forward P4 重传 | 17732 | 493 | -97.2% |
| Reverse P4（receiver） | ~896 Mbit/s | ~914 Mbit/s | +2.0% |
| Reverse P4 重传 | 11967 | 104 | -99.1% |

### 改动

- 新内核 6.18.42，`NF_FLOW_TABLE*`/`NFT_FLOW_OFFLOAD`/`TCP_CONG_BBR` 生效。
- `router-flowtable`：forward 单条 `ct state { established, related } flow add @f`，含 `br-lan`+`ppp0`。
- RPS `f/4096`、backlog 5000、缓冲 16M、`rps_sock_flow_entries=4096`。
- PPPoE 重拨自愈验证通过；回滚走 extlinux 旧 generation。

## 2. r8125 NETDEV WATCHDOG 事故（2026-08-11）

### 时间线（boot -1）

```
r8125 eth0: NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out 6004 ms
r8125 eth0: Transmit timeout reset Device! / Device reseting!
systemd-networkd: eth0: Lost carrier
br-lan: port 1(eth0) entered disabled state
```

超时前无 PHY/EEE/PCIe AER 报错，链路此前一直 2.5G up；全量 journal 第一次出现。重启后 eth0/eth1 恢复 2.5G up 无新 WATCHDOG，但 EEE 仍 enabled。

### 嫌疑点

1. **EEE 关闭未真正落到链路层**：`disable-eee.service` 在设备出现后、链路 up 前执行成功，链路协商后驱动重新开启 EEE。RTL8125B PHY 固件存在 EEE 低功耗唤醒失败导致的载波丢失记录。
2. **PCIe ASPM L1 开着**：两个 RTL8125 `LnkCtl` 均 `ASPM L1 Enabled`；NUR r8125 源码默认 `CONFIG_ASPM=y`、`ENABLE_EEE=y`，当前 derivation 未覆盖。OpenWrt 官方用 `CONFIG_ASPM=n`。

### 处理

- 即时缓解：`ethtool --set-eee eth0/eth1 eee off`（驱动 reset 后可能恢复）。
- 已按方案 B 准备回滚 r8169，后改为重新启用 vendor r8125 的 RSS/多队列构建并**编译期关闭 ASPM/EEE**（见 §3）。若再出现 WATCHDOG 则永久回滚 r8169。
- 未完成：「重启变关机」事故未定位；WATCHDOG 前瞬时流量/中断数据未取到。

## 3. RSS 千兆恢复（2026-08-12）

### 结论

- 根因不是「PPPoE 没有加速」：flowtable 一直在卸载 NAT 流；主要瓶颈是 NUR r8125 默认关闭 RSS/多 TX 队列，且 qBittorrent 运行态残留 10MB/s 全局下载限速。
- 启用 `9.018.00-NAPI-DASH-RSS` + 编译关闭 ASPM/EEE + 解除 qBittorrent 限速后，Mac 四源聚合实测 121-155MB/s，qBittorrent ppp0 约 109MB/s、写盘约 98MB/s，恢复千兆线速。
- 当前无 NETDEV WATCHDOG；RSS 实际启用 2 个 RX 队列（驱动预置最大 8），运行期 `ethtool -L` 不能扩到 8。

### 改动

- `nixos/hardware/nanopi-r5c/default.nix`：r8125 打开 `ENABLE_RSS_SUPPORT=y`、`ENABLE_MULTIPLE_TX_QUEUE=y`，编译关闭 `CONFIG_ASPM`/`ENABLE_EEE`，blacklist r8169。
- `hosts/router/performance.nix`：RPS/XPS 覆盖全部队列，流深 8192/队列，`rps_sock_flow_entries=16384`、`flow_limit_table_len=8192`、`netdev_budget=600`、`budget_usecs=20000`、`optmem_max=131072`。
- `hosts/router/qbittorrent.nix`：启动清除 `Session\GlobalDLSpeedLimit` 写回 0。
- `hosts/router/networking.nix`：EEE off 改非致命。

### 实测对照

| 场景 | 修复前 | 修复后 |
| --- | ---: | ---: |
| router 本机 USTC 单连接 | 32.7 MB/s | 38.6 MB/s |
| Mac 经 router USTC 单连接 | 40.8 MB/s | 56.1 MB/s |
| Mac 四源 10s 聚合 | ~100 MB/s | 121-155 MB/s |
| qBittorrent 下载 | 10MB/s 限速 | ppp0 109 / 写盘 98 MB/s |

## 4. RX 队列根因与 4 队列（2026-08-12）

### 根因

- 实机 `ethtool -l`：RX 2 / TX 2（上限 RX 8 / TX 2）；`ethtool -L eth0 rx 4` 报 `Operation not supported`。
- r8125 驱动调用 `netif_get_num_default_rss_queues()`，Linux 6.18 在物理核数 >2 时只返回核数的一半（4 核 → 2）；驱动无 `set_channels`，运行期无法扩队列。
- 改法：驱动源码中替换为 `num_online_cpus()`，编译后 RX 4 队列；TX 仍是驱动硬上限 2。
- 4 队列解决并发流并行度，不改变单条 TCP 流的串行上限。

### 改动

- `nixos/hardware/nanopi-r5c/default.nix`：r8125 `postPatch` 增加 `sed -i 's/netif_get_num_default_rss_queues()/num_online_cpus()/' src/r8125_n.c`。
- `hosts/router/performance.nix`：`rps_sock_flow_entries` 16384→65536、`flow_limit_table_len` 8192→16384（4 队列 × 8192 流深）；关 irqbalance，`router-rps` 把 eth0/eth1 queue 0-3 中断钉到 CPU 0-3；`netdev_budget` 600→1200、`budget_usecs` 20000→30000；每分钟重断言 qdisc/亲和/RPS/XPS（防 r8125 驱动重置后静默退化）。
- `hosts/router/qbittorrent.nix`：`AsyncIOThreadsCount=4`、`DiskCacheSize=256`、`DiskCacheTTL=60`（限制 4 核 IO）；服务显式依赖 `var-lib.mount`。
- `hosts/router/flowtable.nix`：只卸载 WAN 流量（`iifname "ppp0"` 与 `iifname "br-lan" oifname "ppp0"`），跳过 hairpin；自愈脚本只维护带 `router-flowtable` 注释的规则。
- `hosts/router/host.nix`：`hostname = "192.168.0.1"`，让 Colmena 直接派生目标，避免 LTNET/ZeroTier 路径触发 sshd per-source 惩罚。

### 实机验收（2026-08-12）

- router 代际 58；`ethtool -l` RX 4 / TX 2，RSS 覆盖 queue 0-3，`rps_cpus=f`、`rps_flow_cnt=8192`。
- NAPI budget A/B：`600/20000`：808386 包、461 Mbit/s、rx_missed 1338；`1200/30000`：918840 包、529 Mbit/s、rx_missed 0。
- iperf hairpin P4 reverse：亲和修正后 1.40 Gbit/s/重传 284（修正前 1.32/10059）。
- qBittorrent IO 参数生效后负载 9-13 → 约 4.6。
- 2.5G 端点复测：OPI5P 直连 P16 2.37 Gbit/s；经 router hairpin NAT 多流约 2.28-2.31 Gbit/s。
- flowtable 丢包 A/B（P16，5 轮中位）：无 flowtable 2.255 Gbit/s/重传 79973；精简 WAN-only（已落地）2.293/51041；全量 2.252/84084。重传主要由 OPI5P 发送端感知的 hairpin 乱序引起，非 router 丢包（测试期 CPU 91% 空闲、rx_missed +451）。
- fq_codel A/B：`mq`+`pfifo_fast` 2.293/51041 → `mq`+每队列 `fq_codel`（已落地）2.326/23269（重传 -54%）。
- `ethtool -l eth0/eth1`：RX 4 / TX 2。

### 官方参考与剩余未落地项

- 官方：Kernel nf_flowtable 文档、nftables wiki Flowtable；Linux 6.18 flowtable 元组按双向输入接口记录（`iifidx`），hairpin 双向从 br-lan 进入，机制上支持跳过 hairpin 的结论。
- 未落地：`cake` 对照、BBRv3/TCP Brutal（out-of-tree 风险高）、Clang/ThinLTO、nft-fullcone（仅 UDP，有安全回归风险）、NAPI `1200/30000` 的 DNS/ICMP 延迟对照、qBittorrent 升级后重新核对 IO 参数。

## 相关文件

- `nixos/hardware/nanopi-r5c/default.nix`、`nixos/hardware/nanopi-r5c/kernel-config`
- `hosts/router/{flowtable,performance,qbittorrent,networking,host}.nix`
- 选型背景：[router-firmware-selection.md](router-firmware-selection.md)
