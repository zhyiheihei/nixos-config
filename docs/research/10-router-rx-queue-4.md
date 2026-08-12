# 根因：r8125 只有 2 个 RX 队列，改为 4 个

> 日期：2026-08-12。对象：家庭核心 router（NanoPi R5C / RK3568 / r8125
> 9.018.00-NAPI-DASH-RSS / nftables flowtable）。

## 结论

- 实机 `ethtool -l` 显示 eth0/eth1 都是 RX 2 / TX 2，RX 上限 8、TX 上限 2；
  `ethtool -L eth0 rx 4` 报 `Operation not supported`。
- 根因是 r8125 驱动调用内核
  `netif_get_num_default_rss_queues()`，Linux 6.18 该函数在物理核数大于 2 时
  只返回核数的一半；RK3568 4 核因此得到 2。驱动没有注册 `set_channels`，
  所以运行期 `ethtool -L` 无法扩队列。
- 已把驱动源码中的调用替换为 `num_online_cpus()`，R5C 编译后得到 4 个 RX
  队列；TX 仍是驱动硬上限 2。
- 4 个 RX 队列解决的是并发流并行度，不改变单条 TCP 流的串行处理上限，因此
  多源聚合仍然是单流受限场景下的必要手段。

## 实测与源码证据

- router 实机（改动前）：`eth0/eth1` RX 2 / TX 2，RX 最大 8、TX 最大 2；
  `ethtool -L` 返回 `netlink error: Operation not supported`；RSS 表只在
  queue 0/1 之间轮转。
- r8125 `src/r8125_n.c`：
  `tp->num_rx_rings = min(tp->HwSuppNumRxQueues, netif_get_num_default_rss_queues());`
- Linux 6.18 `net/core/dev.c`：
  `return count > 2 ? DIV_ROUND_UP(count, 2) : count;`
- r8125 ethtool ops 只有 `get_channels`，没有 `set_channels`。

## 改动

- `nixos/hardware/nanopi-r5c/default.nix`：r8125 `postPatch` 增加
  `sed -i 's/netif_get_num_default_rss_queues()/num_online_cpus()/' src/r8125_n.c`。
- `hosts/router/performance.nix`：
  `net.core.rps_sock_flow_entries` 16384 → 32768，
  `net.core.flow_limit_table_len` 8192 → 16384，匹配 4 队列 × 8192 流深；
  关闭 irqbalance，`router-rps` 把 eth0/eth1 的 queue 0-3 中断钉到 CPU 0-3；
  `net.core.netdev_budget` 600 → 1200、`budget_usecs` 20000 → 30000。
- `hosts/router/qbittorrent.nix`：`Session\AsyncIOThreadsCount=4`、
  `Session\DiskCacheSize=256`、`Session\DiskCacheTTL=60`，限制 4 核 router 上
  的 torrent IO 资源占用。
- `hosts/router/flowtable.nix`：flowtable 前向规则改为只卸载 WAN 流量
  （`iifname "ppp0"` 与 `iifname "br-lan" oifname != "br-lan"`），跳过
  br-lan → br-lan hairpin；自愈脚本改为管理多条 flow-add 规则。
- `hosts/router/performance.nix`：新增 `router-qdisc` 服务，把 eth0 根 qdisc
  设为 `fq_codel`，降低 LAN 出口 TCP 乱序/重传。
- `hosts/router/configuration.nix`：Colmena 目标改为
  `192.168.0.1:2222`（`mkForce` 覆盖公共模块的 `router.zhyi.cc`），避免
  LTNET/ZeroTier 路径触发 sshd per-source 惩罚导致 apply 反复断连。

## 实机验收（2026-08-12）

- router 当前代际 58；`ethtool -l eth0/eth1` 均为 RX 4 / TX 2，RSS 表覆盖
  queue 0-3，四个 `rx-*` 的 `rps_cpus=f`、`rps_flow_cnt=8192`。
- 关闭 irqbalance 后 queue 中断亲和为 `0,1,2,3`；此前 irqbalance 把它排成
  `0,3,3,3`，是 rx_missed/多流重传的主要来源之一。
- NAPI budget A/B（qBittorrent 负载下，20 秒 WAN 采样）：
  `600/20000`：808386 包、461 Mbit/s、rx_missed 1338；
  `1200/30000`：918840 包、529 Mbit/s、rx_missed 0。
- iperf hairpin P4 reverse：亲和修正后 1.40 Gbit/s、重传 284；修正前
  1.32 Gbit/s、重传 10059。
- qBittorrent IO 参数生效后系统负载从 9-13 降到约 4.6；WAN 20 秒仍 0 missed。
- 单连接仍受源站/ISP 与单核路径限制，4 队列与 IRQ 亲和提升的是并发流吞吐，
  多源聚合仍是单流受限场景下的必要手段。

## 2.5G 端点复测（OPI5P）

- router `eth0/eth1` 与 OPI5P `lan0` 均协商为 2500Mb/s；ml-builder 只有 1G
  网卡，因此此前用 ml-builder 的测量不能代表 router 上限。
- OPI5P 直连 router：P1 单流 2.32 Gbit/s，P4 2.34 Gbit/s，P8 2.35 Gbit/s，
  P16 2.37 Gbit/s；反向 P8/P16 约 2.33-2.36 Gbit/s。已接近 2.5G 的 TCP
  线速上限（约 2.35-2.40 Gbit/s）。
- OPI5P 经 router hairpin NAT 转发：P1 约 1.99 Gbit/s，P8 2.31 Gbit/s，
  P16 2.28 Gbit/s；多流下重传较多，但聚合吞吐仍接近 2.3G。

## flowtable 丢包 A/B（OPI5P hairpin P16，20 秒）

- 以下为 5 轮（每轮 10 秒）中位数：
  - 无 flowtable：2.255 Gbit/s，sender 重传 79973。
  - 精简 WAN-only flowtable（已落地）：2.293 Gbit/s，重传 51041。
  - 全量 flowtable：2.252 Gbit/s，重传 84084。
- 单次探索（不作为结论）：XPS 收拢 95084 重传；NAPI `2000/40000` 145785，
  均差于当前设置。
- 测试期间 router CPU 约 91% 空闲、eth0 `rx_missed` 仅增加约 451；重传
  主要由 OPI5P 发送端感知的 hairpin 乱序引起，不是 router 网卡大量丢包。

## fq_codel qdisc A/B（OPI5P hairpin P16，5 轮中位数）

- `mq` + `pfifo_fast`（原配置）：2.293 Gbit/s，sender 重传 51041。
- `fq_codel`（已落地）：2.326 Gbit/s，sender 重传 23269。
- 结论：`fq_codel` 在吞吐略升的同时把重传中位数再降约 54%，是当前最有效的
  单变量改进；内核未启用 `fq`，`fq_codel`/`cake` 为内建可用项。

## 官方参考

- Kernel：<https://docs.kernel.org/networking/nf_flowtable.html>
- nftables wiki Flowtable：<https://wiki.nftables.org/wiki-nftables/index.php/Flowtables>
- Linux 6.18 `net/netfilter/nf_flow_table_core.c`：flowtable 元组按双向输入
  接口记录（`iifidx`），hairpin 双向都从 br-lan 进入，与官方“devices 需覆盖
  双向”的模型冲突，机制上支持跳过 hairpin 的结论。

## 剩余可尝试项（未落地）

- `cake`：内核已内建，可作为 `fq_codel` 的进一步对照；本次未做多轮对比。
- BBRv3 / TCP Brutal：只作用于本机 socket，不改变转发流量路径；对
  hairpin 转发重传帮助有限，且都是 out-of-tree 补丁，风险高。
- Clang / ThinLTO：当前 hairpin 测试 router CPU 约 91% 空闲，不是丢包瓶颈；
  收益应集中在 CPU 饱和的 NAT/WAN 场景。
- nft-fullcone：仅支持 UDP，且调研文档记录有安全回归风险。
- SFE / BCM fullcone：调研结论明确不建议复刻。

## 验收预期

- `ethtool -l eth0/eth1`：RX 4 / TX 2。
- `ethtool -x eth0/eth1`：indirection table 覆盖 queue 0-3。
- `/proc/interrupts`：eth0/eth1 的 queue 0-3 中断随流量增长。
- `sysctl net.core.rps_sock_flow_entries`：32768；四个 `rx-*` 的
  `rps_cpus=f`、`rps_flow_cnt=8192`。
- iperf 多连接对照：并发吞吐应不低于 2 队列基线；单连接仍受源站/ISP 与单核
  路径限制，不以 4 队列作为单流线速的依据。

## 相关文件

- `nixos/hardware/nanopi-r5c/default.nix`
- `hosts/router/performance.nix`
- `hosts/router/qbittorrent.nix`
- `docs/research/09-router-rss-gigabit-success-case.md`
