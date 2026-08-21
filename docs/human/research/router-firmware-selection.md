# R5C 路由器固件/高速 NAT 选型调研

> 日期：2026-08-10。对象：NanoPi R5C（RK3568）路由器的 OpenWrt / Cooluc / iStoreOS
> 三套固件方案，评估可移植到 NixOS 的加速项。调研方式：并行子代理深挖官方源码、
> issue、论坛与 fork；所有结论均带来源。

## 调研对象与总体结论

| 对象 | 结论 |
| --- | --- |
| OpenWrt 官方 | 已官方支持 R5C/R5S（main 与 24.10，默认 `kmod-r8169`）；默认不开 flowtable/BBR，需 kmod 包动态打开；实测官方 331 Mbit/s → 自编译调优 1.73 Gbit/s。可移植性整体最高 |
| Cooluc（r5s.cooluc.com / sbwml/builder） | "网速特别高"无实测背书；默认用 nftables flowtable 而非 SFE；编译优化真实但 README 有夸大；最值得复刻 flowtable/BBR/irqbalance/RPS，最不值得 SFE/BCM fullcone |
| iStoreOS（istoreos-24.10） | R5C 与 R5S 共用 r5s 固件；官方用 vendor r8125 9.016.01；未见默认流卸载；最有价值的是 flowtable/BBR/主线路 r8169 |

**共性结论**：RK3568 只有 software offloading（brada4 在 OpenWrt issue 确认），
flowtable 把转发瓶颈从 CPU 移到内存带宽，通常 2-3 倍；SFE 属于 Qualcomm 系
侵入式补丁，三个方案均未默认启用；对 NixOS 最值得复刻的是 nftables flowtable、
BBR、RPS/irqbalance、EEE off、vendor r8125 打包。

## OpenWrt（对象 01）

### 官方组件事实

- R5C DTS 直接用 Linux 主线 `rk3568-nanopi-r5c.dts`，OpenWrt 不需要额外 patch。
- 官方默认内核不开启 `NF_FLOW_TABLE`、`NFT_FLOW_OFFLOAD`、`TCP_CONG_BBR`、`R8169`；
  由 kmod 包通过 KCONFIG 动态打开（`kmod-nft-offload`、`kmod-tcp-bbr`、
  `kmod-r8169`）；`CONFIG_PCIEASPM_DEFAULT=y`（非 performance）。
- r8125 包：版本 `9.016.01`（openwrt/rtl8125 releases），`CONFIG_ASPM=n`；
  RSS variant 额外开 `ENABLE_MULTIPLE_TX_QUEUE=y ENABLE_RSS_SUPPORT=y`。

### 社区实测

- issue #22253：官方 25.12-RC5 反向 331 Mbit/s；FriendlyWRT 24.10 1.38 Gbit/s；
  自编译（nft-offload + bbr + r8125 + irqbalance + EEE off + RPS + backlog/rmem 调整）
  达到 SUM 1.73 Gbit/s。
- BBR 只作用于本机 socket，不作用于转发流量（转发 QoS 用 CAKE/codel）。
- issue #18098：r8169 450-550 Mbit/s，换 `kmod-r8125-rss` 后 750-800 Mbit/s。

### 可复刻清单（NixOS）

1. 内核 flowtable 配置（`NF_FLOW_TABLE`/`NFT_FLOW_OFFLOAD`）+ nft `flow add @f`。
2. BBR sysctl（仓库 `networking.nix` 已启用上游 bbr）。
3. RPS/irqbalance、EEE off、vendor r8125 打包。
4. 风险：flowtable 绕过 netfilter、PPPoE/vendor 驱动稳定性、R5C PCIe 初始化时序。

## Cooluc（对象 02）

### 性能主张核实

- 无官方测速/iperf 对照；Issue #38 是 R76S 用户描述（1000M 家宽 IPv6 2000M），非受控测试。
- 默认固件真正启用的是内核 nftables flowtable（`kmod-nf-flow` + `kmod-nft-offload`），不是 SFE（manifest 无 `kmod-shortcut-fe`）。
- 编译优化真实但夸大：Clang/LTO/mold 由 config.buildinfo 证实；O3 实际 rockchip 只有 `-O2`，仅 zstd 明确 O3；ThinLTO 无法独立核实。
- SS AES 加速不是 RK3568 crypto engine（issue #33：RK3576 都说没有）；实际 `cryptodev-linux` + OpenSSL devcrypto/afalg + ARMv8 crypto 指令。

### 构建/补丁细节

- builder 仓库只有 workflow，真逻辑是 `init2.cooluc.com/build.sh`；rockchip target 克隆自私有 `git.cooluc.com/sbwml/target_linux_rockchip-6.x`，无法独立核实。
- 发布含 `kmod-r8125 9.14.01`、`nft-fullcone`、`bbr3`、`brutal`、`cryptodev`、`irqbalance`。
- nft-fullcone 只支持 UDP 全锥；BCM fullcone 改 `nf_nat_masquerade`（issue #71：可能绕过 WAN input REJECT，暴露本机监听服务）。
- BBRv3：20 个 backport 补丁；LRNG 25 个补丁。

### 可复刻清单（NixOS）

1. irqbalance：仓库全局已启用（`cpuThreads > 1`）。
2. RPS/XPS：R5C kernel-config 已含 `CONFIG_RPS/XPS`；缺 udev/systemd 写 `rps_cpus` 的单元，可补。
3. nft-fullcone：包已在 kernel.nix 但构建失败禁用 + R5C 关 out-of-tree，照搬前先解决。
4. flowtable：**最值得做**，R5C kernel-config 当前未开，需改两个 CONFIG。
5. BBRv3/TCP Brutal：非主线补丁，做 kernelPatches 明确登记。
6. Clang/LTO：kernel.nix 已有 `LLVM=1` 的 `llvmOverride` 基础设施。
7. AES：R5C 已开 `CRYPTO_AES_ARM64_CE=y`，OpenSSL 用 ARMv8 ASM 即可，别指望专用硬件引擎。
8. 不建议：SFE（Qualcomm 系）、BCM fullcone（安全风险）。

## iStoreOS（对象 03）

### 官方源码事实

- R5C 与 R5S 共用 r5s 固件；`legacy.mk` 的 R5S 实为 R5S/R5C combined（4 个 DTS）。
- 官方 24.10 用 `kmod-r8125`（9.01.01，`PROVIDES:=kmod-r8169`）+ 4 个 patch（LED 配置、2.5G 修复、警告去噪、链路信息），没有 `kmod-r8169`。
- 官方构建未启用 `kmod-ipt-offload`；`xt_FLOWOFFLOAD` 是 legacy iptables 路径，未发现默认启用证据。
- 第三方 Kwonelee 同时装 r8125+r8169，存在争用风险。

### 可复刻清单

- nftables flowtable：NixOS 主线路内核直接支持，无需补丁。
- BBR：内核开启或 sysctl。
- 主线路 r8169：NixOS 6.18 已使用，RTL8125 基本可用；R5C LED/2.5G 怪癖可复刻 iStoreOS 4 个 r8125 patch，但需与 r8169 互斥。
- fullcone/xt_FLOWOFFLOAD：非上游补丁，nftables 下不建议照搬。

## 综合风险 / 不确定点

- Cooluc 私有源码无法核实；发布产物无内核 `.config`（LTO/SFE 是否模块为推断）。
- 三套方案都未见 SFE 默认启用的证据；sfe/fullcone 均为非主线，升级易失败或行为回归。
- BBR/brutal 只作用本机 socket，对转发帮助有限。
- 不完整项：R5C 当前关闭 out-of-tree `extraModulePackages`，照搬 fullcone 需先解依赖。

## 相关

- 落地后的调优记录见 [router-r5c-tuning.md](router-r5c-tuning.md)。
- 调研原文来源 URL 列表已压缩；需要时可从 git 历史翻看 `01-openwrt-nanopi-r5c.md`、
  `02-r5s-cooluc.md`、`03-istoreos-r5c.md`（已删除）。
