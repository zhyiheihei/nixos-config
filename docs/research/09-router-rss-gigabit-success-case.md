# 成功案例：R5C Router 启用 r8125 RSS 后恢复千兆线速

> 日期：2026-08-12。对象：家庭核心 router（NanoPi R5C / RK3568 / PPPoE + br-lan / nftables flowtable）。

## 结论

- 根因不是“PPPoE 没有加速”：flowtable 一直在卸载 NAT 流；主要瓶颈是 NUR r8125
  默认关闭 RSS/多 TX 队列，且 qBittorrent 运行态残留 10MB/s 全局下载限速。
- 启用 `9.018.00-NAPI-DASH-RSS` 并编译关闭 ASPM/EEE、解除 qBittorrent 限速后，
  Mac 经 router 的 10 秒四源聚合实测 121-155MB/s，qBittorrent 10 秒采样 ppp0
  约 109MB/s、写盘约 98MB/s，已恢复千兆线速。
- 当前无 NETDEV WATCHDOG；RSS 驱动实际启用 2 个 RX 队列（驱动预置最大 8），
  `ethtool -L` 运行期不能扩到 8。

## 改动

- `nixos/hardware/nanopi-r5c/default.nix`：NUR r8125 打开
  `ENABLE_RSS_SUPPORT=y`、`ENABLE_MULTIPLE_TX_QUEUE=y`，编译期关闭
  `CONFIG_ASPM`、`ENABLE_EEE`，加载 r8125 并 blacklist r8169。
- `hosts/router/performance.nix`：RPS/XPS 覆盖全部队列，RPS 流深 8192/队列，
  `rps_sock_flow_entries=16384`、`flow_limit_table_len=8192`、
  `netdev_budget=600`、`netdev_budget_usecs=20000`、`optmem_max=131072`。
- `hosts/router/qbittorrent.nix`：每次启动清除 `Session\GlobalDLSpeedLimit` 并
  写回 0，避免迁移配置继续限速。
- `hosts/router/networking.nix`：EEE off 改为非致命，避免新驱动不支持该操作时
  服务失败。

## 实测对照

| 场景 | 修复前 | 修复后 |
| --- | ---: | ---: |
| router 本机 USTC 单连接 | 32.7 MB/s | 38.6 MB/s |
| Mac 经 router USTC 单连接 | 40.8 MB/s | 56.1 MB/s |
| Mac 经 router 四源 10s 聚合 | ~100 MB/s | 121-155 MB/s |
| router 本机四源 10s 聚合 | 68 MB/s | 105 MB/s |
| qBittorrent 下载 | 被 10MB/s 限速 | ppp0 109 MB/s / 写盘 98 MB/s |

## 剩余观察

- 单连接速度仍受镜像源/ISP 单流限制，波动 38-56MB/s；多连接才稳定接近线速。
- router 本机入站约 105MB/s，低于 NAT 转发路径，属于本地 PPPoE 收包路径剩余瓶颈。
- r8125 RSS 编译变体只能启用 2 个 RX 队列，OpenWrt 的 r8125-rss 同源驱动应对比
  实际队列数；若后续要超过千兆，优先确认驱动源码的队列上限。
