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
  `net.core.flow_limit_table_len` 8192 → 16384，匹配 4 队列 × 8192 流深。
- 提交：`d5392b99`；ml-builder 构建 router toplevel 已通过，待部署重启后验收。

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
- `docs/research/09-router-rss-gigabit-success-case.md`
