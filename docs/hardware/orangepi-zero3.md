# Orange Pi Zero 3（`opi03`）NixOS 适配

本文记录 4 GiB Orange Pi Zero 3 的 SD 启动与 NixOS 基础配置。主机名为 `opi03`。
板卡的第二阶段目标是自制 reDroid 12、Mali GPU 与 Cedar 视频硬解，单独见
[历史归档的 reDroid 记录](../old/orangepi-zero3-redroid.md)。Orange Pi Zero 2、Zero
2W 和其他内存版本不属于本次实机范围。

## 当前启动契约

| 层级 | 当前选择 |
| --- | --- |
| SoC | Allwinner H618，aarch64-linux，4 × Cortex-A53 |
| RAM | 4 GiB LPDDR4 |
| Linux | Orange Pi H618 vendor Linux 5.4.125，由 ml-builder 交叉编译 |
| DTB | `sunxi/sun50i-h616-orangepi-zero3.dtb`（vendor 命名，仍是 Zero 3/H618） |
| U-Boot | Nixpkgs `ubootOrangePiZero3`，`orangepi_zero3_defconfig` |
| 串口 | UART0 / `ttyS0`，115200-8-N-1，无流控，MMIO `0x05000000` |
| 网络 | 板载千兆以太网，首启 DHCP；匹配 `end0` 或 `eth0` |
| 存储 | microSD：FAT32 `/boot`、Btrfs `/nix`、tmpfs `/` |
| 加速器 | Kbase r20 `/dev/mali0`；Cedar/ION/G2D，供自制 reDroid 12 使用 |
| 无线 | 板载 AW859A/uwe5622 整套后置，当前内核不编译半成品驱动 |

U-Boot 继续使用 Nixpkgs `ubootOrangePiZero3`，内核和 DT 则作为一个 Android 12
BSP 支持集切到 Orange Pi vendor 5.4。该源码以板级固定 commit 获取，不增加 flake
input、不修改 `flake.lock`，也不从 Armbian 输出目录复制随机 kernel/DTB。

固定的 vendor 5.4 DTS 仍保留首次导入时的 GMAC `rx-delay = <0>`。Orange Pi 后续
官方 6.1 DTS、Linux 上游稳定性修复和 Zero 3 p3 Android 12 实例都证明该板需要 RX
时序补偿；旧 vendor 驱动又不支持主线的 `rgmii-rxid` binding。因此板级 kernel 包
用一个小型局部补丁采用 p3 的旧 binding 值 `rx-delay = <6>`，并补齐 YT8531
Motorcomm PHY、GPIO LED、红灯到绿灯的启动阶段切换、绿色 heartbeat 和调试日志
环。证据链和保留/舍弃项见
[历史归档的板级差异审计](../old/orangepi-zero3-redroid.md#zero-3-板级差异审计)。

## 镜像布局

Allwinner BROM 从卡头 8 KiB 读取合并后的 SPL/U-Boot：

```text
microSD
├── 8 KiB: u-boot-sunxi-with-spl.bin
├── 16 MiB: FAT32 FIRMWARE -> /boot
└── Btrfs NIXOS_NIX -> /nix

运行时
├── /     tmpfs
└── /nix  持久化 Btrfs（neededForBoot）
```

首版不读写 SPI NOR，也不假定 SPI 中已有 loader。不要套用 RK356x/RK3588 的
32 KiB `idbloader.img`、8 MiB `u-boot.itb` 布局。

## 已封住的历史构建坑

### initrd 不得继承全硬件模块

Nixpkgs 的 `sd-image.nix` 默认启用 `hardware.enableAllHardware`，会给 arm64 initrd
加入 `3w-9xxx`、旧 PATA/SATA、NVMe 和其他无关模块。某个模块未由目标 kernel
提供时，`modules-shrunk` 会在镜像生成前失败。

当前模块显式关闭：

```nix
hardware.enableAllHardware = lib.mkForce false;
boot.initrd.includeDefaultModules = false;
```

不能把这一做法复制到未审计的通用 kernel。本板当前 vendor config 已确认
`MMC_SUNXI=y`、`BTRFS_FS=y`、ext4/VFAT 也内建，因此 initrd 可以强制使用空模块
列表，不会再触发 `modules-shrunk` 去寻找不存在的 x86/SATA 驱动。

```text
available: []
forced:    []
```

公共 kernel 模块会请求 `nullfsvfs`；板级 `mkForce` 会用唯一需要的
`mali_kbase` 替换公共模块列表。不要在这里恢复通用 out-of-tree 模块，它们不属于
H618 vendor kernel ABI。

### 大包和交叉编译的调度边界

- `opi03` 没有 `nix-builder` 标签，不能接收 Hydra 或分布式大包任务；
- U-Boot derivation 在 x86_64 上交叉编译，并要求 `aarch64-cross` feature；
- kernel 与 Kbase 均在 x86_64 上交叉编译，并要求 `aarch64-cross` feature；
- 不在已有 kernel 构建尚未结束时并行启动镜像构建，否则会长时间等待相同 store
  path 的锁，看起来像卡死。

### 无线功能后置

板载 Wi-Fi/蓝牙使用 AW859A/uwe5622 一类厂商栈。当前 vendor kernel 的引入是为
匹配 Mali/Cedar Android 12 ABI，不等于无线已经验收。Armbian 的 Zero 3 配置通过
`uwe5622-allwinner` 扩展同时提供驱动、firmware 和蓝牙 attach helper；只打开 Orange
Pi 内核里的 `WLAN_UWE5622`/`TTY_OVERY_SDIO` 会得到不可用的半套实现，而且该驱动
Makefile 硬编码 `/bin/pwd`，在 Nix sandbox 中会丢失 include path。

因此当前生成器显式关闭 `SPARD_WLAN_SUPPORT` 及整个 uwe5622 子树，不为它增加一个
掩盖用户态缺失的 Nix 专用补丁。后续无线适配必须作为一组引入 Armbian 已验证的
driver、firmware、`hciattach` 与 systemd service，再做实机 SDIO/蓝牙验收。

### vendor 5.4 不支持 MPTCP

该固定 vendor kernel 早于 MPTCP 主线合入。板级模块会删除公共配置中的
`net.mptcp.enabled`，关闭 `mptcpd`，并把 rsync socket 回退到 TCP；否则即使 kernel
编译成功，开机时仍会出现不存在的 sysctl 和失败服务。BBR/FQ 则由板级 kernel
config 保留，与其余公共网络 sysctl 对齐。

## 构建门禁

在构建机仓库没有未提交的新主机文件时，普通 flake 引用即可。开发中的未跟踪文件
只允许临时使用 `path:.#...` 求值，正式长构建前应先提交。

先做短时求值：

```bash
nix eval --raw \
  '.#nixosConfigurations.opi03.config.system.build.sdImage.drvPath'

nix eval --json \
  '.#nixosConfigurations.opi03.config.boot.initrd.availableKernelModules'
nix eval --json \
  '.#nixosConfigurations.opi03.config.boot.initrd.kernelModules'
```

确认构建机没有另一条大内核任务后，再由用户执行长构建：

```bash
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
nix build \
  '.#nixosConfigurations.opi03.config.system.build.sdImage' \
  --out-link result-opi03 \
  --print-build-logs \
  --show-trace \
  --option max-jobs 2 \
  --option cores 8 \
  --option substituters \
  'http://192.168.0.62:13851 https://attic.zhyi.xin/lantian https://cache.nixos.org' \
  --option fallback true
```

镜像输出：

```bash
find -L result-opi03/sd-image -name '*.img.zst' -print
```

## 首次上电

macOS 串口命令：

```bash
ls /dev/cu.usbserial-* /dev/cu.usbmodem-* 2>/dev/null
tio -b 115200 -d 8 -s 1 -p none -f none /dev/cu.usbserial-DEVICE
```

预期启动链：

```text
U-Boot SPL
U-Boot
Scanning mmc ...
Found /extlinux/extlinux.conf
Starting kernel ...
Linux earlycon at 0x05000000
NixOS stage 1 mounts /nix
systemd
```

进入系统后保存以下证据：

```bash
cat /proc/device-tree/model
findmnt / /boot /nix
ip -br link
ip -br address
systemctl is-system-running
systemctl --failed --no-pager
systemctl status opi03-grow-nix.service --no-pager
test -s /nix/persistent/etc/ssh/ssh_host_ed25519_key
```

从 DHCP 地址经项目已有操作者公钥登录：

```bash
ssh -p 2222 root@ADDRESS
```

完成一次断电冷启动后，再记录 SSH host 公钥、ZeroTier node ID 和正式 LAN 地址，
更新 `hosts/opi03/host.nix`、执行 secrets rekey，最后移除 `manualDeploy`。在此之前
不要把设备加入批量部署或构建节点集合。
