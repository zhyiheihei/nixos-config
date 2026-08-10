# 调研文档 01：OpenWrt 对 NanoPi R5C 的专项适配与高速 NAT 方案

> 日期：2026-08-10。本文件只覆盖一号对象：OpenWrt NanoPi R5C（RK3568）。
> 调研方式：并行子代理深挖官方源码、issue、论坛与 fork；所有结论均带来源。

## 结论

1. OpenWrt `main` 与 `24.10` 已官方支持 R5C/R5S，默认网卡包是 `kmod-r8169`；`23.05` 分支没有 R5C/R5S 设备定义。R5C DTS 直接用 Linux 主线 `rk3568-nanopi-r5c.dts`，OpenWrt 不需要额外 patch。
2. OpenWrt 默认内核配置并不开启 `NF_FLOW_TABLE`、`NFT_FLOW_OFFLOAD`、`TCP_CONG_BBR`、`R8169`；这些由 `kmod-nft-offload`、`kmod-tcp-bbr`、`kmod-r8169` 等包通过 KCONFIG 动态打开。R5C 官方镜像默认只有 `kmod-r8169`。
3. OpenWrt issue #22253 实测：官方 OpenWrt 25.12-RC5 反向 iperf3 约 331 Mbit/s，FriendlyWRT 24.10 约 1.38 Gbit/s；自编译加入 `kmod-nft-offload + kmod-r8125 + kmod-tcp-bbr`、irqbalance、RPS、EEE off、增大 sysctl 后达到约 1.73 Gbit/s。维护者明确 RK3568 只有 software offloading，收益是把转发瓶颈从 CPU 移到内存速度。
4. SFE（Shortcut-FE）不在 OpenWrt 官方树中，属于 Qualcomm QSDK 系软件 fast path；LEDE fork 有 `package/qca/shortcut-fe` 并在 RK3568 FastRhino R66S 上构建测试过。FriendlyWrt 请求加入 SFE 的 issue #14 至今未证实采纳。
5. 可移植性整体很高：内核 flowtable 配置、nft 规则、BBR sysctl、RPS/irqbalance、EEE off、vendor r8125 打包都能在 NixOS 复刻。风险集中在 flowtable 绕过 netfilter、PPPoE/vendor 驱动稳定性、R5C PCIe 初始化时序。

## 官方组件清单

### 设备定义

- [main `target/linux/rockchip/image/armv8.mk` L158-164](https://github.com/openwrt/openwrt/blob/main/target/linux/rockchip/image/armv8.mk#L158)：R5C `DEVICE_PACKAGES` 含 `kmod-r8169`、`kmod-rtw88-8822ce` 等；R5S 只含 `kmod-r8169`。
- [24.10 `armv8.mk` L95-109](https://github.com/openwrt/openwrt/blob/openwrt-24.10/target/linux/rockchip/image/armv8.mk#L95) 首次出现 R5C/R5S；[23.05 `armv8.mk`](https://github.com/openwrt/openwrt/blob/openwrt-23.05/target/linux/rockchip/image/armv8.mk) 无 R5C/R5S。
- [Linux v6.18 `rk3568-nanopi-r5c.dts`](https://raw.githubusercontent.com/torvalds/linux/v6.18/arch/arm64/boot/dts/rockchip/rk3568-nanopi-r5c.dts)：`compatible = "friendlyarm,nanopi-r5c", "rockchip,rk3568"`。

### 内核配置

- [main `target/linux/rockchip/armv8/config-6.18`](https://github.com/openwrt/openwrt/blob/main/target/linux/rockchip/armv8/config-6.18)：`# CONFIG_CRYPTO_DEV_ROCKCHIP is not set`、`CONFIG_PCIEASPM_DEFAULT=y`（非 performance）、`CONFIG_RPS=y`、`CONFIG_RFS_ACCEL=y`、`CONFIG_NET_FLOW_LIMIT=y`。
- [generic `config-6.18`](https://github.com/openwrt/openwrt/blob/main/target/linux/generic/config-6.18)：默认 `# CONFIG_NFT_FLOW_OFFLOAD is not set`、`# CONFIG_NF_FLOW_TABLE is not set`、`# CONFIG_TCP_CONG_BBR is not set`、`# CONFIG_R8169 is not set`；[23.05 `config-5.15`](https://github.com/openwrt/openwrt/blob/openwrt-23.05/target/linux/generic/config-5.15) 相同。

### kmod 包（KCONFIG 动态开）

- [netfilter.mk `nf-flow`](https://github.com/openwrt/openwrt/blob/main/package/kernel/linux/modules/netfilter.mk#L208)：`CONFIG_NF_FLOW_TABLE`、`CONFIG_NF_FLOW_TABLE_HW`、`CONFIG_NETFILTER_INGRESS`，打包 `nf_flow_table.ko`。
- [netfilter.mk `nft-offload`](https://github.com/openwrt/openwrt/blob/main/package/kernel/linux/modules/netfilter.mk#L1381)：`CONFIG_NF_FLOW_TABLE_INET` + `CONFIG_NFT_FLOW_OFFLOAD`，打包 `nf_flow_table_inet.ko`、`nft_flow_offload.ko`；23.05 版还会打包 IPv4/IPv6 flowtable 模块。
- [netdevices.mk `kmod-r8169`](https://github.com/openwrt/openwrt/blob/main/package/kernel/linux/modules/netdevices.mk#L1360)：`KCONFIG := CONFIG_R8169`，官方默认网卡包。
- [netsupport.mk `kmod-tcp-bbr`](https://github.com/openwrt/openwrt/blob/main/package/kernel/linux/modules/netsupport.mk#L1051)：`CONFIG_TCP_CONG_BBR`，自带 [sysctl-tcp-bbr.conf](https://raw.githubusercontent.com/openwrt/openwrt/main/package/kernel/linux/files/sysctl-tcp-bbr.conf)，内容即 `net.ipv4.tcp_congestion_control=bbr`。
- [package/kernel/r8125/Makefile](https://github.com/openwrt/openwrt/blob/main/package/kernel/r8125/Makefile)：版本 `9.016.01`，源码来自 [openwrt/rtl8125 releases](https://github.com/openwrt/rtl8125/releases/download/9.016.01)；`CONFIG_ASPM=n`；RSS variant 额外开 `ENABLE_MULTIPLE_TX_QUEUE=y ENABLE_RSS_SUPPORT=y`；模块为 `src/r8125.ko`；23.05 分支也有同版本包。

## 社区实测与方案细节

- [issue #22253 原始对比](https://github.com/openwrt/openwrt/issues/22253)：官方 OpenWrt 25.12-RC5 反向 331 Mbit/s（394 MB、44 retr）；FriendlyWRT 24.10 反向 1.38 Gbit/s（1.60 GB）。
- [自编译调优结果](https://github.com/openwrt/openwrt/issues/22253#issuecomment-3995172424)：加入 `kmod-nft-offload`、`kmod-tcp-bbr`、`kmod-r8125`、`irqbalance`、`ethtool --set-eee eth1 eee off`、`net.core.netdev_max_backlog=5000`、`rmem_max/wmem_max=16777216`、`rps_cpus=f`、`rps_flow_cnt=4096`，达到 SUM 1.73 Gbit/s（sender 2.05 GB）。
- [brada4 评论](https://github.com/openwrt/openwrt/issues/22253#issuecomment-3995635854)：RK3568 只有软件 offload；flowtable 把转发瓶颈从 CPU 转到内存带宽，通常 2-3 倍。
- [brada4 评论](https://github.com/openwrt/openwrt/issues/22253#issuecomment-3998574089)：BBR 只作用于本机 socket，不作用于转发流量；转发 QoS 要用 CAKE/codel 等 qdisc。
- [issue #18098（R5C PPPoE）](https://github.com/openwrt/openwrt/issues/18098)：`kmod-r8169` 下 450-550 Mbit/s，换 `kmod-r8125-rss` 后下载提升到 750-800 Mbit/s，但仍有 RX drop。
- [issue #22110（r8125-rss PPPoE）](https://github.com/openwrt/openwrt/issues/22110)：R6S 上 2.5G PPPoE 反复 link flap，换回主线 `r8169` 解决。
- [issue #17452（R5C WAN 口）](https://github.com/openwrt/openwrt/issues/17452)：`eth1` 启动时偶发 PCIe 初始化失败，属 R5C 已知问题。
- [LEDE `package/qca/shortcut-fe`](https://github.com/coolsnowwolf/lede/blob/master/package/qca/shortcut-fe/shortcut-fe/Makefile)：含 `shortcut-fe.ko`、`shortcut-fe-ipv6.ko`、`shortcut-fe-cm.ko`；[LEDE PR #10074](https://github.com/coolsnowwolf/lede/pull/10074) 说明该 SFE 内核 patch 在 `rk3568/fastrhino_r66s` 上构建测试过。
- [R5C/R5S 论坛主题](https://forum.openwrt.org/t/nanopi-r5c-rockchip-rk3568b2-2-pcie-2-5gbps/148431)：219 楼的 2.5G/PCIe 行为讨论。

## 可复刻到 NixOS 的清单

1. 内核配置（`nixos/hardware/nanopi-r5c/kernel-config`）：
   - `CONFIG_NETFILTER_INGRESS=y`（已有）
   - `CONFIG_NF_FLOW_TABLE=m`
   - `CONFIG_NF_FLOW_TABLE_INET=m`
   - `CONFIG_NFT_FLOW_OFFLOAD=m`
   - `CONFIG_TCP_CONG_BBR=y`
2. nft flowtable 规则（内核文档原文）：
   ```nft
   table inet x {
       flowtable f {
           hook ingress priority 0; devices = { ppp0, br-lan };
       }
       chain y {
           type filter hook forward priority 0; policy accept;
           ip protocol tcp flow add @f
           counter packets 0 bytes 0
       }
   }
   ```
3. sysctl：`net.core.netdev_max_backlog=5000`、`net.core.rmem_max=16777216`、`net.core.wmem_max=16777216`、`net.ipv4.tcp_congestion_control=bbr`。
4. RPS/irqbalance：`rps_cpus=f`、`rps_flow_cnt=4096`（eth0/eth1）；`services.irqbalance.enable = true`。
5. EEE：`ethtool --set-eee <dev> eee off`；本仓库已有 `hosts/router/networking.nix` 的 disable-eee 服务。
6. vendor r8125 打包参考：下载 `r8125-9.016.01.tar.bz2`（哈希见 OpenWrt Makefile），构建传 `CONFIG_ASPM=n`；RSS 变体加 `ENABLE_MULTIPLE_TX_QUEUE=y ENABLE_RSS_SUPPORT=y`，安装 `src/r8125.ko`，网络前加载，与 `r8169` 二选一。

## 风险 / 不确定点

- flowtable 命中后从 ingress 之后直接 `neigh_xmit()`，后续 Netfilter hook、forward 链计数/规则都会绕过；需要按业务保留例外规则。
- 这是软件 fast path，不是硬件卸载；网卡不支持时 “Hardware offload” 标志无意义。
- PPPoE/VLAN 自内核 5.13 起 flowtable 已支持，但社区里 R5C PPPoE + vendor 驱动仍出现过 RX drop 和 link flap。
- vendor r8125 有 ASPM 关停历史（[PR #18509](https://github.com/openwrt/openwrt/pull/18509) 称 ASPM 造成 latency/吞吐异常）以及其他平台的 `NETDEV WATCHDOG` TX timeout 记录；未找到 R5C 专属 TX stall 官方 issue。
- R5C 的 PCIe 初始化时序问题不是驱动性能可解决的，NixOS 硬件配置需要保留排查手段。
- 未找到证据：23.05 存在 R5C/R5S 官方支持；官方或社区存在 R5C/R5S 上 SFE 的具体吞吐数字。

## 来源 URL 列表

- https://github.com/openwrt/openwrt/blob/main/target/linux/rockchip/image/armv8.mk#L158
- https://github.com/openwrt/openwrt/blob/openwrt-24.10/target/linux/rockchip/image/armv8.mk#L95
- https://github.com/openwrt/openwrt/blob/main/target/linux/rockchip/armv8/config-6.18
- https://github.com/openwrt/openwrt/blob/main/target/linux/generic/config-6.18
- https://github.com/openwrt/openwrt/blob/main/package/kernel/linux/modules/netfilter.mk#L208
- https://github.com/openwrt/openwrt/blob/main/package/kernel/linux/modules/netfilter.mk#L1381
- https://github.com/openwrt/openwrt/blob/main/package/kernel/linux/modules/netdevices.mk#L1360
- https://github.com/openwrt/openwrt/blob/main/package/kernel/linux/modules/netsupport.mk#L1051
- https://github.com/openwrt/openwrt/blob/main/package/kernel/r8125/Makefile
- https://github.com/openwrt/openwrt/issues/22253
- https://github.com/openwrt/openwrt/issues/18098
- https://github.com/openwrt/openwrt/issues/22110
- https://github.com/openwrt/openwrt/issues/17452
- https://github.com/openwrt/openwrt/pull/18509
- https://github.com/friendlyarm/Actions-FriendlyWrt/issues/14
- https://github.com/coolsnowwolf/lede/blob/master/package/qca/shortcut-fe/shortcut-fe/Makefile
- https://github.com/coolsnowwolf/lede/pull/10074
- https://docs.kernel.org/networking/nf_flowtable.html
- https://forum.openwrt.org/t/nanopi-r5c-rockchip-rk3568b2-2-pcie-2-5gbps/148431

