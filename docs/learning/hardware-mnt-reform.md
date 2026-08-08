# hardware-mnt-reform 学习笔记

## 1. 是什么

`hardware-mnt-reform` 是 MNT Reform 笔记本（i.MX8MQ / Nitrogen8M
SOM，aarch64）的 NixOS 适配仓库，维护者 jollheef，24 star，无明确
license。产出：

- 可启动的 NixOS SD 镜像（`#sdImage`）；
- NVMe 安装指南（LUKS 或明文 + extlinux boot）；
- 定制内核（MNT patch 版 linux 5.18 + 板级 dts）；
- U-Boot（`#ubootReformImx8mq`，flash.bin 写进
  `mmcblk0boot0`）；
- 固件：键盘（AVR/DFU）、主板 LPC 固件（按板级 D2..R3）。

## 2. NixOS module

`nixosModule` 直接给主机配置：

- `boot.kernelPackages` 默认 reform 内核；initrd 加
  `nwl-dsi` / `imx-dcss`，`extraModprobeConfig` 关 HDMI；
- `kernelParams = [ "console=ttymxc0,115200" "console=tty1" "pci=nomsi" ]`；
- extlinux 引导（grub 关闭）、device tree
  `imx8mq-mnt-reform2.dtb`；
- PulseAudio 默认 48kHz、首次启动灌 `initial-asound.state`、
  fstrim、systemd `DefaultTimeoutStopSec=15s`、sway 只留
  swaylock/swayidle/xwayland（unbloat）。

## 3. 内核 / U-Boot / 固件

- `kernel/default.nix`：基于 nixpkgs `linux_5_18`，源码用 MNT
  reform-debian-packages 的 git checkout；自动收集 `patches/` 目录
  全部补丁；用 IFD（`allowImportFromDerivation`）把 MNT 的
  kernel-config 转成 extraConfig；把 `imx8mq-mnt-reform2*.dts`
  拷进 freescale 目录并补 Makefile；`LOADADDR=0x40480000`；
- `uboot/default.nix`：`buildUBoot` +
  `nitrogen8m_som_4g_defconfig`，只装 `flash.bin`，带
  `env_vars.patch`；
- `firmware.nix`：LPC 固件用 `pkgsCross.arm-embedded` 按板级编译，
  键盘固件用 `pkgsCross.avr` + dfu-programmer，wrap 成
  `reform2-keyboard-fw` 命令（erase → flash → start）。

## 4. CI：ARM64 自托管 runner + 缓存预填充

- `image.yml`：push/PR 在 ARM64 runner 上 `nix build` 整镜像，
  master 上传 artifact（README 用 nightly.link 提供下载）；
- `kernel.yml`：每小时预构建 kernel + initialRamdisk 推
  nix-community cachix，并用 `--override-input nixpkgs` 分别对
  release-21.11 / nixos-21.11 / release-22.05 / nixos-unstable 各
  建一遍，保证不同 nixpkgs 安装都有缓存。

## 5. 对我们仓库的启发

- 我们没有 MNT Reform，不引入；
- “板级内核 + U-Boot + 固件 + 镜像 + 安装文档”是 ARM 板卡适配
  仓库的标准五件套；以后若支持 SBC（如树莓派外的板卡）可参考；
- 每小时用多分支 override 预填二进制缓存，能让“用户装旧 nixpkgs
  也能命中缓存”，这个策略对我们 ml-builder 的缓存运营有借鉴
  意义。

## 6. 参考

- [hardware-mnt-reform](https://github.com/nix-community/hardware-mnt-reform)
- [MNT Reform](https://mntre.com/reform.html)
