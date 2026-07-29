# NanoPi R5C 内核与系统闭包裁剪审计

本文只讨论正式 `router` 的体积、构建负担和安全裁剪边界。启动、刷写和硬件验收
见 [`nanopi-r5c.md`](./nanopi-r5c.md)。

## 当前结论

2026-07-29 真机系统闭包约为 **2.0 GiB**，包含约 964 个 requisites。该体积对
NixOS 路由器偏大，但当前没有证据表明它会造成运行故障。最值得继续优化的是
R5C 静态内核配置，而不是删除作者的 nixpkgs 补丁或随意移除路由服务。

当前 `kernel-config` 约 236 KiB：

| 类型 | 数量 |
| --- | ---: |
| 内建 `=y` | 2094 |
| 模块 `=m` | 712 |
| 明确禁用 | 4198 |

它源自通用 Rockchip/ARM64 基线，仍启用了大量非 R5C 硬件族，不能视为已经完成的
最小内核。

## 补丁不是主要问题

`patches/nixpkgs/` 的 10 个补丁与作者仓库逐文件一致。R5C 硬件目录本身没有维护
额外的 Linux 板级 `.patch` 堆栈；主要差异是：

- 静态 `kernel-config`；
- R5C U-Boot defconfig；
- 目标 DTB 筛选；
- 精简固件 derivation；
- SD image 分区与 Rockchip 引导载荷；
- RTC、LED 和本板文件系统设置。

因此删除 nixpkgs 补丁既不能显著减小 R5C closure，也会制造不必要的上游偏离。

## 已实施且应保留的裁剪

### 精简固件

系统只保留 MT7921/MT7961 Wi-Fi、MT7921 蓝牙和 RTL8125 所需固件，不引入完整约
800 MiB 的 `linux-firmware`。这是目前收益最大、风险可控的裁剪。

### 单板 DTB

`hardware.deviceTree.filter` 只复制 `rk3568-nanopi-r5c.dtb`，避免把所有 ARM64
平台 DTB 放入 `/boot`。

### 精简 initrd

`boot.initrd.availableKernelModules` 强制为空，不继承通用 SD image 的 NVMe、USB
存储和虚拟机模块。R5C 只需在 initrd 中挂载本地 Btrfs `/nix`。

### 限制启动代数

256 MiB FAT `/boot` 只保留两个 extlinux generation，避免多个约 61 MiB kernel
和约 24 MiB initrd 填满分区，同时仍保留一个可回退版本。

### 真实交叉编译

在 x86_64 `ml-builder` 上，内核使用 `pkgsCross.aarch64-multiplatform` 编译，
编译器原生运行并输出 AArch64 对象，不通过 QEMU 执行 ARM64 GCC。它主要减少构建
时间和内存压力，不直接改变运行时 closure。

## 不能裁掉的内核能力

下列能力已被真机或公共模块依赖，不能因为模块“看起来没加载”而删除：

| 能力 | 原因 |
| --- | --- |
| MMC、Btrfs、VFAT、ext4 | 启动介质、`/nix` 与 `/boot` |
| RK3568 pinctrl、clock、regulator、PCIe | 板级启动和外设枚举 |
| r8169、RTL8125 firmware | 双 2.5 GbE 和 PPPoE WAN |
| MT7921e、MediaTek Wi-Fi firmware | hostapd AP |
| Bluetooth、btusb、BT_MTK | MT7921 蓝牙 |
| nftables、bridge、VLAN、PPPoE、conntrack | 路由器数据面 |
| MPTCP | 公共 `mptcpd` 服务 |
| ZRAM、Zstd | 公共 `zramSwap`，缺失会产生 90 秒启动超时 |
| BPF、BTF、debug info BTF | DAE |
| NETDEV LED trigger | LAN、WAN、WLAN 状态灯 |
| RTC RK808/HYM8563、I²C | 断网启动时钟恢复 |
| USB serial CP210x、FTDI、WWAN/option | GPS 和可能的外接串口设备 |

蓝牙 BNEP 是例外：当前只需要 BLE/GATT、配对及 central/peripheral 角色，不使用
蓝牙 PAN。缺少 BNEP 会产生一条 BlueZ 警告，但不应仅为消除日志而启用。

## 仍有裁剪潜力的区域

静态配置仍包含约 274 个宽泛的网络、无线、显示、媒体和声音相关选项。优先审计：

1. 除 Realtek 之外的大量 PCI/服务器网卡厂商；
2. 除 MediaTek 之外的无线网卡厂商；
3. Nouveau 和与无头路由器无关的 DRM 驱动；
4. 摄像头、视频采集和完整 Media 子系统；
5. SoundWire 及无实际设备对应的音频驱动；
6. 与 RK3568/R5C 不相关的 SoC、开发板和存储控制器。

不能根据一次 `lsmod` 直接删除：内建驱动不会出现在 `lsmod`，部分驱动只在冷启动、
插入 USB 设备、建立 PPPoE 或加载 eBPF 时使用。

## 用户空间闭包

`minimal.nix` 会导入 Home Manager，并为 `root` 和 `zhyi` 生成非客户端环境，包括
git、htop、jq 和 Home Manager 自身。这在闭包中较显眼，但与作者结构一致；为了
复刻上游，不应只对 router 创建特殊删除规则。

router 相比作者 `lt-home-router` 增加了 DAE、Wi-Fi 和 Prometheus 指标，同时没有
引入作者的 lancache 与 ncps 服务端。应用层没有证据表明本 fork 比作者配置显著
更重。`nmea-static-gps-server`、`ncps-client`、miniupnpd 和 CoreDNS 也均来自作者
路由器结构。

## 后续裁剪方法

每轮只处理一个驱动族，并保留上一个可启动 generation：

1. 冷启动后保存 `lsmod`、`lspci -k`、`lsusb -t`、`dmesg` 和
   `/sys/kernel/debug/devices_deferred`；
2. 对照 R5C DTS、PCI/USB modalias 和当前服务的内核需求；
3. 修改一组 Kconfig，使用交叉工具链重新构建；
4. 验证冷启动、两张网卡、PPPoE、Wi-Fi、蓝牙、DAE、MPTCP、ZRAM、LED 和 RTC；
5. 比较 kernel、modules、initrd、`/boot` 与系统 closure 的实际尺寸；
6. 确认稳定后才开始下一组。

建议记录命令：

```bash
systemd-analyze
systemd-analyze critical-chain
systemctl --failed --no-pager

lsmod
lspci -nnk
lsusb -t
zramctl
bluetoothctl show

du -sh /boot
nix path-info -Sh /run/current-system
nix path-info -s $(nix-store -qR /run/current-system) | sort -k2 -n | tail -50
```

这里的目标是减少无关模块和构建时间，不是追求最小数字。任何导致冷启动、路由
数据面或回退能力下降的裁剪，都不应进入正式 `router`。
