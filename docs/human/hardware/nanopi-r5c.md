# NanoPi R5C NixOS 镜像适配与安装

本文记录 NanoPi R5C（Rockchip RK3568）在本仓库中的适配、构建和刷写流程。目标布局
遵循作者物理主机的约定，而不是使用普通的持久化 ext4 根目录：

- tmpfs `/`
- FAT32 `/boot`，卷标 `FIRMWARE`
- Btrfs `/nix`，卷标 `NIXOS_NIX`
- 持久化目录 `/nix/persistent`

真机刷卡、USB-TTL 接线和完整串口日志采集步骤见第 8 节；内核、固件和系统闭包
的体积审计及后续裁剪边界见第 9 节。其他 ARM64 开发板应从
[`arm-board-bring-up.md`](arm-board-bring-up.md) 的通用流程开始，不要直接复制
本板的串口地址、U-Boot 偏移或 DTB 名称。

硬件适配位于 [`nixos/hardware/nanopi-r5c/`](../../../nixos/hardware/nanopi-r5c)，
并由 [`hosts/router/`](../../../hosts/router) 直接使用；R5C 就是正式的 `router`
主机，不再维护额外的 `nanopi-r5c` 主机定义。

## 1. 当前构建环境

当前正式镜像只需要 NixOS ARM64 构建机：

| 机器 | 系统 | 用途 |
| --- | --- | --- |
| `root@192.168.0.50:2222` | NixOS `ml-builder` | 求值并构建最终 NixOS SD 镜像 |

早期曾使用 `zhyi@192.168.0.60` 的 Ubuntu 环境运行 Armbian build framework，
用于确认 R5C 的 DTS、U-Boot defconfig、固件版本和硬件行为。该机器和
`armbian-build` 工作树现在都不是 NixOS 镜像的输入。

配置仓库以 Git 远端为唯一同步基准。修改必须先在本地提交并 push，再由构建机
pull；不要用 `rsync` 覆盖构建机的正式工作树。

```bash
# 本地
git push

# ml-builder
cd ~/Documents/nixos/nixos-config
git pull --ff-only
```

## 2. 历史 Armbian 硬件验证

本节是适配证据和故障对照，不是当前构建步骤。删除 Ubuntu 上的 Armbian 工作树
不会影响 `nixosConfigurations.router` 的求值或构建。

Armbian 的板级配置为：

```text
config/boards/nanopi-r5c.csc
```

Ubuntu 构建机上的工作目录：

```text
/home/zhyi/armbian-build
```

DTB 构建命令：

```bash
cd ~/armbian-build

./compile.sh kernel-dtb \
  BOARD=nanopi-r5c \
  BRANCH=current \
  RELEASE=bookworm \
  BUILD_DESKTOP=no \
  KERNEL_CONFIGURE=no
```

U-Boot 构建命令：

```bash
./compile.sh uboot \
  BOARD=nanopi-r5c \
  BRANCH=current \
  RELEASE=bookworm \
  BUILD_DESKTOP=no \
  REGIONAL_MIRROR=china
```

已验证的关键输入：

```text
Linux DTS:
  arch/arm64/boot/dts/rockchip/rk3568-nanopi-r5c.dts

U-Boot defconfig:
  configs/nanopi-r5c-rk3568_defconfig

RKBin DDR:
  rk35/rk3568_ddr_1560MHz_v1.21.bin

RKBin BL31:
  rk35/rk3568_bl31_v1.44.elf
```

已生成并核对的 Armbian 产物：

| 产物 | SHA-256 |
| --- | --- |
| `rockchip-rk3568-nanopi-r5c.dtb--6.18-current.dtb` | `df82927ae52c5315d54b8e227e3f0a61edd66e2f53de09cccc2658c8a073e2cd` |
| Linux image Debian 包 | `a081b5179db428dc5e93346960e3e16e3affe05be5a32a0d349bcf9561f0994d` |
| `idbloader.img` | `c48c4ee25c144a09feb6d3096e7176eb0568329e929787b18fd32263512ab4ce` |
| `u-boot.itb` | `ca46e9f419dc27b1721c5c5a80338fc563aa84140ad3899ef267f66c6118fb5f` |

DTB 的 compatible 包含：

```text
friendlyarm,nanopi-r5c
rockchip,rk3568
```

Armbian 内核配置已确认包含 Rockchip、MMC、PCIe、DWMAC/STMMAC、RTL8125、ext4、
Btrfs 和串口支持。

这些 Armbian 产物用于确认硬件支持和提供故障回退依据。当前 NixOS 镜像不直接
复制 Armbian 的 Debian 包，而是使用 Nixpkgs 的 Linux 6.18、R5C DTS 和 U-Boot
源码完成可复现构建。

当前依赖边界如下：

| 组件 | 当前来源 | 是否依赖 Armbian |
| --- | --- | --- |
| Linux kernel | `pkgs.linux_6_18` | 否 |
| R5C DTB | Linux 6.18 源码中的上游 DTS | 否 |
| U-Boot | `pkgs.ubootNanoPiR5S` 覆盖 R5C defconfig | 否 |
| DDR/BL31 等固件 | Nixpkgs U-Boot derivation 声明的输入 | 否 |
| 分区与文件系统镜像 | 本仓库 Nix 模块 | 否 |

仓库配置中没有 Armbian flake input、绝对路径或构建产物引用。Armbian 只在本文的
历史命令和哈希记录中出现。

## 3. NixOS 配置设计

### 内核

不要直接设置：

```nix
boot.kernelPackages = pkgs.linuxPackages_6_18;
```

这会绕过作者在 `nixos/minimal-components/kernel.nix` 中的
`myKernelPackageFor`，导致 `nft-fullcone`、`nullfsvfs` 等自定义内核模块属性
消失。R5C 保留作者的 `lantian.kernel` 接口，但内核 derivation 使用
`linuxManualConfig` 和本板的已解析配置；在 x86_64 构建机上则使用真实的 AArch64
交叉工具链，避免通过 QEMU 执行整套 ARM64 编译器：

```nix
lantian.kernel = lib.mkForce r5cKernel;
```

设备树选择：

```nix
hardware.deviceTree = {
  name = "rockchip/rk3568-nanopi-r5c.dtb";
  filter = "rk3568-nanopi-r5c.dtb";
};
```

`name` 选择 extlinux 启动使用的 DTB，`filter` 则沿用作者 `lt-rpi4` 的做法，限制
镜像只复制目标板 DTB，避免把全部 ARM64 平台的一千多个 DTB 放入 `/boot`。

### U-Boot

R5C 暂时复用 Nixpkgs 的 NanoPi R5S U-Boot derivation，并替换 defconfig：

```nix
pkgs.ubootNanoPiR5S.override {
  defconfig = "nanopi-r5c-rk3568_defconfig";
}
```

Rockchip 引导文件写入整盘镜像的固定偏移：

| 文件 | `dd seek` | 字节偏移 |
| --- | ---: | ---: |
| `idbloader.img` | 64 | 32 KiB |
| `u-boot.itb` | 16384 | 8 MiB |

镜像第一分区从 16 MiB 开始，避免覆盖两个引导载荷。`FIRMWARE` 分区固定为
256 MiB；当前约 61 MiB 的 kernel Image 和 24 MiB 的 initrd 无法放入 Nixpkgs
默认的 30 MiB firmware 分区。

当前 Nixpkgs SD image 模块假设 extlinux 位于第 2 分区，因此默认把第 2 分区
标记为 MBR bootable。R5C 镜像将 extlinux 放在第 1 个 FAT 分区，必须在
`postBuildCommands` 中执行：

```bash
sfdisk --activate "$img" 1
```

否则 U-Boot 的 distro boot 可能只扫描第 2 分区而找不到 extlinux，表现为引导灯
正常但系统没有 DHCP 或 SSH。

### 文件系统

最终镜像包含：

```text
整盘镜像
├── Rockchip idbloader，32 KiB
├── U-Boot ITB，8 MiB
├── FIRMWARE，FAT32，挂载到 /boot
└── NIXOS_NIX，Btrfs，挂载到 /nix
```

运行时 `/` 为 tmpfs。系统 closure 直接位于 Btrfs 分区的 `store/`，挂载后对应
`/nix/store/`。`/nix` 必须设置：

```nix
fileSystems."/nix".neededForBoot = true;
```

通用 SD image 的 `expandOnBoot` 通过 `/` 推导待扩容分区，与 tmpfs `/` 不兼容，
因此 R5C 将其禁用。首次启动验收成功后，应明确扩展第 2 分区，再执行
`btrfs filesystem resize max /nix`。

### 早期串口诊断

R5C 的调试串口使用 3.3 V TTL、1500000 baud。若 U-Boot 已读取 kernel、initrd
和 R5C DTB，但在 `Starting kernel ...` 后立即重新出现 DDR training，则设备在
Linux 注册普通 console 之前发生了硬复位。配置保留以下参数以捕获内核入口阶段
的日志：

```text
earlycon=uart8250,mmio32,0xfe660000
console=ttyS2,1500000n8
console=tty0
```

`uart8250` 的 `earlycon` 参数不能在 MMIO 地址后追加 `,1500000`。追加后 U-Boot
仍会显示 `Starting kernel ...`，但内核串口输出不可见，容易误判为内核卡死。

R5C 还必须导入 `nixos/hardware/disable-watchdog.nix`。公共 minimal 配置默认启用
20 秒运行时硬件 watchdog；该 watchdog 在此板上会造成系统完成启动、网卡建立
链路后约 20 秒无日志硬复位。

2026-07-27 的受控 A/B 测试保持 SD 卡上的 kernel、DTB、initrd、system closure
和清理后的 extlinux 参数完全不变，只替换开头 16 MiB 的 Rockchip 启动载荷。
Nixpkgs U-Boot 2026.04（DDR v1.23、BL31 v1.45）能够正常初始化 MMC、挂载 Btrfs、
进入真实 systemd，并使 RTL8125 网卡以 2.5Gbps 建立链路。因此仓库继续使用
Nixpkgs derivation；此前约 3.16 秒停止并不是 U-Boot 固件差异导致。

R5C 直接导入通用 `sd-image.nix`，不导入 `sd-image-aarch64.nix`。后者会追加面向
Tegra/QEMU 的 `ttyS0`、`ttyAMA0`；与 R5C 的 `ttyS2` 并存后，只能依赖
`keep_bootcon` 持续写调试 UART，并可能在并发 printk 时停止进展。生产配置只保留
`ttyS2`，让正式 8250 console 在注册后正常接管 earlycon。

实机枚举出的两个 RTL8125 PCIe 路径分别为 `pci-0001:11:00.0` 和
`pci-0002:21:00.0`，systemd `.link` 规则应使用这两个路径。

### 网卡驱动

R5C 的两个 RTL8125 网口使用 vendor `r8125` 驱动，并编译开启 RSS 与多 TX 队列，
同时关闭 ASPM/EEE，对应 OpenWrt `kmod-r8125-rss` 的高吞吐方案。2026-08-11 曾
因 r8125 TX queue `NETDEV WATCHDOG` 回滚到主线 `r8169`；2026-08-12 复测确认
NUR 默认 r8125 没有 RSS、ASPM/EEE 默认开启，因此改用 RSS 版并编译关闭低功耗
路径后重新启用。驱动默认跟随内核 `netif_get_num_default_rss_queues()`，4 核
RK3568 只得到 2 个 RX 队列；本仓库覆写为 `num_online_cpus()` 以启用 4 个 RX
队列，TX 仍受驱动 2 队列上限约束。若再次复现 WATCHDOG，则按事故记录永久回滚
r8169。

```nix
boot.kernelModules = [ "r8125" ];
```

initrd 不包含通用网卡、NVMe、USB 存储或虚拟机驱动：`/nix` 是本地 Btrfs，
initrd 无需网络即可找到 closure。不要恢复通用 ARM64 SD image 自动加入的驱动，
否则会扩大 initrd，并可能引入与真实板卡无关的模块依赖。

### Wi-Fi、蓝牙与固件

PCIe MT7921 组合卡同时提供 Wi-Fi 和蓝牙。Wi-Fi 由 hostapd 建立 AP 并桥接到
`br-lan`；蓝牙由 NixOS 的 BlueZ 服务管理：

```nix
hardware.bluetooth.enable = true;
```

系统不保留完整约 800 MiB 的 `linux-firmware`，而是在
`nixos/hardware/nanopi-r5c/default.nix` 中只复制：

- MT7921/MT7961 Wi-Fi 所需的六个 MediaTek 固件；
- `BT_RAM_CODE_MT7961_1_2_hdr.bin` 蓝牙固件；
- `rtl_nic/rtl8125b-2.fw`。

Nixpkgs 中的固件可能以 Zstd 压缩形式进入 closure，因此内核必须同时启用
`CONFIG_FW_LOADER_COMPRESS` 和 `CONFIG_FW_LOADER_COMPRESS_ZSTD`。只复制固件但关闭
压缩固件加载，会表现为 `mt7921e` 已加载但 `wlan0` 不出现。

当前蓝牙验收范围为控制器上电、BLE/GATT、central/peripheral 角色和普通配对。
内核没有启用 BNEP，因此 BlueZ 会记录缺少 Bluetooth Network Encapsulation
Protocol 的警告；除非明确需要蓝牙 PAN/网络共享，不应仅为消除该警告增加 BNEP。

### 公共模块要求的内核能力

R5C 的静态内核配置不能只满足启动硬件，还必须覆盖 `minimal.nix` 自动启用的公共
功能：

| 配置 | 使用方 | 缺失表现 |
| --- | --- | --- |
| `CONFIG_MPTCP` | `services.mptcpd`、`net.mptcp.enabled` | `mptcp.service` 退出，Colmena 将激活判为失败 |
| `CONFIG_ZRAM=m` | 公共 hardening 的 `zramSwap` | 等待 `/dev/zram0` 超时，每次启动增加约 90 秒 |
| `CONFIG_DEBUG_INFO_BTF` | DAE eBPF 程序 | DAE 报告当前内核没有 BTF |
| `CONFIG_LEDS_TRIGGER_NETDEV` | 三个绿色状态 LED | sysfs 中没有 `netdev` trigger |

`CONFIG_MPTCP` 是内建布尔项，因此公共模块仍尝试 `modprobe mptcp` 时可能出现一条
找不到模块的警告；只要 `net.mptcp.enabled = 1` 且 `mptcp.service` 为 active，
该警告不影响功能。

### RTC 与时钟

RK3568 没有内置 RTC。R5C 板载 RK808 PMIC RTC（`/dev/rtc0`）和 HYM8563 外置 RTC
（`/dev/rtc1`，有 CR1220 电池接口但未安装电池）。RK808 RTC 靠电容能维持短时间
断电，长时间断电后重置。

时钟恢复机制（`nixos/hardware/nanopi-r5c/default.nix`）：

- `rtc_rk808` 加入 `boot.kernelModules`，确保 RTC 驱动在 `systemd-modules-load`
  阶段加载，远早于 `multi-user.target`。
- `r5c-hwclock-restore` 服务在 `ntpd-rs` 之前执行 `hwclock -s --utc`，从 RTC
  恢复系统时钟。
- `r5c-hwclock-save` 定时器每小时执行 `hwclock -w --utc`，将系统时钟写回 RTC，
  保持 RTC 时间准确。
- `ntpd-rs` 联网后执行精确校时。

### 状态 LED

板载 4 个 GPIO LED：`red:power`、`green:lan`、`green:wan`、`green:wlan`。
`r5c-leds` 服务在 `wlan0` 设备就绪后配置触发器：

- `red:power`：`default-on`（heartbeat 触发器在此板不驱动亮度）
- `green:lan`：netdev 触发器，关联 `eth0`
- `green:wan`：netdev 触发器，关联 `eth1`
- `green:wlan`：netdev 触发器，关联 `wlan0`

RJ45 网口插座本身的 PHY 指示灯由 r8169/RTL8125 硬件在 probe 时初始化，无需
`r5c-leds` 服务配置。

设备 eMMC 中原有的 OpenWrt U-Boot 可能显示 `Model: Easepi RK3568 Board`，并从
SD 卡第 1 分区加载 NixOS。这不代表 Nix 构建的 U-Boot 产物使用了 Easepi
defconfig；应分别通过串口启动来源和 Nix store 中的 U-Boot derivation 判断。

镜像预先创建：

```text
/nix/persistent/etc/machine-id
/nix/persistent/etc/ssh
/nix/var/nix/daemon-socket
/nix/var/nix/profiles/system
/nix/nix-path-registration
```

`machine-id` 在镜像中为空文件，由 systemd 首次启动写入唯一 ID。正式 router 的
SSH host key 和 SOPS 身份从旧 router 迁移，不把私钥嵌入 Nix store 或镜像
derivation。

`/nix` 和 `/nix/persistent` 顶层必须由 `root:root` 持有。若误设为普通用户，
systemd-tmpfiles 会以 `unsafe path transition` 拒绝创建持久化文件，SOPS、SSH
host key 和其他 preservation 项可能随之失败。检查命令：

```bash
stat -c '%U:%G %a %n' /nix /nix/persistent
```

## 4. 求值与构建

先确认分支和提交：

```bash
ssh -p 2222 root@192.168.0.50
cd ~/Documents/nixos/nixos-config

git status --short --branch
git pull --ff-only
```

求值 SD 镜像：

```bash
nix eval \
  .#nixosConfigurations.router.config.system.build.sdImage.drvPath \
  --show-trace
```

提交 `60c9f2b9` 已成功求值得到：

```text
/nix/store/85ak4s247bkimdm3xzq8xh72vq6a0wxg-nixos-image-sd-card-26.11pre-git-aarch64-linux.img.zst.drv
```

正式构建建议放入 tmux。当前正式 host 和输出名均为 `router`：

```bash
tmux new -s r5c-build
cd ~/Documents/nixos/nixos-config

nix build \
  .#nixosConfigurations.router.config.system.build.sdImage \
  --out-link result-router-r5c \
  --print-build-logs \
  --show-trace
```

断线后恢复：

```bash
tmux attach -t r5c-build
```

成功后检查：

```bash
find -L result-router-r5c -maxdepth 3 -type f -printf '%p  %s bytes\n'

IMAGE="$(find -L result-router-r5c/sd-image -type f -name '*.img.zst' -print -quit)"
test -n "$IMAGE"
readlink -f "$IMAGE"
sha256sum "$IMAGE"
```

### 二进制缓存告警

构建过程中可能出现：

```text
unable to download 'http://192.168.0.51:13851/...narinfo': HTTP error 500
the narinfo was purged
```

这表示缓存索引指向的 NAR 已被清理，不等于 derivation 构建失败。当前
`fallback = true`，Nix 会继续查询其他缓存，未命中时在本地编译。只有出现
`builder for ... failed` 或依赖 derivation 失败才视为正式失败。

若缓存节点持续影响构建，可在新一轮构建中临时排除它：

```bash
nix build \
  .#nixosConfigurations.router.config.system.build.sdImage \
  --out-link result-router-r5c \
  --print-build-logs \
  --show-trace \
  --option substituters \
  "https://attic.zhyi.xin/lantian https://cache.nixos.org"
```

## 5. 刷写镜像

连接目标 TF 卡、eMMC 读卡器或其他启动介质后，先确认整盘设备：

```bash
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,FSTYPE,LABEL,MOUNTPOINTS
```

以下操作会覆盖目标设备的全部数据。`TARGET` 必须是整盘，例如 `/dev/sdb`，不能是
`/dev/sdb1`：

```bash
TARGET=/dev/sdb
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,FSTYPE,LABEL,MOUNTPOINTS "$TARGET"
```

人工确认设备后，卸载它已有的分区，再写入：

```bash
umount "${TARGET}"?* 2>/dev/null || true

zstd -dc "$IMAGE" |
  dd of="$TARGET" bs=16M iflag=fullblock status=progress conv=fsync

sync
partprobe "$TARGET"
udevadm settle
lsblk -f "$TARGET"
```

预期看到 `FIRMWARE` 和 `NIXOS_NIX` 两个卷标。

刷写后可以只读挂载检查：

```bash
mkdir -p /mnt/r5c-boot /mnt/r5c-nix
mount -o ro "${TARGET}1" /mnt/r5c-boot
mount -o ro "${TARGET}2" /mnt/r5c-nix

test -f /mnt/r5c-boot/extlinux/extlinux.conf
test -d /mnt/r5c-nix/store
test -f /mnt/r5c-nix/nix-path-registration
test -L /mnt/r5c-nix/var/nix/profiles/system
test -d /mnt/r5c-nix/persistent/etc/ssh

umount /mnt/r5c-boot /mnt/r5c-nix
```

## 6. 启动与验收

当前镜像是正式 `router` 配置，不是带 DHCP 和 `.98/.99` 地址的救援 host。首次
切换前必须先迁移旧 router 的 SSH/SOPS、ZeroTier 和 Kea 状态，并确认 WAN/LAN
物理端口。旧 router 与 R5C 不得同时使用 `192.168.0.1`。

切换后从 LAN 侧通过串口或正式地址登录并检查：

```bash
hostname
uname -a
cat /proc/device-tree/model

findmnt /
findmnt /boot
findmnt /nix

lsblk -f
ip -br link
ip -br address
lspci -nn

systemctl is-system-running
systemctl --failed --no-pager
systemctl status sshd --no-pager
systemctl status mptcp bluetooth hostapd dae --no-pager

sysctl net.mptcp.enabled
zramctl
bluetoothctl show
ip -br link show wlan0

test -s /nix/persistent/etc/ssh/ssh_host_ed25519_key
readlink -f /nix/var/nix/profiles/system

systemd-analyze
systemd-analyze critical-chain
systemd-analyze blame | head -30
```

必须确认：

- `/` 的类型是 tmpfs；
- `/boot` 来自 `FIRMWARE`；
- `/nix` 来自 `NIXOS_NIX`，并启用预期的 Btrfs 选项；
- 至少一个网口取得地址；
- SSH host key 位于持久目录；
- `/nix` 和 `/nix/persistent` 属于 `root:root`；
- `/dev/zram0` 正常建立，不出现 90 秒设备等待；
- MPTCP、DAE、Wi-Fi 和蓝牙服务正常；
- 冷启动后仍能找到 system closure 并正常进入系统。

## 7. 已验证状态与切换前检查

已在真机确认：

- Nixpkgs U-Boot 可从 TF 和 eMMC 读取 extlinux；
- Linux 6.18、R5C DTB、initrd 和真实 systemd 可以启动；
- `/` 为 tmpfs，`/boot` 为 FAT32，`/nix` 为 Btrfs；
- 主线 r8169（此前）/ vendor r8125 RSS 版（2026-08-12 起，已验证部署并开启
  4 个 RX 队列）正常加载，两个 RTL8125 网口以 2.5 Gbps 建立链路；
- `hwclock -s --utc` 在 `rtc_rk808` 早期加载后成功从 RTC 恢复系统时钟；
- `ntpd-rs` 联网后精确校时，无失败服务；
- WiFi（MT7921）通过 hostapd 提供 `moli-rk-wifi` AP，加入 br-lan 桥接；
- MT7921 蓝牙控制器由 BlueZ 正常上电，支持 BLE central/peripheral；
- MPTCP 和 DAE 在带 BTF 的 Linux 6.18 内核上正常运行；
- 已补齐 ZRAM 内核模块配置；部署该内核后的冷启动必须用 `zramctl` 和
  `systemd-analyze` 确认不再等待 `/dev/zram0`；
- 板载状态 LED（red:power、green:lan、green:wan、green:wlan）正常工作；
- 修复持久化 `machine-id` 后，D-Bus、DHCP 和交互延迟正常；
- `/nix` 与 `/nix/persistent` 顶层属主为 `root:root`，tmpfiles 不再报告 unsafe
  path transition；
- eMMC 可独立冷启动，不依赖原 OpenWrt 系统。

当前已经作为正式 `router` 运行。后续升级应继续检查 PPPoE、DHCP、DNS、NAT、
DDNS、监控和无线服务；涉及静态 `kernel-config` 的变更必须经过一次冷启动验证。

## 8. 从 macOS 写卡与串口日志

### 8.1 确认构建产物

构建机为 `root@192.168.0.50:2222`，仓库和结果链接分别位于
`/nix/src/nixos-config` 与 `/nix/src/nixos-config/result-router-r5c`。

```bash
cd ~/Documents/nixos/nixos-config
nix build .#nixosConfigurations.router.config.system.build.sdImage \
  --out-link result-router-r5c --print-build-logs

IMAGE=/nix/src/nixos-config/result-router-r5c/sd-image/nixos-image-sd-card-26.11pre-git-aarch64-linux.img.zst
test -f "$IMAGE"
zstd --test "$IMAGE"
sha256sum "$IMAGE"
```

构建日志中较早显示的分区表可能仍把第 2 分区标为 bootable；最终
`postBuildCommands` 应显示 `The bootable flag on partition 1 is enabled now.`

### 8.2 在 macOS 识别 SD 卡

```bash
diskutil list external physical
```

按容量、介质类型和分区确认整盘设备（例如 `/dev/disk4`），下文仅以此为示例；
设备编号不同就必须替换。先让 `sudo` 完成认证，避免 SSH 已开始传输后才停在
密码提示：

```bash
sudo -v
diskutil unmountDisk /dev/disk4
```

### 8.3 从构建机流式写入 SD 卡

无需先把压缩镜像复制到 Mac。通过 SSH 解压，并直接写入 macOS raw disk：

```bash
diskutil list external physical
diskutil unmountDisk /dev/disk5

set -o pipefail
ssh -A -p 2222 root@192.168.0.50 \
  'zstd -dc /nix/src/nixos-config/result-rock5c/sd-image/nixos-image-sd-card-26.11pre-git-aarch64-linux.img.zst' |
  sudo dd of=/dev/rdisk5 bs=8m
```

`/dev/rdisk4` 是 `/dev/disk4` 对应的 raw device。macOS 自带 `dd` 未必支持
`status=progress`；刷写时可在运行 `dd` 的终端按 `Ctrl-T`，或从另一终端执行
`sudo pkill -INFO -x dd`。如果构建机上的 `zstd` 几乎不占 CPU 且 SSH 发送队列
持续积压，通常是 Mac 端停在 `sudo` 认证或 `dd` 没有成功打开目标设备，按
`Ctrl-C` 停止整条管道，先完成 `sudo -v` 和 `diskutil unmountDisk`，再重新写入。
写完后：

```bash
sync
diskutil eject /dev/disk5
```

### 8.4 连接 R5C 调试串口

R5C 调试口为 3 针、3.3 V TTL，参数为 1500000 baud、8N1、无流控。接线必须交叉：

```text
R5C GND → USB-TTL GND
R5C TX  → USB-TTL RX
R5C RX  → USB-TTL TX
```

不要连接 USB-TTL 的 `VCC`/`3.3V`/`5V`；R5C 使用自己的 USB-C 电源。不要使用
RS-232 电平转换器。将 CH340/CH341 或其他 USB-TTL 转接器插入 Mac，查看实际
设备名：

```bash
ls -l /dev/cu.* /dev/tty.*
```

设备名可能是 `/dev/cu.wchusbserial*`、`/dev/cu.usbserial*` 或
`/dev/cu.usbmodem*`，由转接器固件和 macOS 驱动决定；即使使用 CH340 也不保证
名称包含 `wch`。

### 8.5 使用 tio 读取并保存日志

```bash
brew install tio
tio --list
tio -b 1500000 -d 8 -s 1 -p none -f none /dev/cu.usbmodem57920206431
```

需要同时保存日志时追加 `--timestamp --log --log-file nanopi-r5c-boot.log
--log-strip`。先启动 `tio`，再让 R5C 完全断电并重新上电，才能保留 DDR training、
SPL、BL31、U-Boot、extlinux 和 Linux 内核的完整输出。退出 `tio`：`Ctrl-T` 然后
按 `Q`。串口设备一次只能被一个程序占用。

### 8.6 识别启动阶段

正常的 SD bootloader 应出现：

```text
U-Boot SPL 2026.04
U-Boot 2026.04
Model: FriendlyElec NanoPi R5C
```

随后应从 SD 卡第 1 分区读取 `/extlinux/extlinux.conf`、`linux Image`、`initrd`
和 `rockchip/rk3568-nanopi-r5c.dtb`。内核命令行应包含：

```text
earlycon=uart8250,mmio32,0xfe660000
console=ttyS2,1500000n8
console=tty0
```

不要把波特率追加到 `earlycon` 的 MMIO 地址后。错误写成
`earlycon=uart8250,mmio32,0xfe660000,1500000` 时，内核可能已经正常运行，但串口
会停留在 U-Boot 的 `Starting kernel ...`。

如果系统已进入 NixOS、网卡也已建立链路，却在约 20 秒后无日志复位，检查目标
主机是否导入了 `nixos/hardware/disable-watchdog.nix`。U-Boot 2026.04、DDR
v1.23/1056 MHz 和 BL31 v1.45 是仓库当前 Nixpkgs 启动链的正常版本组合；若日志
在约 3 秒停止，先检查最终 extlinux 命令行是否仍混入多个串口 console、
`keep_bootcon` 或 `ignore_loglevel`，不要仅凭停止位置判定 U-Boot 有问题。最终
命令行不应同时出现 `console=ttyS0`/`ttyAMA0`/`ttyS2`，也不应长期保留
`keep_bootcon`；R5C 只使用 `console=ttyS2,1500000n8`。

如果显示 `U-Boot 2024.10-OpenWrt` / `Model: Easepi RK3568 Board`，则设备仍由
eMMC 中的旧 bootloader 接管。如果 `Starting kernel ...` 后立即重新出现 DDR
training，表示设备硬复位。U-Boot 的 `Net: No ethernet found.` 只表示 U-Boot
未初始化板载 PCIe 网卡，不能据此判断 Linux 网卡状态。

### 8.7 进入 U-Boot 命令行

在倒计时出现前连续按空格，成功后显示 `=>`；若已看到 extlinux 的
`Enter choice:` 说明按键太晚。只读检查 eMMC 和 SD：

```text
mmc list
mmc dev 0
mmc info
mmc part
mmc dev 1
mmc info
mmc part
```

本机已确认：`mmc 0` = 28.9 GiB eMMC（`mmc@fe310000`），`mmc 1` = SD 卡
（`mmc@fe2b0000`）。擦除命令具有破坏性，每次写入或擦除前必须重新用
`mmc info` 核对容量和设备控制器。

## 9. 内核与系统闭包裁剪

正式 `router` 真机系统闭包约 **2.0 GiB**（约 964 个 requisites，2026-07-29）。
对 NixOS 路由器偏大，但当前没有证据表明会造成运行故障。最值得继续优化的是
R5C 静态内核配置，而不是删除作者的 nixpkgs 补丁或随意移除路由服务。

当前 `kernel-config` 约 236 KiB：内建 `=y` 2094、模块 `=m` 712、明确禁用 4198。
它源自通用 Rockchip/ARM64 基线，仍启用了大量非 R5C 硬件族，不能视为最小内核。

### 补丁不是主要问题

`patches/nixpkgs/` 的 10 个补丁与作者仓库逐文件一致。R5C 硬件目录没有维护
额外的 Linux 板级 `.patch` 堆栈；主要差异是静态 `kernel-config`、R5C U-Boot
defconfig、目标 DTB 筛选、精简固件 derivation、SD image 分区与 Rockchip
引导载荷。删除 nixpkgs 补丁既不能显著减小闭包，也会制造不必要的上游偏离。

### 已实施且应保留的裁剪

- **精简固件**：只保留 MT7921/MT7961 Wi-Fi、MT7921 蓝牙和 RTL8125 所需固件，
  不引入完整约 800 MiB 的 `linux-firmware`。收益最大、风险可控。
- **单板 DTB**：`hardware.deviceTree.filter` 只复制 `rk3568-nanopi-r5c.dtb`。
- **精简 initrd**：`boot.initrd.availableKernelModules` 强制为空，不继承通用
  SD image 的 NVMe、USB 存储和虚拟机模块。
- **限制启动代数**：256 MiB FAT `/boot` 只保留两个 extlinux generation，
  仍保留一个可回退版本。
- **真实交叉编译**：x86_64 `ml-builder` 上用 `pkgsCross.aarch64-multiplatform`
  编译，编译器原生运行输出 AArch64 对象，不通过 QEMU 执行 ARM64 GCC。

### 不能裁掉的内核能力

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

蓝牙 BNEP 是例外：当前只需要 BLE/GATT、配对及 central/peripheral 角色，
不使用蓝牙 PAN。缺少 BNEP 会产生一条 BlueZ 警告，不应仅为消除日志而启用。

### 仍有裁剪潜力的区域

静态配置仍包含约 274 个宽泛的网络、无线、显示、媒体和声音相关选项。优先
审计：除 Realtek 之外的大量 PCI/服务器网卡厂商；除 MediaTek 之外的无线网卡
厂商；Nouveau 和与无头路由器无关的 DRM 驱动；摄像头/视频采集和完整媒体
子系统；SoundWire 及无实际设备对应的音频驱动；与 RK3568/R5C 不相关的 SoC、
开发板和存储控制器。不能根据一次 `lsmod` 直接删除：内建驱动不会出现在
`lsmod`，部分驱动只在冷启动、插入 USB 设备、建立 PPPoE 或加载 eBPF 时使用。

### 用户空间闭包

`minimal.nix` 会导入 Home Manager，并为 `root` 和 `zhyi` 生成非客户端环境
（git、htop、jq 等）。这在闭包中较显眼，但与作者结构一致；不应只为 router
创建特殊删除规则。router 相比作者 `lt-home-router` 增加了 DAE、Wi-Fi 和
Prometheus 指标，同时没有引入作者的 lancache 与 ncps 服务端，应用层没有证据
表明本 fork 比作者配置显著更重。

### 后续裁剪方法

每轮只处理一个驱动族，并保留上一个可启动 generation：冷启动后保存 `lsmod`、
`lspci -k`、`lsusb -t`、`dmesg` 和 `/sys/kernel/debug/devices_deferred`；
对照 R5C DTS、PCI/USB modalias 和当前服务的内核需求；修改一组 Kconfig 并交叉
重新构建；验证冷启动、双网卡、PPPoE、Wi-Fi、蓝牙、DAE、MPTCP、ZRAM、LED 和
RTC；比较 kernel、modules、initrd、`/boot` 与系统 closure 的实际尺寸；确认
稳定后才开始下一组。记录命令：

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

目标是减少无关模块和构建时间，不是追求最小数字；任何导致冷启动、路由数据面
或回退能力下降的裁剪，都不应进入正式 `router`。
