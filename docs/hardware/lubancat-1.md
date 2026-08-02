# LubanCat-1（非 V2）NixOS 适配

本页记录原版 EmbedFire LubanCat-1 的首启配置。目标实机为 RK3566、2 GiB RAM，
未焊接 eMMC；系统和 bootloader 均位于 SD 卡。LubanCat-1 V2、LubanCat-1N 和
LubanCat-2 不是本文目标，不能直接复用本模块。

## 当前启动契约

| 层级 | 当前选择 |
| --- | --- |
| SoC | RK3566，aarch64-linux |
| Linux | Nixpkgs Linux 6.18，使用主线 `rk3566-lubancat-1.dtb` |
| U-Boot | 主线 `generic-rk3568_defconfig`，RK3566/RK3568 TPL + BL31 |
| 串口 | `ttyS2`，1500000-8-N-1，MMIO `0xfe660000` |
| 网络 | 板载 GMAC/RTL8211F，首启 IPv4 DHCP |
| 磁盘 | FAT32 `/boot`、Btrfs `/nix`、tmpfs `/` |

主线 U-Boot 尚未提供 LubanCat-1 专用 defconfig。首版使用
`generic-rk3568_defconfig`，让通用 RK356x SPL 初始化 SD 卡，再由 extlinux 向
Linux 传入精确的 LubanCat-1 DTB。这与厂商 U-Boot 使用通用 EVB 设备树、把板级
差异留给 kernel DTB 的思路一致。

如果串口在 DDR/TPL、SPL 或 MMC 初始化阶段停止，应保留完整日志，不要先改 Linux
参数。回退路线是把官方 LubanCat U-Boot 2017.09 的 `rk3566` 配置封装成 Nix
derivation；不因此回退到厂商 Linux 内核。

## 镜像布局

```text
SD 卡
├── 32 KiB: idbloader.img
├── 8 MiB: u-boot.itb
├── 16 MiB: FAT32 FIRMWARE -> /boot
└── Btrfs NIXOS_NIX -> /nix

运行时
├── /     tmpfs
└── /nix  持久化 Btrfs
```

板上没有 eMMC，因此不存在 eMMC loader 抢在 SD 卡之前启动的问题。不要给当前硬件
增加 SPI 或 eMMC 启动假设。

## 构建

长时间构建在 ml-builder 上执行：

```bash
nix build \
  '.#nixosConfigurations.lubancat1.config.system.build.sdImage' \
  --out-link result-lubancat1 \
  --print-build-logs \
  --option max-jobs 4
```

镜像位于：

```bash
ls -lh result-lubancat1/sd-image/
```

首版使用主线内核的通用配置，内核和 U-Boot derivation 在 x86_64 ml-builder 上
交叉编译；不要把 LubanCat-1 加入 `nix-builder` 标签。

## 首次上电检查

串口参数：

```bash
tio -b 1500000 /dev/cu.usbserial-*
```

预期顺序：

```text
Rockchip DDR/TPL
U-Boot SPL
U-Boot
Scanning mmc ...
Found /extlinux/extlinux.conf
Starting kernel ...
Linux earlycon on 0xfe660000
systemd
```

进入系统后检查：

```bash
systemctl --failed
ip -br address
findmnt / /boot /nix
cat /proc/device-tree/model
cat /sys/class/leds/sys_led/trigger
```

DHCP 获得地址后，通过项目已有授权公钥登录：

```bash
ssh -p 2222 root@ADDRESS
```

首启生成持久 SSH host key 后，再采集公钥写入 `hosts/lubancat1/host.nix`，分配正式
LAN 地址并完成 SOPS rekey。首启验证前保持 `manualDeploy = true`。

## 暂不启用的功能

- Mini PCIe 无线或蜂窝模块：安装具体设备后再加入对应驱动和固件；
- 模拟耳机接口：当前主线板级 DTS 只明确启用了 HDMI 音频；
- MIPI 摄像头、DSI 和 NPU：不属于最小首启范围；
- GPU/VPU 应用服务：基础启动稳定后再单独验收，不引入 RK3588 专用模块。
