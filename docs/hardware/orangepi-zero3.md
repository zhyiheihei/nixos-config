# Orange Pi Zero 3（`opi03`）NixOS 适配

本文记录 4 GiB Orange Pi Zero 3 的首启配置。主机名为 `opi03`，目标是先从
microSD 启动最小 NixOS、通过串口和千兆网口验收，再录入正式 SSH/SOPS/ZeroTier
身份。Orange Pi Zero 2、Zero 2W 和其他内存版本不属于本次实机范围。

## 当前启动契约

| 层级 | 当前选择 |
| --- | --- |
| SoC | Allwinner H618，aarch64-linux，4 × Cortex-A53 |
| RAM | 4 GiB LPDDR4 |
| Linux | Nixpkgs 通用 arm64 Linux 6.18.40，不维护板级 kernel config |
| DTB | `allwinner/sun50i-h618-orangepi-zero3.dtb` |
| U-Boot | Nixpkgs `ubootOrangePiZero3`，`orangepi_zero3_defconfig` |
| 串口 | UART0 / `ttyS0`，115200-8-N-1，无流控，MMIO `0x05000000` |
| 网络 | 板载千兆以太网，首启 DHCP；匹配 `end0` 或 `eth0` |
| 存储 | microSD：FAT32 `/boot`、Btrfs `/nix`、tmpfs `/` |
| 无线 | 板载 AW859A/uwe5622 路线暂缓，首启不引入 vendor kernel |

主线 Linux 已包含 H618 Orange Pi Zero 3 DTS，当前锁定的 Nixpkgs 也已提供专用
U-Boot derivation，因此不需要增加 flake input、修改 `flake.lock`，也不需要从
Armbian 输出目录复制 kernel、DTB 或 bootloader。

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

不能再用 `boot.initrd.availableKernelModules = lib.mkForce [ ];` 作为通用裁剪方案。
本板使用的通用 arm64 kernel 中 `MMC_SUNXI=y`，但 `BTRFS_FS=m`；`/nix` 又标记了
`neededForBoot`。因此必须允许 NixOS 的 Btrfs 模块把 `btrfs` 和校验算法加入 initrd。
最终列表应大致为：

```text
available: autofs, efivarfs, sunxi_mmc, crc32c, xxhash64, sha256, blake2b-256
forced:    btrfs
```

公共 kernel 模块会无条件请求 out-of-tree `nullfsvfs`。本板不构建该模块，只针对
`nullfsvfs` 设置 false，不能连同 `btrfs` 一起强制清空。

### 大包和交叉编译的调度边界

- `opi03` 没有 `nix-builder` 标签，不能接收 Hydra 或分布式大包任务；
- U-Boot derivation 在 x86_64 上交叉编译，并要求 `aarch64-cross` feature；
- kernel 使用可缓存的 Nixpkgs 通用 arm64 包，不为本板触发一次完整内核重编译；
- 不在已有 kernel 构建尚未结束时并行启动镜像构建，否则会长时间等待相同 store
  path 的锁，看起来像卡死。

### 无线功能后置

板载 Wi-Fi/蓝牙使用 AW859A/uwe5622 一类厂商栈，当前主线内核没有可直接宣告为
已验收的完整路线。首启镜像只保证 SD、串口和有线网；取得实机的 `dmesg`、
`lsusb`、`ls /sys/bus/sdio/devices` 后再决定是否增加最小补丁。不要为了先亮无线
直接切换整套 Armbian/vendor kernel。

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
