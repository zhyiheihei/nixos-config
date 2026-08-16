# 调研文档 03：iStoreOS 对 NanoPi R5C 的适配

> 日期：2026-08-10。本文件只覆盖三号对象：iStoreOS（https://github.com/istoreos/istoreos ，分支 `istoreos-24.10`）。
> 调研方式：并行子代理深挖源码、补丁、固件发布目录与第三方适配；所有结论均带来源。

## 结论

1. iStoreOS 官方不单独发布 R5C 镜像：R5C 与 R5S 共用同一份 `r5s` 固件；源码里独立 `friendlyarm_nanopi-r5c` 设备被注释，但 `legacy.mk` 的 R5S/R5C combined 设备包含 R5C DTS。
2. 官方 24.10 R5S/R5C 构建使用 Realtek vendor 驱动 `kmod-r8125`（9.016.01），不是主线 `kmod-r8169`；官方 `config.buildinfo` 中 `CONFIG_PACKAGE_kmod-r8125=y`，未发现 `kmod-r8169`。
3. 官方没有用 SFE/Shortcut-FE。默认走 `firewall4` + `nftables` + `kmod-nft-offload`，即内核 nf_flow_table/nft_flow_offload；未发现默认开启流卸载的证据。
4. iStoreOS 源码里保留两套加速补丁：legacy iptables 的 `xt_FLOWOFFLOAD`，以及 BCM fullcone；官方 24.10 构建配置里没有启用 `kmod-ipt-offload`，fullcone 也未发现默认开启。
5. 对 NixOS 最有价值的可复刻项是 nftables flowtable、BBR、主线路 r8169；vendor r8125 可打包，但会与 r8169 争设备，不一定优于主线路驱动。

## 官方源码事实

- 分支 `istoreos-24.10` 存在，官方 24.10 镜像对应此分支。
- [armv8.mk](https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/rockchip/image/armv8.mk)：
  - R5C 定义存在：`DEVICE_PACKAGES := kmod-r8169 kmod-rtw88-8822ce rtl8822ce-firmware wpad-basic-mbedtls`。
  - R5C 被注释：`# TARGET_DEVICES += friendlyarm_nanopi-r5c`。
  - R5S 启用：`TARGET_DEVICES += friendlyarm_nanopi-r5s`。
  - 对比 OpenWrt 官方 `openwrt-24.10`：官方上游启用 R5C，iStoreOS 是刻意注释。
- [legacy.mk](https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/rockchip/image/legacy.mk)：`friendlyarm_nanopi-r5s` 实为 “R5S/R5C combined”，`DEVICE_DTS` 含 `rk3568-nanopi-r5s`、`rk3568-nanopi-r5c`、`rk3568-nanopi-r5s-lts`、`rk3568-nanopi-r5s-c1`。
- [rk3568-nanopi-r5c.dts](https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/rockchip/dts/rk3568/rk3568-nanopi-r5c.dts)：wrapper，`#include <rockchip/rk3568-nanopi-r5c.dts>` 并引入 `rk3568-ip.dtsi`、`rk3568-ip-rk809.dtsi`、`rk3568-ramoops.dtsi`；R5S wrapper 另有 PWM 风扇和 gmac reset。
- 内核版本：`include/kernel-6.6` 为 `6.6.144`，与 OpenWrt `openwrt-24.10` 相同。

## 内核配置事实

- [iStoreOS armv8 config-6.6](https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/rockchip/armv8/config-6.6)：没有显式 `NF_FLOW_TABLE`、`NFT_FLOW_OFFLOAD`、`TCP_CONG_BBR`、`R8169`、`R8125`；`# CONFIG_CRYPTO_DEV_ROCKCHIP is not set`，`CONFIG_NET_SWITCHDEV=y`。
- [generic config-6.6](https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/generic/config-6.6)：`# CONFIG_NF_FLOW_TABLE is not set`、`# CONFIG_NFT_FLOW_OFFLOAD is not set`、`# CONFIG_R8169 is not set`、`# CONFIG_TCP_CONG_BBR is not set`。
- 与 OpenWrt 官方 `openwrt-24.10` 对应选项值相同，说明这些不是 iStoreOS 特改。
- `kmod-nft-offload` 包定义会通过 `CONFIG_NF_FLOW_TABLE_INET`、`CONFIG_NFT_FLOW_OFFLOAD` 把模块带进镜像；`include/target.mk` 的 router 默认包包含 `firewall4 nftables kmod-nft-offload`。仓库默认防火墙配置未设置 `flow_offloading`，未找到默认开启流卸载的证据。

## r8125 / flow offload 补丁细节

- [r8125 Makefile](https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/package/kernel/r8125/Makefile)：`PKG_VERSION=9.016.01`、`PKG_RELEASE=2`、`PROVIDES:=kmod-r8169`、`AUTOLOAD:=$(call AutoLoad,35,r8125)`、rockchip/x86 走 `modules-pending.d`。OpenWrt 官方同文件是 `PKG_RELEASE=1`、`AutoProbe,r8125,1`，且官方没有这批 patch。
- `100-add-LED-configuration-from-OF.patch`：给 vendor 驱动加 `LEDSEL_0_8125`、`LEDFEATURE_8125` 等寄存器，并读取 DT 的 `realtek,led-data`、`realtek,led-feature` 配置 LED。
- `102-rework-2_5G-on-8162.patch`：把 `pdev->device == 0x8162` 改成 `pdev->subsystem_vendor == 0x8162`，使这类芯片走 2.5G 的 CFG_METHOD 分支。
- `110-detail-kernel-warning.patch`：把 `WARN_ON_ONCE` 改成带消息的 `WARN_ONCE`，覆盖 MDIO OCP 读写和 PHY resume 超时。
- `200-r8125-print-link-speed-and-duplex-mode.patch`：链路 up 时打印 `2500/FULL` 这类速度/双工信息。
- [650-netfilter-add-xt_FLOWOFFLOAD-target.patch](https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/generic/hack-6.6/650-netfilter-add-xt_FLOWOFFLOAD-target.patch)：新增 `xt_FLOWOFFLOAD` 内核 target，支持 `--hw`，并解除 `NF_FLOW_TABLE` 对 `NF_TABLES` 的依赖。
- [800-flowoffload_target.patch](https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/package/network/utils/iptables/patches/800-flowoffload_target.patch)：给 iptables 用户态加 `-j FLOWOFFLOAD --hw`。这是 legacy iptables 路径，官方 24.10 构建未启用 `kmod-ipt-offload`。

## 固件发布与第三方适配

- [fw.koolcenter.com/iStoreOS](https://fw.koolcenter.com/iStoreOS/) 根目录有 `r5s/`，没有 `r5c/`。
- [r5s 目录](https://fw.koolcenter.com/iStoreOS/r5s/) 发布 `istoreos-24.10.8-2026073111-r5s-squashfs.img.gz` 等镜像；README 明确写 “R5S 跟 R5C 共用一个固件，支持 R5S、R5C、R5S-LTS、R5S-C1”。
- [安装文档](https://doc.istoreos.com/zh/guide/istoreos/install_r5s.html) 标题为 “NanoPi R5S/R5C 安装教程”，下载入口 `devicename=r5s`，注明 R5C 只能刷 2023052616 之后的版本。
- [官方 r5s config.buildinfo](https://fw.koolcenter.com/iStoreOS/r5s/config.buildinfo)：`CONFIG_PACKAGE_kmod-r8125=y`、`kmod-r8126=y`、`kmod-r8168=y`；没有 `kmod-r8169`，没有 SFE/fullcone 相关包配置。
- [xiaomeng9597/iStoreOS-RK35XX](https://github.com/xiaomeng9597/iStoreOS-RK35XX)：旧 `rk35xx` 分支方案，`.config` 启用 `kmod-ipt-offload`、`kmod-nf-flow`、`iptables-zz-legacy`、`xtables-legacy`，禁用 `iptables-nft`，即 legacy iptables 流卸载路径，未发现 SFE。
- [Kwonelee/iStoreOS-Actions](https://github.com/Kwonelee/iStoreOS-Actions)：README 把 NanoPi-R5C 列在 rk3568 支持表；`arm64/build24.sh` 同时加入 `firewall4`、`kmod-nf-flow`、`kmod-nft-offload`、`kmod-r8125`、`kmod-r8169` 等；`files/etc/uci-defaults/99-custom.sh` 对 `friendlyarm,nanopi-r5c` 做 `WAN=eth1, LAN=eth0` 映射。未发现 flow_offloading/fullcone/SFE 配置。

## 可复刻到 NixOS 的清单

- nftables flowtable：NixOS 主线路内核直接支持 `nf_flow_table`、`nf_flow_table_inet`、`nft_flow_offload`，无需 iStoreOS 补丁；写 flowtable + `flow add` 规则即可。
- BBR：内核开启 `TCP_CONG_BBR` 或使用 sysctl，与 iStoreOS 无关。
- 主线路 r8169：NixOS 6.18 已使用，RTL8125 基本可用；若遇到 R5C LED/2.5G 怪癖，可把 iStoreOS 的 4 个 r8125 patch 复刻成 NixOS kernel module 包，但需和 r8169 互斥。
- fullcone/xt_FLOWOFFLOAD：属于非上游补丁，NixOS nftables 下不建议照搬；未发现 iStoreOS 默认启用它们的证据。

## 风险 / 不确定点

- 官方源码为何注释独立 R5C，未找到提交说明，未核实。
- `config.buildinfo` 证明官方构建选了 r8125，但没有解包官方镜像确认实际加载的模块，运行态证据未核实。
- 官方默认是否在 UCI 配置中开启 `flow_offloading`，未找到直接证据，结论是“未见默认开启”。
- SFE/Shortcut-FE 在官方与两个第三方仓库中均未找到证据，但不能排除固件运行后被用户自行安装。
- Kwonelee 同时装 `kmod-r8125` 和 `kmod-r8169`，存在驱动争用风险，未做运行验证。

## 来源 URL

- https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/rockchip/image/armv8.mk
- https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/rockchip/image/legacy.mk
- https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/rockchip/dts/rk3568/rk3568-nanopi-r5c.dts
- https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/rockchip/armv8/config-6.6
- https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/generic/config-6.6
- https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/package/kernel/r8125/Makefile
- https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/target/linux/generic/hack-6.6/650-netfilter-add-xt_FLOWOFFLOAD-target.patch
- https://raw.githubusercontent.com/istoreos/istoreos/istoreos-24.10/package/network/utils/iptables/patches/800-flowoffload_target.patch
- https://fw.koolcenter.com/iStoreOS/
- https://fw.koolcenter.com/iStoreOS/r5s/
- https://fw.koolcenter.com/iStoreOS/r5s/README.md
- https://fw.koolcenter.com/iStoreOS/r5s/config.buildinfo
- https://doc.istoreos.com/zh/guide/istoreos/install_r5s.html
- https://github.com/xiaomeng9597/iStoreOS-RK35XX
- https://github.com/Kwonelee/iStoreOS-Actions
- https://raw.githubusercontent.com/Kwonelee/iStoreOS-Actions/main/arm64/build24.sh
- https://raw.githubusercontent.com/Kwonelee/iStoreOS-Actions/main/files/etc/uci-defaults/99-custom.sh

