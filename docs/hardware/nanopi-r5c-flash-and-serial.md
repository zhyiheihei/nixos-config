# NanoPi R5C：从 macOS 写入 SD 卡到读取串口日志

本文是 NanoPi R5C 真机调试操作手册，范围从确认构建产物、在 macOS 写入 SD 卡，
到通过 3.3 V TTL 串口保存完整启动日志。镜像设计和构建原理见
[`nanopi-r5c.md`](./nanopi-r5c.md)。

## 1. 确认构建产物

构建机为 `root@192.168.0.50:2222`，仓库和结果链接分别位于：

```text
/nix/src/nixos-config
/nix/src/nixos-config/result-router-r5c
```

构建并检查镜像：

```bash
cd /nix/src/nixos-config

nix build \
  .#nixosConfigurations.router.config.system.build.sdImage \
  --out-link result-router-r5c \
  --print-build-logs

IMAGE=/nix/src/nixos-config/result-router-r5c/sd-image/nixos-image-sd-card-26.11pre-git-aarch64-linux.img.zst
test -f "$IMAGE"
zstd --test "$IMAGE"
sha256sum "$IMAGE"
```

构建日志中较早显示的分区表可能仍把第 2 分区标为 bootable；最终
`postBuildCommands` 应显示：

```text
The bootable flag on partition 2 is disabled now.
The bootable flag on partition 1 is enabled now.
```

## 2. 在 macOS 识别 SD 卡

插入 SD 卡后执行：

```bash
diskutil list external physical
```

按容量、介质类型和分区确认整盘设备，例如 `/dev/disk4`。下文仅以
`/dev/disk4` 为例；设备编号不同就必须替换。选错目标会覆盖其他磁盘。

先让 `sudo` 完成认证，避免 SSH 已开始传输后才停在密码提示：

```bash
sudo -v
diskutil unmountDisk /dev/disk4
```

## 3. 从构建机流式写入 SD 卡

无需先把压缩镜像复制到 Mac。通过 SSH 解压，并直接写入 macOS raw disk：

```bash
diskutil list external physical
diskutil unmountDisk /dev/disk5

set -o pipefail

ssh -A -p 2222 root@192.168.0.50 \
  'zstd -dc /nix/src/nixos-config/result-opi5p/sd-image/nixos-image-sd-card-26.11pre-git-aarch64-linux.img.zst' |
  sudo dd of=/dev/rdisk5 bs=8m
```

`/dev/rdisk4` 是 `/dev/disk4` 对应的 raw device。macOS 自带 `dd` 未必支持
`status=progress`；刷写时可在运行 `dd` 的终端按 `Ctrl-T`，或从另一终端执行：

```bash
sudo pkill -INFO -x dd
```

如果构建机上的 `zstd` 几乎不占 CPU，且 SSH 发送队列持续积压，通常是 Mac 端停在
`sudo` 认证，或 `dd` 没有成功打开目标设备。按 `Ctrl-C` 停止整条管道，先完成
`sudo -v` 和 `diskutil unmountDisk`，再重新写入。

写完后：

```bash
sync
diskutil eject /dev/disk4
```

## 4. 连接 R5C 调试串口

R5C 调试口为 3 针、3.3 V TTL，参数为 1500000 baud、8N1、无流控。接线必须交叉：

```text
R5C GND → USB-TTL GND
R5C TX  → USB-TTL RX
R5C RX  → USB-TTL TX
```

不要连接 USB-TTL 的 `VCC`、`3.3V` 或 `5V`；R5C 使用自己的 USB-C 电源。不要使用
RS-232 电平转换器。

将 CH340、CH341 或其他 USB-TTL 转接器插入 Mac，查看实际设备名：

```bash
ls -l /dev/cu.* /dev/tty.*
```

设备名可能是：

```text
/dev/cu.wchusbserial*
/dev/cu.usbserial*
/dev/cu.usbmodem*
```

设备名由转接器固件和 macOS 驱动决定；即使使用 CH340，也不保证名称中包含
`wch` 或 `CH340`。

## 5. 使用 tio 读取并保存日志

安装并列出串口：

```bash
brew install tio
tio --list
```

以实际设备名连接：

```bash
tio \
  -b 1500000 \
  -d 8 \
  -s 1 \
  -p none \
  -f none \
  /dev/cu.usbmodem57920206431
```

需要同时保存日志时：

```bash
tio \
  -b 1500000 \
  -d 8 \
  -s 1 \
  -p none \
  -f none \
  --timestamp \
  --log \
  --log-file nanopi-r5c-boot.log \
  --log-strip \
  /dev/cu.usbmodem57920206431
```

先启动 `tio`，再让 R5C 完全断电并重新上电，才能保留 DDR training、SPL、BL31、
U-Boot、extlinux 和 Linux 内核的完整输出。退出 `tio`：

```text
Ctrl-T，然后按 Q
```

串口设备一次只能被一个程序占用。如果另一个 `tio`、CoolTerm 或 Serial 已连接，
先关闭它。

## 6. 识别启动阶段

正常的 SD bootloader 应出现：

```text
U-Boot SPL 2026.04
U-Boot 2026.04
Model: FriendlyElec NanoPi R5C
```

随后应从 SD 卡第 1 分区读取：

```text
/extlinux/extlinux.conf
linux Image
initrd
rockchip/rk3568-nanopi-r5c.dtb
```

内核命令行应包含：

```text
earlycon=uart8250,mmio32,0xfe660000
console=ttyS2,1500000n8
console=tty0
```

不要把波特率追加到 `earlycon` 的 MMIO 地址后。错误写成
`earlycon=uart8250,mmio32,0xfe660000,1500000` 时，内核可能已经正常运行，但串口
会停留在 U-Boot 的 `Starting kernel ...`，看不到后续输出。

如果系统已经进入 NixOS、网卡也已建立链路，却在约 20 秒后无日志复位，检查目标
主机是否导入了 `nixos/hardware/disable-watchdog.nix`。R5C 当前需要禁用公共
minimal 配置中的运行时硬件 watchdog。

U-Boot 2026.04、DDR v1.23/1056 MHz 和 BL31 v1.45 是仓库当前 Nixpkgs 启动链
的正常版本组合。2026-07-27 的受控 A/B 测试确认它能通过 MMC、Btrfs、真实
systemd 和网卡初始化。若日志在约 3 秒停止，先检查最终 extlinux 命令行是否仍
混入多个串口 console、`keep_bootcon` 或 `ignore_loglevel`，不要仅凭停止位置
判定 U-Boot 有问题。

最终命令行不应同时出现 `console=ttyS0`、`console=ttyAMA0` 和
`console=ttyS2`，也不应长期保留 `keep_bootcon`。R5C 只使用
`console=ttyS2,1500000n8`；正式 8250 console 接管后，earlycon 应正常注销。

如果显示：

```text
U-Boot 2024.10-OpenWrt
Model: Easepi RK3568 Board
```

则设备仍由 eMMC 中的旧 bootloader 接管，而不是 SD 镜像中的 R5C U-Boot。

如果 `Starting kernel ...` 后立即重新出现 DDR training，表示设备发生了硬复位，
不是单纯丢失普通 console 输出。提交问题时应提供从上一条 `Starting kernel`、
下一轮 DDR training，到新一轮 kernel 参数的连续日志。

U-Boot 中的 `Net: No ethernet found.` 只表示 U-Boot 没有初始化板载 PCIe 网卡，
不能据此判断 Linux 中的网卡状态。

## 7. 进入 U-Boot 命令行

在下面的倒计时出现前连续按空格：

```text
Hit any key to stop autoboot:
```

成功后显示 `=>`。如果已经看到 extlinux 的 `Enter choice:`，说明按键太晚；此时
输入的命令会被当作启动项编号，并显示 `not found`。

只读检查 eMMC 和 SD：

```text
mmc list
mmc dev 0
mmc info
mmc part
mmc dev 1
mmc info
mmc part
```

本机已确认的设备对应关系为：

```text
mmc 0: 28.9 GiB eMMC，mmc@fe310000
mmc 1: SD 卡，mmc@fe2b0000
```

擦除命令具有破坏性，不能仅凭编号猜测目标。每次执行写入或擦除前，都必须重新用
`mmc info` 核对容量和设备控制器。
