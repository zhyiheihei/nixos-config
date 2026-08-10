# 调研文档 02：r5s.cooluc.com / Cooluc（sbwml/builder）方案

> 日期：2026-08-10。本文件只覆盖二号对象：https://r5s.cooluc.com/ 及其发布仓库 https://github.com/sbwml/builder 。
> 调研方式：并行子代理深挖站点、README、workflow、构建脚本、发布产物与 issue；所有结论均带来源。

## 结论

1. Cooluc 固件的“网速特别高”没有实测背书：站点、README、发布页都没有吞吐数字。唯一带数字的反馈是 [Issue #38](https://github.com/sbwml/builder/issues/38)，那是用户描述的 R76S 环境（1000M 家宽、IPv6 最高约 2000M），不是 R5S/R5C 受控对照测试。
2. 默认固件真正启用的是内核 nftables flowtable（`kmod-nf-flow` + `kmod-nft-offload`），不是 SFE。v25.12.5-standard 的 manifest 里没有 `kmod-shortcut-fe`；README 的 “Shortcut-FE 支持 UDP 入站” 更像“可装能力”，不是默认生效。
3. 编译优化是真的，但 README 有夸大：Clang/LLVM、GCC16、mold、LTO/GC-sections 由 [config.buildinfo](https://github.com/sbwml/builder/releases/download/v25.12.5-standard/buildinfo_nanopi-r5s.tar.gz) 证实；所谓 O3 补丁实际把 rockchip 设为 `-O2`，只有 zstd 明确 O3；ThinLTO 因 rockchip target 仓库私有无法独立核实。
4. “SS AES 硬件加速”大概率不是 RK3568 crypto engine：作者在 [Issue #33](https://github.com/sbwml/builder/issues/33) 说 RK3576 hw crypto“目前还没有，作用微乎其微”；Linux 6.18 主线 Rockchip crypto 驱动只支持 RK3288/RK3328/RK3399。固件实际用 `cryptodev-linux` + OpenSSL `devcrypto/afalg` + ARMv8 crypto 指令扩展。
5. NixOS 上最容易复刻的是 flowtable、BBR、irqbalance、RPS/XPS、Clang/LTO 内核与 nft-fullcone；最不值得复刻的是 SFE 和 BCM fullcone 这类侵入式内核补丁。

## 站点与发布信息

- [r5s.cooluc.com](https://r5s.cooluc.com/)：标题 “NanoPi R5S - OpenWrt 固件”，导航含 R4S/R5S/R76S/X86_64、GitHub Releases、dev.cooluc.com OTA。
- [README](https://github.com/sbwml/builder/blob/main/README.md)：R5S/R5C 均挂在 r5s.cooluc.com；Releases 基于 OpenWrt releases 源码 + Linux 6.18 LTS；Snapshots 基于 `openwrt-25.12` 每夜构建；Minimal 为无内置插件版；OTA 通道 `dev.cooluc.com/release|standard|minimal/<model>`。
- 当前发布 `v25.12.5`，内核 [6.18.44](https://init.cooluc.com/tags/kernel-6.18)；[发布资产](https://github.com/sbwml/builder/releases/tag/v25.12.5-standard) 同时包含 `nanopi-r5c` 与 `nanopi-r5s` 的 squashfs/ext4 固件。
- R5S 的 `config.buildinfo` 同时启用 `friendlyarm,nanopi-r5c` 与 `friendlyarm,nanopi-r5s`，OTA JSON 也同时生成 R5C/R5S 条目，见 [build.sh](https://github.com/sbwml/r4s_build_script/blob/master/openwrt/build.sh:629)。

## 构建源码 / 补丁细节

- `builder` 仓库本身只有 README 和 5 个 Actions workflow；真正逻辑是 workflow 里的 `bash <(curl $secrets.script_url_general)`，即 [init2.cooluc.com/build.sh](https://init2.cooluc.com/build.sh)。旧版存档在 [r4s_build_script](https://github.com/sbwml/r4s_build_script)。
- OpenWrt 源码是官方 `openwrt/openwrt` 的 `v25.12.5`/`openwrt-25.12`，不是自定义 fork；rockchip target 克隆自 `git.cooluc.com/sbwml/target_linux_rockchip-6.x`，该仓库不可公开访问（Gitea API 返回 not found），DTS/MSI/内核 config 细节无法独立核实。
- SFE：内核钩子补丁 [953-net-patch-linux-kernel-to-support-shortcut-fe.patch](https://init.cooluc.com/openwrt/patch/kernel-6.18/net/953-net-patch-linux-kernel-to-support-shortcut-fe.patch)，包来自 [git.cooluc.com/sbwml/shortcut-fe](https://git.cooluc.com/sbwml/shortcut-fe)（LEDE 移植）；“UDP 入站”对应 fast-classifier 的 [010-fix-udp.patch](https://git.cooluc.com/sbwml/shortcut-fe/raw/branch/main/fast-classifier/patches/010-fix-udp.patch)。
- Fullcone：`nft-fullcone` 是独立内核模块，README 明确 “Currently only UDP traffic is supported for full-cone NAT”；另一套 BCM fullcone 直接改 `nf_nat_masquerade` / `nft_masq`，补丁在 [982](https://init.cooluc.com/openwrt/patch/kernel-6.18/net/982-add-bcm-fullcone-support.patch) / [983](https://init.cooluc.com/openwrt/patch/kernel-6.18/net/983-add-bcm-fullcone-nft_masq-support.patch)。
- BBRv3：20 个 backport 补丁下载进 `target/linux/generic/backport-6.18`（[01-prepare_base-mainline.sh](https://github.com/sbwml/r4s_build_script/blob/master/openwrt/scripts/01-prepare_base-mainline.sh:87)）；TCP Brutal 来自 `sbwml/package_kernel_tcp-brutal`；LRNG 25 个补丁见同一脚本 111-137 行。
- 编译参数：workflow 设置 `KERNEL_CLANG_LTO=y ENABLE_LTO=y ENABLE_LRNG=y USE_GCC16=y ENABLE_MOLD=y`；产物确认 `CONFIG_KERNEL_CC="ccache clang"`、`CONFIG_USE_LTO=y`、`CONFIG_USE_GC_SECTIONS=y`、`CONFIG_USE_MOLD=y`、`CONFIG_KERNEL_LRNG=y`。
- 发布 manifest 还包含 `kmod-r8125 9.016.01`、`kmod-nft-fullcone`、`kmod-tcp-bbr3`、`kmod-tcp-brutal`、`kmod-cryptodev`、`libopenssl-devcrypto`、`libopenssl-afalg`、`irqbalance`。

## 性能主张核实

- 未找到官方测速、iperf 对照或发布说明里的 Mbps 数字。
- [Issue #38](https://github.com/sbwml/builder/issues/38) 是唯一接近“实测”的资料：R76S 上 RPS/XPS 热插拔未生效、IRQ 绑到小核，手动设 RPS mask 后突发性能明显提升；作者回复 RK3576 是 GICv2，无法改 IRQ affinity。无精确前后对照，且不适用 R5C/R5S。
- [Issue #71](https://github.com/sbwml/builder/issues/71)：fullcone 安全回归，开启后可能绕过 WAN `input REJECT`，暴露本机监听服务。NixOS 复刻需额外防护。

## 可复刻到 NixOS 的清单

1. irqbalance：仓库已全局启用 `services.irqbalance.enable = LT.this.cpuThreads > 1`（[environment.nix](/Users/molishanguang/my-project/nixos/nixos-config/nixos/minimal-components/environment.nix:116)），R5C 多核自动开启，无需额外动作。
2. RPS/XPS：R5C 本地 kernel-config 已含 `CONFIG_RPS=y`、`CONFIG_XPS=y`、`CONFIG_PCI_MSI=y`；仓库没有写 `rps_cpus` 的 udev/systemd 单元。可复刻 Cooluc：按网卡固定 `rps_cpus`（如 `eth0=0x30`、`eth1=0xc0`），用 `systemd.tmpfiles` 或 udev rule。
3. nft-fullcone：包已在 [kernel.nix](/Users/molishanguang/my-project/nixos/nixos-config/nixos/minimal-components/kernel.nix:141)（`pkgs.nur-xddxdd.nft-fullcone`），但自动加载被注释；R5C 的 [nanopi-r5c/default.nix](/Users/molishanguang/my-project/nixos/nixos-config/nixos/hardware/nanopi-r5c/default.nix:116) 用 `extraModulePackages = lib.mkForce [ ]` 关闭 out-of-tree 模块。复刻需要编进 R5C kernelPackages、加载 `nft_fullcone`、nft 规则加 `meta nfproto ipv4 fullcone`。
4. nftables flowtable（最值得做）：R5C kernel-config 当前 `# CONFIG_NF_FLOW_TABLE is not set`（[kernel-config](/Users/molishanguang/my-project/nixos/nixos-config/nixos/hardware/nanopi-r5c/kernel-config:1188)）；需改 `CONFIG_NF_FLOW_TABLE=y`、`CONFIG_NFT_FLOW_OFFLOAD=y`，再在 [firewall.nix](/Users/molishanguang/my-project/nixos/nixos-config/hosts/router/firewall.nix) 加 flowtable 与 `flow add @f`。与现有 masquerade/DNAT 的兼容性、fullcone 同时开时的入站 UDP 行为都要实测。
5. BBR/BBRv3：[networking.nix](/Users/molishanguang/my-project/nixos/nixos-config/nixos/minimal-components/networking.nix:36) 已启用上游 `bbr`；BBRv3 是 20 个 out-of-tree 补丁，可用 `boot.kernelPatches` 应用；TCP Brutal 独立模块。风险和收益需本机 iperf3 验证。
6. Clang/LLVM + ThinLTO：R5C 当前走 `crossPkgs.linuxManualConfig` 的上游 6.18 内核，未确认 ThinLTO；可复刻 Cooluc：LLVM 工具链 + `LLVM=1` + `CONFIG_LTO_CLANG_THIN=y` + 包级 LTO/mold overlay。[kernel.nix](/Users/molishanguang/my-project/nixos/nixos-config/nixos/minimal-components/kernel.nix:47) 已有 `LLVM=1` 的 `llvmOverride` 基础设施。
7. AES：[kernel-config](/Users/molishanguang/my-project/nixos/nixos-config/nixos/hardware/nanopi-r5c/kernel-config:8472) 已开 `CONFIG_CRYPTO_AES_ARM64_CE=y` 与 `CONFIG_CRYPTO_USER_API=m`；主线没有 RK3568 crypto engine 驱动，OpenSSL 用 ARMv8 ASM 即可，不要期待 `/dev/crypto` 调专用硬件引擎。
8. 不建议复刻：SFE（Qualcomm 系内核补丁，默认固件都没装）、BCM fullcone（直接改 `nf_nat_masquerade`，风险高且已出安全 bypass）、DPDK/r8125 PMD。

## 风险 / 不确定点

- `git.cooluc.com/sbwml/target_linux_rockchip-6.x` 私有，PCI-MSI、ThinLTO、R5S 内核 config/DTS 细节无法独立核实。
- 发布产物只有 OpenWrt `config.buildinfo`，没有内核 `.config`；`CONFIG_LTO_CLANG_THIN=y`、SFE 是否编译成模块仍属推断。
- v25.12.5-standard manifest 无 `kmod-shortcut-fe`，但 `CONFIG_ALL_KMODS=y` 时 kmod 仓库可能仍有包；未下载核对，不能断言 SFE 完全不可安装。
- 没有官方吞吐基准；Issue #38 的 1000M/2000M 是用户侧 R76S 描述，不是受控测试。
- `nft-fullcone` 只支持 UDP 全锥；BCM fullcone 补了 TCP 但改 NAT 路径，风险更高。
- 本地 [kernel.nix](/Users/molishanguang/my-project/nixos/nixos-config/nixos/minimal-components/kernel.nix:184) 已注明 `nft_fullcone` 因构建失败暂时禁用，且 R5C 关闭 out-of-tree `extraModulePackages`；直接照搬需先解决这两个问题。
- BBRv3、TCP Brutal、SFE、BCM fullcone 都是非主线补丁，内核升级容易失败或行为回归；NixOS 应做成明确的 kernelPatches/包。

## 来源 URL 列表

- https://r5s.cooluc.com/ 、 https://dev.cooluc.com/ 、 https://snapshot.cooluc.com/ 、 https://init.cooluc.com/tags/kernel-6.18
- https://github.com/sbwml/builder 、 https://github.com/sbwml/builder/blob/main/README.md 、 https://github.com/sbwml/r4s_build_script
- https://github.com/sbwml/builder/tree/main/.github/workflows 、 https://init2.cooluc.com/build.sh
- https://github.com/sbwml/r4s_build_script/blob/master/openwrt/build.sh 、 https://github.com/sbwml/r4s_build_script/blob/master/openwrt/scripts/01-prepare_base-mainline.sh
- https://init.cooluc.com/openwrt/patch/kernel-6.18/net/953-net-patch-linux-kernel-to-support-shortcut-fe.patch
- https://git.cooluc.com/sbwml/shortcut-fe 、 https://git.cooluc.com/sbwml/shortcut-fe/raw/branch/main/fast-classifier/patches/010-fix-udp.patch
- https://git.cooluc.com/sbwml/nft-fullcone 、 https://init.cooluc.com/openwrt/patch/kernel-6.18/net/982-add-bcm-fullcone-support.patch 、 https://init.cooluc.com/openwrt/patch/kernel-6.18/net/983-add-bcm-fullcone-nft_masq-support.patch
- https://init.cooluc.com/openwrt/patch/generic-25.12/0005-kernel-Add-support-for-llvm-clang-compiler.patch 、 https://init.cooluc.com/openwrt/patch/target-modify_for_aarch64_x86_64.patch 、 https://init.cooluc.com/openwrt/generic/config-lto
- https://github.com/sbwml/builder/releases/tag/v25.12.5-standard 、 https://github.com/sbwml/builder/releases/download/v25.12.5-standard/buildinfo_nanopi-r5s.tar.gz
- https://github.com/sbwml/builder/issues/33 、 https://github.com/sbwml/builder/issues/38 、 https://github.com/sbwml/builder/issues/71
- https://github.com/torvalds/linux/blob/v6.18/drivers/crypto/rockchip/rk3288_crypto.c 、 https://github.com/torvalds/linux/blob/v6.18/Documentation/devicetree/bindings/crypto/rockchip,rk3288-crypto.yaml

