# LubanCat-1（非 V2）NixOS 适配

本页记录原版 EmbedFire LubanCat-1 的 NixOS 适配与实机验收。目标实机为 RK3566、
2 GiB RAM，未焊接 eMMC；系统和 bootloader 均位于 SD 卡。设备当前使用项目既有
`server` 角色，承担低内存常驻服务，但不参与 Nix 远程构建。LubanCat-1 V2、
LubanCat-1N 和 LubanCat-2 不是本文目标，不能直接复用本模块。

## 当前启动契约

| 层级 | 当前选择 |
| --- | --- |
| SoC | RK3566，aarch64-linux |
| Linux | Nixpkgs Linux 6.18，以已验证的 RK356x 手工配置为基线，叠加本机 RTL8822CE 与 zram 配置，使用主线 `rk3566-lubancat-1.dtb` |
| U-Boot | 主线 `generic-rk3568_defconfig`，RK3566/RK3568 TPL + BL31 |
| 串口 | `ttyS2`，1500000-8-N-1，MMIO `0xfe660000` |
| 网络 | 板载 GMAC/RTL8211F，固定 `192.168.0.65/24`，LTNET `198.18.0.124/24` |
| 磁盘 | FAT32 `/boot`、Btrfs `/nix`、tmpfs `/` |
| Mini PCIe | RTL8822CE Wi-Fi；同卡 USB 功能为 RTL8822CU Bluetooth |
| 角色 | `server` + `low-ram` + `lan-access`；不含 `nix-builder` |

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
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
nix build \
  '.#nixosConfigurations.lubancat1.config.system.build.sdImage' \
  --out-link result-lubancat1 \
  --print-build-logs \
  --option max-jobs 1 \
  --option cores 8 \
  --option substituters \
  'http://192.168.0.62:13851 https://attic.zhyi.xin/lantian https://cache.nixos.org'
```

镜像位于：

```bash
ls -lh result-lubancat1/sd-image/
```

内核以 `nanopi-r5c/kernel-config` 作为 RK356x 启动基线。该配置保留 RK3566
所需的时钟、pinctrl、电源域、RK809、SD/MMC、DesignWare GMAC、USB、LED 和串口，
同时避免编译通用 ARM64 配置中的 Radeon、AMDGPU、Tegra、ATM、XFS 和 joystick
等无关驱动。模块在构建时以纯文本派生 LubanCat 专属 config，额外启用
`RTW88_8822CE` 和 zram zstd backend，不直接改动或复制 R5C 的完整 config。

固件闭包同样按实机裁剪，只复制：

```text
rtw88/rtw8822c_fw.bin
rtw88/rtw8822c_wow_fw.bin
rtl_bt/rtl8822cu_fw.bin
rtl_bt/rtl8822cu_config.bin（上游存在时）
```

内核 derivation 在 x86_64 ml-builder 上交叉编译；不要把 LubanCat-1 加入
`nix-builder` 标签。ml-builder 曾在高并发编译时出现宿主内核页状态损坏，因此
首次构建固定为一个 derivation、八个编译线程。

### 动态 kernel config 与 modules 输出

R5C 直接把仓库内的 `kernel-config` Nix path 传给 `linuxManualConfig`，Nixpkgs 会
解析其中的 `CONFIG_MODULES=y`。LubanCat-1 则以 R5C 配置为基线动态替换无线和 zram
选项，`builtins.toFile` 返回的是 store-path 字符串，不满足 Nixpkgs 自动解析配置的
类型检查。如果只传 `configfile`，kernel 虽会按文本完成编译，但 Nix derivation 会
被误判为没有模块，只创建 `out` 而不创建 `modules`，随后出现：

```text
modules-shrunk/lib: No such file or directory
Can not derive a closure of kernel modules because no modules were provided.
```

此时 kernel 本身可能已经编译成功，但名为 modules 的聚合目录里只有 `Image`、
`dtbs` 和 `System.map`，没有 `lib/modules`。给 initrd 随意增加 `zram` 或无线模块
不能解决该输出建模错误。当前模块会用与 Nixpkgs 相同的规则解析动态配置中的 `y/m`
选项，并把结果显式传给 `linuxManualConfig`，确保生成真正的 `modules` 输出。

不要再为此 kernel 额外增加调度 `overrideAttrs`。Nixpkgs kernel 本身要求
`big-parallel`，而本仓库只有 ml-builder 宣告该 feature，已足以保证大型交叉内核
不会调度到 pve-5700u 或 opi5p。

initrd 日志中的 `Couldn't satisfy dependency libcrypto.so.4`、`libbpf.so.0` 是
`make-initrd-ng` 扫描未选入 initrd 的 systemd 辅助程序时产生的警告；只要随后没有
缺失 store 路径或构建退出，它们不是本次失败根因。

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

2026-08-02 首启及 server 角色切换已完成，实机身份和网络参数为：

```text
LAN              192.168.0.65/24（eth0，静态）
LTNET            198.18.0.124/24
ZeroTier node ID fde3beab16
SSH              root@lubancat1.zhyi.cc:2222
```

持久 SSH host 公钥已写入 `hosts/lubancat1/host.nix`，并作为 SOPS age identity 的
权威来源。主机已有独立 WireGuard 私钥密文
`per-host/wg-priv/lubancat1.yaml`；对应公钥登记在 secrets 仓库的
`wg-pubkey.nix`。完成全库 rekey 和控制器授权后，主机已退出 `manualDeploy` 阶段，
参与常规 Colmena 部署。

## 首启实机验收记录

2026-08-02 使用 32 GiB SD 卡验证：

- SPL、U-Boot、extlinux、Linux earlycon 和普通 `ttyS2` 控制台均正常；
- RK3566、2 GiB LPDDR4X、CPU 408 MHz～1.8 GHz 调频正常；
- 板载 GMAC 以 1000 Mbps/full duplex 建链，访问家庭网关无丢包；
- 主线 PCIe 成功枚举 RTL8822CE，USB 成功枚举其 RTL8822CU Bluetooth 功能；
- Wi-Fi 可扫描到周边 BSS，Bluetooth 服务正常启动；未配置无线接入时保持 Wi-Fi
  接口关闭，避免无意义耗电；
- tmpfs `/`、FAT32 `/boot` 和 `neededForBoot` 的 Btrfs `/nix` 挂载正常；
- 初始 3.5 GiB Btrfs 分区已在线扩展到整张卡，约 29.5 GiB；
- `lubancat1-grow-nix.service` 会在以后重新刷写镜像时自动完成同一扩容流程。

板上没有电池供电的 RTC，完全断电后固件会回到 2017 年。硬件模块因此只为本机增加
软件时钟持久化：每小时及关机时把 epoch 写入
`/nix/persistent/var/lib/lubancat1-clock/epoch`，下次启动在 `ntpd-rs` 前恢复。
冷断电复测后，日志从开机第一阶段即使用正确的 2026 时间；网络时间服务仍负责随后
校准。该处理沿用项目内 OPI5P/ROCK5C 的板级写法，没有修改公共时间模块。

首启时 SOPS 和 node-exporter 的失败均属于身份尚未注册的连带结果：前者需要把新
host recipient 写入 secrets 并全库 rekey，后者等待 ZeroTier 控制器分配 LTNET
地址。现已完成全库 rekey 和 colocrossing 控制器的声明式部署；设备已取得
`198.18.0.124`，并通过 `sops-install-secrets -check-mode sopsfile` 实机验证新密文
可由持久化 SSH host key 解密。切换新系统代际后仍须重新检查 `systemctl --failed`，
不能把首启失败状态保留下来。

## Server 角色与资源预算

服务链路、资源快照和迁移批次见
[`服务链路与 LubanCat-1 迁移审计`](../infrastructure/service-chain-lubancat-audit.md)。
该审计只批准把低写入轻服务作为后续独立批次迁入；本页记录的当前 server 基线不代表
这些应用已经切换。

主机直接导入作者已有的 `nixos/server.nix`，没有复制或裁剪公共 server 模块。
`host.nix` 只增加角色标签、Asia-E 区域和家庭 NAT 主机沿用的 hostdare、colocrossing、
google WSS peer。WireGuard/BIRD、CoreDNS、Nginx、Yggdrasil、Prometheus exporters、
rsync 等服务均来自作者的公共模块。它不带 `nix-builder` 标签，Hydra 和分布式 Nix
不会向这块 2 GiB 板卡派发大包。

对端部署后，LubanCat-1 到 colocrossing 的 `wgmesh120` 握手正常，双方 BIRD peer
均为 `Established`，`198.18.120.1` 经该接口可达。此前因缺少直连路由失败的
`rsync-nix-sync-servers.service` 已重新执行成功，并完成 Nginx reload；最终
`systemctl --failed` 为 0，systemd 状态为 `running`。

切换后实测内存约 453 MiB 已用、约 1.5 GiB 可用，984 MiB zram 尚未使用。主要常驻
服务的 cgroup 内存量级为：Yggdrasil 约 32 MiB、Nginx 约 30 MiB、node-exporter
约 17 MiB、CoreDNS 约 14 MiB、ZeroTier 约 10 MiB、BIRD 约 2 MiB。这个基线可用于
后续迁入轻量服务；新增服务后应重新记录 idle 内存和 zram 使用，避免把数据库或大型
构建任务迁入本机。

从 `minimal` 在线切到 `server` 时，ZeroTier 的 `allowManaged` 策略改变可能让
Colmena 使用的 LTNET SSH 在激活中自断。首次切换应保留 LAN 管理路径，必要时执行
`networkctl reload` 和 `networkctl reconfigure zttalxbxtu`；稳定后的常规部署仍走
项目统一的 2222 端口。此现象不需要修改作者的公共 networking 模块。

冷启动耗时约 19.8 秒。以下日志目前属于已知非致命项，不应为了消除文字警告继续膨胀
内核或公共模块：未焊 eMMC 的初始化失败、未使用 DWC3/PCIe 控制器的 probe 警告，
以及与 R5C 相同的 BlueZ BNEP/default system config 提示。node-exporter 偶尔会在
ZeroTier 地址出现前失败一次，既有 Restart 策略会在约 0.4 秒后恢复。

## 暂不验收的功能

- 模拟耳机接口：当前主线板级 DTS 只明确启用了 HDMI 音频；
- MIPI 摄像头、DSI 和 NPU：不属于最小首启范围；
- GPU/VPU 应用服务：基础启动稳定后再单独验收，不引入 RK3588 专用模块。
