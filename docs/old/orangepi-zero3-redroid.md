# Orange Pi Zero 3：H618 reDroid 12、Mali GPU 与 Cedar 视频硬解

> **历史归档（2026-08-08）**：`tools/redroid-opi03/` 已整体移除，本文不再作为可执行手册；其中引用的构建、打包和验证脚本已删除，命令不可复现。

本文描述 `opi03` 的第二阶段目标：在 NixOS 主机内运行自制 reDroid 12 容器，
Android 图形走 Mali-G31，视频编解码走 Allwinner Cedar/VE。它分两个 Stage：
**Stage 1（当前）只要求 Mali GPU renderer 在容器内驱动**，即 SurfaceFlinger
用 `ro.hardware.egl=mali` 经 `/dev/mali0` 渲染；**Stage 2（后续）再加视频硬解**
（Codec2/Cedar，需先把 vendor libcedarc 64 位 blob 换成 Android bionic 版）。
它不是“容器能启动”文档；Stage 1 的完成标准是 SurfaceFlinger 的 Mali renderer
证据。

当前状态：NixOS/vendor-kernel 包装、Android source overlay、打包、导入与验收工具
已经落库；GPU-only 产品配置已生效，Android 编译进行中，尚未在实机完成 GPU 动态
验收。因此本文不能被解读为“硬件加速已经验证通过”。

## 为什么固定在 Android 12

H618 的可用闭源图形和视频栈来自同一代 Android 12 BSP：

| 层 | 固定实现 |
| --- | --- |
| 主机内核 | Orange Pi `orange-pi-5.4-sun50iw9`，Linux 5.4.125 |
| 板级 DT | `sunxi/sun50i-h616-orangepi-zero3.dtb` |
| GPU KMD | BSP 内 `mali-bifrost` Kbase r20p0，产生 `/dev/mali0` |
| GPU UMD | H618 BSP 的 `libGLES_mali.so`、`vulkan.apollo.so`、`gralloc.apollo` |
| VPU KMD | `cedar_dev`、ION、G2D，产生 `/dev/cedar_dev`、`/dev/ion`、`/dev/g2d` |
| VPU UMD | `hardware/aw/libcodec2` 与 `frameworks/av/media/libcedarc` 的 CedarX 库 |
| 容器层 | reDroid 12，保留 64/32 位 ARM ABI |

这套栈按 ABI 配对，不接受以下替换：

- 主线 Panfrost + Allwinner 闭源 `libGLES_mali.so`；
- 随机版本 Kbase + Android 12 UMD；
- 先把容器升级到 Android 16，再期待旧 vendor blob 自动兼容；
- 只看到 `/dev/dri` 或容器启动，就宣称 Cedar 硬解成功。

Android 16 可以作为 Android 12 验收后的独立移植项目，但不是本阶段的兼容开关。

## 仓库实现边界

- [`pkgs/opi03-redroid-kernel/`](../../pkgs/opi03-redroid-kernel/)：固定 Orange Pi
  vendor kernel commit，在 x86_64 `ml-builder` 上交叉编译；
- [`pkgs/opi03-mali-kbase/`](../../pkgs/opi03-mali-kbase/)：从同一源码构建匹配的
  `mali_kbase.ko`；
- [`nixos/hardware/orangepi-zero3/`](../../nixos/hardware/orangepi-zero3/)：选择 vendor
  DTB、CMA、Kbase 与 SD 启动布局；
- [`hosts/opi03/configuration.nix`](../../hosts/opi03/configuration.nix)：本地镜像、
  持久化 `/data`、loopback ADB 和设备节点门禁；
- [`tools/redroid-opi03/`](../../tools/redroid-opi03/)：Android 12 source overlay、
  rootfs 打包、实机导入与验收脚本。

没有新增 flake input，也不修改 `flake.lock`。H618 BSP 仅服务这一块板，固定 commit
直接写在板级 package/tool 中，避免把超大 Android/kernel 仓库扩散到全局输入图。

## 官方基线与公开案例

本适配不是从通用 arm64 config 猜选项。参考资料按证据强度分层使用：

- [Allwinner 官方 H618 方案说明](https://www.allwinnertech.com/uploads/download_source/20260303162657a4.pdf)：
  证明芯片包含 Mali-G31，并给出 H.265/H.264/VP9/AVS2 的硬件能力上限；这只是硅片
  能力，不等于某个 Linux 或容器镜像已经接通对应驱动；
- [Orange Pi Zero 3 官方 Wiki](https://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_Zero_3)：
  官方适配表明确把普通 Linux 镜像的 Mali GPU 与 video codec 标为 `NO`，而把
  Android 12/Linux 5.4 的两项标为 `OK`。因此本项目必须复用 Android vendor ABI，
  不能把 Armbian/Panfrost 能启动当作目标完成；
- Orange Pi [英文官方下载页](https://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-Zero-3.html)
  与[中文官方下载页](https://www.orangepi.cn/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-Zero-3.html)：
  前者发布 Google Drive 的 18 个 `H618-Android12-Src.tar.gz` 分片，后者发布同类
  Android 源码的百度网盘入口；最终都必须通过固定的官方逐片 MD5 清单。这是 Zero 3
  板级 Android userspace 的首选基线；
- [Orange Pi 官方 vendor kernel](https://github.com/orangepi-xunlong/linux-orangepi)：固定
  commit 中的 `sun50iw9p1smp_h618_android_defconfig` 是 H618 硬件、G2D、DI300、
  Cedar、ION 与 Binder 的主机内核基线；
- [BPI-SINOVOIP H618 Android 12 BSP](https://github.com/BPI-SINOVOIP/BPI-H618-Android12)：
  Banana Pi 的[官方 M4 Berry 文档](https://docs.banana-pi.org/zh/BPI-M4_Berry/BananaPi_BPI-M4_Berry)
  将其列为 H618 Android 12 源码。仓库提供可按 Git commit 审计的同代 `apollo`、
  Mali、CedarX/Codec2 对照实现；其 README 明确要求合并 GitHub 之外的 oversize
  files。它是官方同 SoC 参照和 Orange Pi 下载不可用时的构建回退，不是 Zero 3
  板级首选；
- [YAJATapps 的 Zero 2W/Zero 3 OmniROM 12.1 清单](https://github.com/YAJATapps/android_apollo-p2_local_manifest)
  与[构建记录](https://blogs.yajatkumar.com/2024/10/source-compilation-omnirom-121-for.html)：
  这是目前找到的最接近本板的公开可复现案例。它指出 Zero 3 的 Longan 板型必须选
  `p3`、`PRODUCT_ORANGE_PI_ZERO_2W` 必须设为 `false`，打包也必须显式使用 `p3`；
  其设备、`hardware/aw` 和 `vendor/aw` 仓库只用于逐文件差异审计，不直接覆盖官方
  源码；
- [社区实机复现记录](https://www.reddit.com/r/OrangePI/comments/1ji5w19/howto_android_12_tv_for_orange_pi_zero_3_working/)：
  有用户报告上述 Zero 3 OmniROM 可用硬件解码流畅播放 H.265 4K。它是有价值的动态
  旁证，但不是 reDroid 证据，也不能替代本项目的 Cedar 中断/文件描述符验收；
- [Armbian Orange Pi Zero 3 板级配置](https://github.com/armbian/build/blob/main/config/boards/orangepizero3.csc)：
  用于核对主线 U-Boot、DT、以太网和 uwe5622 完整扩展边界；主线 Panfrost/Cedrus
  只能作为外围硬件参照，不能替代 Android blob 所需的 vendor ABI；
- [reDroid 官方文档](https://github.com/remote-android/redroid-doc)及
  [官方构建流程](https://github.com/remote-android/redroid-doc/blob/master/android-builder-docker/README.md)：
  用于 Binder、容器启动参数、arm64 产品、patch 和 system/vendor 镜像打包边界；
- Radxa 的[官方 Rock 5 reDroid 指南](https://docs.radxa.com/en/rock5/rock5b/app-development/redroid)：
  是嵌入式 Mali 板卡把 `/dev/mali0` 交给 privileged reDroid、使用板级 GPU mode，
  并要求主机开启 PSI 的厂商案例。本项目复用这种容器边界与检查思路，但不复制
  RK3588 的 Kbase、Mali-G52、Rockchip gralloc 或 MPP；H618 仍必须使用自己的
  r20p0/Apollo/CedarX ABI。

Orange Pi 官方和 OmniROM 案例只证明 Zero 3 裸机 Android 12 的板级栈；目前仍没有
找到可直接复刻的公开“Orange Pi Zero 3/H618 + reDroid + Mali/CedarX”完整案例。
因此文档不会把裸机 Android、Armbian 主线硬解或 BPI 裸机 Android 的成功误写成
reDroid 已经成功；最终仍以本文末尾的 Mali renderer 与 Cedar 动态证据为准。

### Zero 3 板级差异审计

固定的 Orange Pi 5.4 分支不是完整的 Zero 3 最终状态。它的
[`sun50i-h616-orangepi-zero3.dts`](https://github.com/orangepi-xunlong/linux-orangepi/blob/9ab7a758149d3c9b721878a0c18b3f9c5d6c93e6/arch/arm64/boot/dts/sunxi/sun50i-h616-orangepi-zero3.dts)
自 2023 年首次导入后没有后续板级提交，GMAC 仍为 `tx-delay = <7>`、
`rx-delay = <0>`。三条独立证据表明 RX 时序不能保留为零：

- Orange Pi 后来的[官方 6.1 Zero 3 DTS](https://github.com/orangepi-xunlong/linux-orangepi/blob/71144529b0334d1488624c41d0d3ba0cb03dd4c1/arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero3.dts)
  使用 `allwinner,rx-delay-ps = <1800>` 和 700 ps TX delay；
- Linux 上游的[稳定性修复讨论](https://lists.infradead.org/pipermail/linux-arm-kernel/2023-October/873197.html)
  说明加入该时序后以太网稳定；最终[主线 DTS](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero3.dts)
  按 RGMII binding 改写为 `phy-mode = "rgmii-rxid"`；
- Zero 3 已实际发布镜像的 p3 Android 12 配置，在固定 commit
  `47b861f18054c373241666c1ad3cb6ba0f265441` 的
  [`board.dts`](https://gitlab.com/Yajat/android_longan/-/blob/47b861f18054c373241666c1ad3cb6ba0f265441/device/config/chips/h618/configs/p3/linux-5.4/board.dts)
  中对旧 Allwinner GMAC 驱动使用 `rx-delay = <6>`。

主线的 `rgmii-rxid` 不能原样放回 5.4 BSP：该 BSP 的 `sunxi-gmac` 只接受
`mii`、`rgmii` 和 `rmii`，并直接读取整数 `tx-delay`/`rx-delay` 档位。因此本项目的
[`orangepi-zero3-board-fixes.patch`](../../pkgs/opi03-redroid-kernel/orangepi-zero3-board-fixes.patch)
使用 p3 已验证的旧 binding 值 `rx-delay = <6>`，同时让绿色状态灯采用 Orange Pi
6.1 DTS 的 heartbeat 策略，并在 kernel 接管 GPIO 后关闭 U-Boot 阶段的红灯；这与
[官方 Wiki](https://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_Zero_3)
“U-Boot 红灯、kernel 绿灯”的阶段语义一致，而不是把主线 DT binding 生硬反向移植
到 vendor 驱动。

p3 的
[`sun50iw9p1smp_h618_zero3_android_defconfig`](https://gitlab.com/Yajat/android_longan/-/blob/47b861f18054c373241666c1ad3cb6ba0f265441/kernel/linux-5.4/arch/arm64/configs/sun50iw9p1smp_h618_zero3_android_defconfig)
还比 Orange Pi 的通用 H618 Android defconfig 多出以下板级项。本项目只保留运行和
验收所需的最小集合：

| 差异 | 本项目处理 | 理由 |
| --- | --- | --- |
| `MOTORCOMM_PHY` | 内建 | 板载千兆 PHY 是 YT8531，不能只依赖 generic PHY |
| `LEDS_GPIO`、heartbeat | 内建 | PC12 红灯标识 U-Boot 阶段，kernel 接管后熄灭；PC13 绿灯为运行心跳 |
| `LOG_BUF_SHIFT=17` | 保留 | 128 KiB 日志环，便于捕获 Mali/Cedar 早期初始化且内存代价很小 |
| uwe5622 Wi-Fi/BT | 暂不启用 | 必须连同 firmware 与 attach helper 一起适配，不能只开半套驱动 |
| `GPIO_SYSFS`、`SPI_SPIDEV` | 不启用 | 是开发接口，不是 GPU、VPU、网卡或启动依赖 |

这样既补上精确板型相对通用 SoC defconfig 的缺口，也没有复制 p3 调试镜像的全部
宽松选项。

### Android userspace 差异审计

公开的 Zero 3 Android 12 产品不是直接证明 reDroid 能工作的成品，但它能约束
userspace 选择：

- Apollo
  [`BoardConfig.mk`](https://github.com/YAJATapps/android_device_softwinner/blob/f4cc19361c00cd4717632f4980191316a0852f3b/apollo/BoardConfig.mk)
  使用 `TARGET_BOARD_PLATFORM=apollo`、`TARGET_GPU_TYPE=mali-g31`、
  `USE_IOMMU=true`、32 位应用兼容和 G2D；本项目的 vendor overlay 保留同样的
  GPU/ABI 合约；
- 同代
  [`hardware/aw/gpu/product_config.mk`](https://github.com/YAJATapps/android_hardware_aw/blob/eb2b7e7c8708284128fc170635d5f9bca2495048/gpu/product_config.mk)
  把 `mali-g31` 映射为 `mali-bifrost`，并把匹配的 32/64 位
  `libGLES_mali.so` 安装为 EGL/Vulkan userspace；这也是本项目使用
  `gpu-package` 而不是 Mesa/Panfrost 的依据；
- Apollo
  [`media/config.mk`](https://github.com/YAJATapps/android_device_softwinner/blob/f4cc19361c00cd4717632f4980191316a0852f3b/apollo/common/media/config.mk)
  虽包含 `android.hardware.media.aw.c2@1.0-service` 和 Allwinner codec XML，默认
  `MEDIA_CTS_TEST_ENABLE=true` 会跳过这组硬件 C2 安装。reDroid 产品不能沿用这个
  测试开关，否则系统能启动但只会注册 Google 软件 codec；本项目显式安装服务、
  primary XML 及其 `Include` 文件，并以运行时 `c2.allwinner.*` 和 Cedar 中断为门禁。
- 同板产品还通过 `softwinner/common.mk` 继承
  [`libcdclist.mk`](https://github.com/YAJATapps/android_frameworks_av/blob/4069a322b9154c02184fb7f6c4fed29309ddf257/media/libcedarc/libcdclist.mk)。
  `android.hardware.media.aw.c2@1.0-service` 虽然直接链接 `libvdecoder`、`libVE`，实际
  H.264/H.265 等引擎仍依赖该清单安装的 `libawh264`、`libawh265` 及 vendor 变体。
  本项目现在继承同一运行库清单。打包脚本默认（Stage 1）检查服务、VINTF、Mali
  32/64 位库、gralloc 与 `redroid.opi03.rc`；Cedar 配置和 H.264/H.265 插件属于
  Stage 2，须以 `--stage2-codec2` 才会强制检查（见"打包也是长任务"段）。

reDroid 官方只为通用 `auto`、`host`、`guest` GPU 模式定义了 DRM render-node 或
SwiftShader 路径；H618 的闭源 BSP 使用 `/dev/mali0`、Apollo gralloc 和 ION，而不是
`/dev/dri/renderD*`。所以本项目增加独立的 `opi03` GPU mode，只替换 GPU 初始化，
仍继承 reDroid 的 arm64/arm32 容器、虚拟显示和分区布局。裸机 Apollo 配置中的物理
显示 HWC、HDMI、audio、camera 包不会整组导入容器，避免把“GPU userspace ABI”误等同
为“复制整台 Android 电视盒系统”。

## vendor kernel 源锁

内核源码固定为 commit `9ab7a758149d3c9b721878a0c18b3f9c5d6c93e6`，源码包
SRI 固定为 `sha256-9vPjjbSA6Knec7GyZ20sO3FZKhxRRzaK/vwGXhbOyD0=`。需要
重新审计上游内容时，在 `ml-builder` 运行：

```bash
export HTTP_PROXY=http://192.168.0.64:7892
export HTTPS_PROXY=$HTTP_PROXY
export http_proxy=$HTTP_PROXY
export https_proxy=$HTTPS_PROXY

nix store prefetch-file --unpack --json \
  'https://github.com/orangepi-xunlong/linux-orangepi/archive/9ab7a758149d3c9b721878a0c18b3f9c5d6c93e6.tar.gz'
```

输出的 `hash` 必须与上述值和
[`pkgs/opi03-redroid-kernel/default.nix`](../../pkgs/opi03-redroid-kernel/default.nix)
一致。不要把整个 kernel 仓库加进 `flake.lock`；只有明确更新 vendor kernel commit
时才允许同时更新该哈希。

同板公开实现的 Longan、device、`hardware/aw` 与 `frameworks/av` 也只作为审计
参考，并已把本次使用的四个 commit 固定在
[`source-lock.env`](../../tools/redroid-opi03/source-lock.env)。这些 reference lock
不会被 `prepare-source.sh` 合并进 Orange Pi/BPI 源树；它们只保证文档中的差异结论
以后仍可复核。

## kernel config 的生成契约

[`generate-config.sh`](../../pkgs/opi03-redroid-kernel/generate-config.sh)先展开 Orange Pi
官方 H618 Android defconfig，再只添加 NixOS tmpfs/Btrfs 启动、systemd/Podman
cgroup/namespace、仓库 nftables 防火墙、BBR/FQ 和 reDroid 宿主所需增量。生成器会在
编译前检查 GMAC、串口、MMC 代际、Cedar、G2D、ION、Binder、CMA 和容器能力。

旧配置启用 1957 个符号；官方基线增量版启用 1596 个（其中包含 nftables set
基础设施），减少 361 个启用项，同时修复旧配置关闭 nftables、PID namespace、
BBR/FQ 的问题。不要手工编辑生成的 `kernel-config`；在 `ml-builder` 使用固定源码和
该 kernel 自身的 Nix build environment 重生成：

```bash
nix build --no-link \
  '.#packages.x86_64-linux.opi03-redroid-kernel.vendorSource'

kernel_drv=$(nix eval --raw \
  '.#packages.x86_64-linux.opi03-redroid-kernel.drvPath')
vendor_source=$(nix eval --raw \
  '.#packages.x86_64-linux.opi03-redroid-kernel.vendorSource.outPath')

nix develop "$kernel_drv" --command \
  ./pkgs/opi03-redroid-kernel/generate-config.sh \
  "$vendor_source" \
  ./pkgs/opi03-redroid-kernel/kernel-config
```

相对官方通用 H618 Android defconfig，Motorcomm PHY、GPIO LED 和较大的日志环是
经过上述精确板型审计后补入的必要增量。唯一有意关闭的板载硬件栈是 uwe5622：
官方裸机 config 只启用其 WCN core，而 Armbian 的工作案例还需要配套 firmware 和
定制蓝牙 attach helper。本轮 GPU/VPU bring-up 将整套无线栈关闭，避免编译一个既
不可用又因 `/bin/pwd` 硬编码而破坏 Nix sandbox 的半成品；无线作为后续独立验收项
引入。

## 构建 NixOS 镜像

先求值，确认任务要求 `aarch64-cross`，不会调度到小 ARM 板：

```bash
nix eval --raw \
  '.#nixosConfigurations.opi03.config.system.build.sdImage.drvPath'
```

内核与 SD 镜像都是长任务，由用户执行：

```bash
nix build \
  '.#nixosConfigurations.opi03.config.system.build.sdImage' \
  --out-link result-opi03 \
  --print-build-logs \
  --show-trace \
  --builders '' \
  --option max-jobs 4 \
  --option cores 7
```

首次切换 vendor kernel 时不要先创建 reDroid 的 `.image-ready` 标记。这样即使 Android
镜像尚未导入，`podman-redroid.service` 也只是 `ConditionPathExists` 未满足，不会让
Colmena 激活失败。保留 extlinux 中两个 generation；冷启动失败时从串口选择上一代。

串口控制台是 `ttyAS0`（vendor 5.4 的 sunxi-uart 驱动把 UART0 注册为 ttyAS0，
不是 ttyS0），`console=ttyAS0,115200n8` 已写入 kernelParams。早期挂起（uart0
probe 附近）时可用 `loglevel=8 ignore_loglevel` 参数（见
`nixos/hardware/orangepi-zero3/default.nix`，提交 `11de0cfd`）让内核打印全部
消息；`ignore_loglevel` 保证消息不被 console_loglevel 过滤。注意 `uname -r`
显示的 `-aarch64-unknown-linux-gnu` 是交叉编译工具链前缀，不是运行架构。

烧录 SD 卡（mac 侧，先把卡插到 MacBook，盘符按 `diskutil list external physical`
实际值改）：

```bash
diskutil list external physical     # 确认盘符，例如 /dev/disk4
diskutil unmountDisk /dev/disk4

set -o pipefail
ssh -A -p 2222 root@192.168.0.50 \
  'zstd -dc /nix/src/nixos-config/result-opi03/sd-image/nixos-image-sd-card-26.11pre-git-aarch64-linux.img.zst' |
  sudo dd of=/dev/rdisk4 bs=8m conv=fsync

diskutil eject /dev/disk4
```

注意：macOS 对 FAT32 boot 分区以只读方式挂载（fskit），**无法直接改卡上
`/extlinux/extlinux.conf`**；临时改日志参数应走 NixOS kernelParams 重建镜像，
而不是改卡。


vendor kernel 启动后先验证主机 ABI：

串口接入：Zero 3 的调试串口是 3.3V TTL UART0（板载 4-pin 排针，GND/TX/RX；
RX 接板子 TX、TX 接板子 RX），波特率 **115200**。mac 用 `screen /dev/cu.usbserial-* 115200`
或 `minicom -D /dev/cu.usbserial-* -b 115200`；Linux 用
`minicom -D /dev/ttyUSB0 -b 115200`。看内核与 systemd 输出必须走串口（无 HDMI
输出）。

```bash
uname -r
test -c /dev/mali0
test -c /dev/cedar_dev
test -c /dev/ion
test -c /dev/g2d
lsmod | grep '^mali_kbase '
dmesg | grep -iE 'mali|kbase|cedar|g2d|ion'
```

四个字符设备和 `mali_kbase` 未全部出现时，禁止继续用 Android userspace 掩盖内核
问题。

## 准备 Android 12 BSP 源码

### 环境替换清单

本文档大量使用本任务构建机的私有内网地址与路径。复现前先按你的环境替换：

| 变量 | 本任务值 | 说明 |
|---|---|---|
| `ML_BUILDER` | `root@192.168.0.50`（ssh `-p 2222`） | NixOS 构建机，`/nix/src/nixos-config` 为 flake 工作树 |
| `UBUNTU_BUILD` | `zhyi@192.168.0.60` | Android 12 编译机（Ubuntu 22.04） |
| `PROXY_FAST` | `http://192.168.0.64:7892` | rock5c 代理：快、大文件可靠，但会间歇 SSL EOF |
| `PROXY_ROUTER` | `socks5://192.168.0.1:1080` | 路由器 xray：慢、egress IP 不同（下载失败时切换用） |
| `BUILD_DIR` | `/home/zhyi/build` | Ubuntu 上 Android 源码/产物根目录 |
| `GDOWN_BIN` | `~/gdown-venv/bin/gdown` | 见下文 gdown 安装 |
| `OPI03_ADDRESS` | （opi03 走 DHCP） | 板卡 IP，用 `hosts/opi03` 的 mDNS/串口获取 |

Android 源码必须**固定**在官方 18 分卷（首选）或 BPI 官方仓库（回退），两者都
不可用时不继续——不要换成来源不明的压缩包或"看起来像 H618"的其他源码树。

首选源是 Orange Pi 官方 Zero 3 Android 12 分卷。Ubuntu 构建机正好是官方手册要求
的 Ubuntu 22.04，并有 32 GiB RAM、48 GiB swap 和 500 GiB 以上可用空间。下载器
固定 Google Drive 文件 ID、官方 checksum manifest 的 SHA256，并逐片校验 MD5：

```bash
# gdown 需要单独装（文档示例路径是构建机上已建好的 venv）：
python3 -m venv ~/gdown-venv
~/gdown-venv/bin/pip install 'gdown==6.1.*'

GDOWN_BIN=~/gdown-venv/bin/gdown \
GDOWN_PROXY=http://192.168.0.64:7892 \
GDOWN_MAX_ATTEMPTS=48 \
GDOWN_RETRY_SECONDS=1800 \
  /path/to/nixos-config/tools/redroid-opi03/download-orangepi-android12.sh \
  /home/zhyi/build/OPI03-H618-Android12-official
```

`GDOWN_BIN`/`GDOWN_PROXY`/`/home/zhyi/build/`/`192.168.0.64:7892` 都是本任务
构建机的环境；换环境时按自己的代理与目录替换（见下文"环境替换清单"）。

Google 公共文件配额拒绝下载时，不要换成来源不明的压缩包。官方中文页的百度网盘
备用入口是 `https://pan.baidu.com/s/1BUsudU_XahzB_4eR3s83Ug?pwd=umdt`；把下载出的
`H618-Android12-Src.tar.gzaa` 至 `...gzar` 和 checksum manifest 放进上述输出目录的
`parts/` 后重跑同一脚本。**百度下载的文件若命名不同（如带额外前后缀），必须改名
为 `H618-Android12-Src.tar.gz` + 后缀（aa..ar）**——脚本按 manifest 里的精确
文件名匹配 `parts/`，文件名不符会被当成"本地没有"而重新走 gdown。无论取自哪个
官方入口，脚本都只在 18 片全部通过 MD5 后流式解压，并在实际 Android source root
写入固定 manifest 标记。

### 下载阶段踩过的坑

- **gdown 6.1.0 下载后不做完整性校验**（上游 issue #477）：下载完成 ≠ 文件正确。
  单靠 gdown 的进度条 100% 会放过损坏分片（本任务中 ae 分片曾下载成功但 MD5 不
  符）。下载器必须对每个分片做 `md5sum -c`，不匹配就删除重下并自动重试。
- **文件 ID 不能凭印象抄**：ae 分片曾误用 af 的 Google Drive ID，下载到的是 af
  的内容（MD5 恰好等于 manifest 里 af 的期望值），两次不同代理下到相同"错误"
  内容，靠逐片 MD5 对 manifest 才定位。脚本里 `ids[]` 与 `suffixes[]` 的下标
  必须一一对应，改脚本时严禁错位。
- **单个代理不可靠**：`192.168.0.64:7892`（rock5c）快但会间歇性 SSL EOF 中断
  大文件；`192.168.0.1:1080`（路由器 xray）慢且 egress IP 不同。可靠做法是
  下载循环里**双代理自动切换**：优先 7892，失败自动切 1080，配合
  `resume=True` 断点续传 + MD5 校验 + 有限次重试（本任务 48 次/1800s）。
- 18 片合计约 35 GiB，下载目录所在盘要有 100 GiB 以上余量（解压后源码约 78
  GiB）。

脚本最后会打印实际 source root。以该路径运行：

```bash
/path/to/nixos-config/tools/redroid-opi03/prepare-source.sh \
  /home/zhyi/build/OPI03-H618-Android12-official/extracted/H618-Android12-Src
```

若压缩包的顶层目录名不同，以脚本打印值为准，不要为了匹配本文手工移动源码。
`prepare-source.sh` 只接受上述官方 manifest 标记或下面的 BPI 固定 commit，任意
“看起来像 H618”的目录都会被拒绝。

### 同 SoC 官方回退：BPI BSP

当 Orange Pi 两个官方入口都暂时不可用时，可继续使用构建机上的
`/home/zhyi/build/BPI-H618-Android12` 做同 SoC 回退。BPI 发布物是一个巨型单体 Git
仓库，不是普通 AOSP `repo sync` 多仓库；必须检出下面的审计 commit：

```bash
git clone --filter=blob:none --no-checkout \
  https://github.com/BPI-SINOVOIP/BPI-H618-Android12.git \
  /home/zhyi/build/BPI-H618-Android12

git -C /home/zhyi/build/BPI-H618-Android12 checkout --detach \
  316cd80ca43fa17b0385eacd7f6f3652bbd66b2a
```

这个仓库约有一百万个路径。`--filter=blob:none` 节省初始传输，但某些 Git 版本在
checkout/restore 时会按很小的 promisor batch 取 blob；每批又可能跨过 `gc.auto`
阈值并触发一次 repack，表现为只展开 `art/`、CPU 长时间消耗在 `pack-objects`。
不要删除仓库或反复 checkout。先停止未完成的 checkout，然后一次枚举、分批补齐：

```bash
tools/redroid-opi03/hydrate-partial-clone.sh \
  /home/zhyi/build/BPI-H618-Android12 \
  5000

git -C /home/zhyi/build/BPI-H618-Android12 \
  restore --source=HEAD --worktree :/
git -C /home/zhyi/build/BPI-H618-Android12 status --porcelain
```

脚本把固定 HEAD 的缺失对象清单和每批完成标记保存在 `.git` 内，关闭的也仅是该
仓库的自动 GC；网络中断后重跑会跳过成功批次。最后一次完整扫描必须报告 0 个缺失
对象，再恢复工作树。不要在 hydration 完成前手工运行 `git gc`，也不要删除仍被
Git 进程写入的临时 pack。

GitHub 的单文件 100 MiB 限制导致官方仓库本身并不完整。必须再从 BPI README
指定的 Google Drive `1ye-uzyABf9LZEKp5R1f6FjARTZndTkEb` 下载 oversize files，
保持目录结构合并到构建根；不能把缺失的 blob 当成可忽略警告。完整构建根至少包含：

```bash
GDOWN_BIN=/home/zhyi/build/.venv-gdown/bin/gdown \
GDOWN_PROXY=http://192.168.0.64:7892 \
  /path/to/nixos-config/tools/redroid-opi03/download-bpi-oversize.sh \
  /home/zhyi/build/BPI-H618-oversize

rsync -a \
  /home/zhyi/build/BPI-H618-oversize/extracted/github_oversize_files/ \
  /home/zhyi/build/BPI-H618-Android12/
```

脚本校验官方 readme 给出的两段 MD5 和重组后 tarball MD5，任何一项不匹配都会在
解压前停止。合并后再运行 `prepare-source.sh`，让必需路径检查成为第二道门禁。

```text
build/make
frameworks/base
frameworks/av
frameworks/av/media/libcedarc/libcdclist.mk
hardware/aw/gpu
hardware/aw/gpu/mali-bifrost/mali-g31/arm64/lib/libGLES_mali.so
hardware/aw/gpu/mali-bifrost/mali-g31/arm64/lib64/libGLES_mali.so
hardware/aw/libcodec2
hardware/aw/libcodec2/services/Android.bp
device/softwinner/apollo
device/softwinner/apollo/common/media/codec/media_codecs_allwinner_video.xml
vendor/aw
```

Orange Pi 与 BPI 两棵源码不能互相覆盖目录。选择其中一棵后必须在同一 source root
内完成 reDroid patch、GPU/Codec2 差异审计和完整构建；更换基线必须重新审计所有
二进制 blob、Codec2 ABI 和 Kbase 用户态 ABI。不要把 Android 13/14/16 vendor 目录
混进来。

在 Android 构建机上保留代理环境，然后运行小型准备脚本：

```bash
export HTTP_PROXY=http://192.168.0.64:7892
export HTTPS_PROXY=$HTTP_PROXY
export http_proxy=$HTTP_PROXY
export https_proxy=$HTTPS_PROXY

/path/to/nixos-config/tools/redroid-opi03/prepare-source.sh \
  /home/zhyi/build/BPI-H618-Android12
```

脚本会：

1. 检查单体仓库 HEAD、H618 GPU、Codec2 和 `vendor/aw` 是否齐全；
2. 按 [`source-lock.env`](../../tools/redroid-opi03/source-lock.env) 固定 reDroid 12
   的 device/vendor/prebuilt/C2/OMX commit；
3. 严格应用 `android-12.0.0_r32` 官方 reDroid patches，任何冲突立即停止；
4. 新增 `redroid_opi03` 产品，不覆盖 `redroid_arm64` 产品；
5. 把 GPU mode 固定为 Mali/apollo，并在 media service 前把
   `debug.stagefright.ccodec` 从 reDroid 默认的 `0` 恢复为 `4`；
6. 禁用 reDroid OMX 产品路径，安装自有 primary `media_codecs.xml`，并显式
   `Include` Allwinner 视频和 Google 音视频 Codec2 列表。只把一个
   `media_codecs_allwinner_video.xml` 放进 `/vendor/etc` 不会被 Android 自动发现；
7. 继承同板 Allwinner BSP 产品使用的 `libcdclist.mk`。Codec2 服务的链接依赖不能代替
   动态 codec 插件的产品安装清单，否则常见结果是 HAL 已注册但首次解码失败；
8. 应用 CedarX/OMX 构建修复（`patches/cedarx-external-multilib.patch`、
   `patches/cedarc-library-arm64.patch`、`patches/cedarc-top-no-openmax.patch`、
   `patches/cedarc-config-board-default.patch`、
   `patches/cedarx-config-board-default.patch`、
   `patches/c2codec-config-gpu-default.patch`、
   `patches/redroid-prebuilts-omx-conditional.patch`、
   `patches/redroid-omx-conditional.patch`），并把 BSP 的
   `frameworks/av/media/libcedarc/openmax` 移出源码树。原因与契约：
   - H618 BSP 的 CedarX prebuilt（`libadecoder`、`libVE`、`liblive555` 等）在官方
     构建中只出 32 位；reDroid 的 `redroid_arm64` 主架构是 arm64，soong 会为这些
     模块生成 arm64 变体，必须在 `Android.bp` 里按 `arch: { arm/arm64 }` 指到官方
     `lib64/` 的真实 64 位 blob（`lib64/aarch64-linux-gnu/`、`toolchain-sunxi-aarch64-glibc/`、
     `lib64/alp50/`）；
   - 官方 `androideabi_64/` 目录不存在（源码打包缺陷），`libVE` 等的 arm64 srcs 需
     改指到 `toolchain-sunxi-aarch64-glibc/`；
   - 软解库（`libawvp6soft`、`libawwmv12soft`、`libawvp9soft`、`libawh265soft`）在
     源码里**不存在任何 64 位 blob**，只能 arm64-disabled 并从
     `libcdc_libs_defaults` 移除（reDroid 走 Codec2 硬解，软解路径不参与）；
   - BSP `openmax/`（`libOmxCore`、`libstagefrighthw`）与 reDroid 的 OMX prebuilt
     同名冲突；soong 扫描源码树内**所有** `Android.bp`（含 `.disabled` 目录），
     因此 openmax 必须整体移出源码根（备份在 `$SRC/../openmax-bsp-backup`，
     备份目录带 `.opi03-bsp-backup` 标记；重跑时若无该标记会拒绝替换，
     避免误删同名目录），
     并给 reDroid 侧 `redroid-prebuilts/Android.mk` 的 `libOmxCore` 与
     `hardware/redroid/omx/Android.mk` 的 `libstagefrighthw` 加
     `REDROID_DISABLE_OMX` 条件，Codec2 模式下二者都不定义；
   - `cedarx_config.go` / `cedarc_config.go` 按 vendor `board` 选平台 cflags。
     reDroid 的 arm64 BoardConfig 不会把 `TARGET_BOARD_PLATFORM` 传进 soong
     Go 插件，board 为空时两者都回退到 `default_cflags`
     （`-DCONF_ANDROID_MAJOR_VER=10`），与 Android 12 表项（`=12`）在新 clang
     `-Werror` 下冲突。两个 Go 插件已在 board 为空时默认 `apollo`
     （见 `patches/cedarc-config-board-default.patch` 与
     `patches/cedarx-config-board-default.patch`）；
   - `c2codec_config.go`、`cedarx_config.go`、`cedarc_config.go` 读取
     `gpu.public_include_file` 生成 `-DGPU_PUBLIC_INCLUDE`，reDroid arm64 下该值
     不到达 Go 插件（soong_config_add 只写 vendor 命名空间），Codec2 组件与
     CedarX 的 `#include GPU_PUBLIC_INCLUDE` 会展开为空、`hnd->share_fd` 等字段
     报未定义。三个 Go 插件在 config 为空时默认
     `mali-bifrost/gralloc/src/mali_gralloc_buffer.h`（H618 Mali-G31 gralloc 头，
     见 `patches/c2codec-config-gpu-default.patch` 与
     `patches/cedarc-config-board-default.patch`、
     `patches/cedarx-config-board-default.patch` 的 GPU_PUBLIC_INCLUDE hunk）；
   - AOSP `wifi_hal_common.cpp` 无条件引用 `DRIVER_MODULE_NAME`，该标识符只在
     `#ifdef WIFI_DRIVER_MODULE_PATH` 块内定义。reDroid 无 Wi-Fi HAL，但模块
     仍被编译；BoardConfig 里补 `WIFI_DRIVER_MODULE_NAME := dummy` 与
     `WIFI_DRIVER_MODULE_PATH := dummy`（占位，仅满足编译）。

## 长时间 Android 构建

Android 编译固定在 Ubuntu `192.168.0.60`；当前容量基线是 32 GiB RAM、48 GiB
swap、至少 500 GiB 可用磁盘（下载 35 GiB + 源码解压 78 GiB + AOSP out 约 100+ GiB
同一块盘）。该主机是 Ubuntu 22.04，正好对齐 Orange Pi 官方手册，
Orange Pi 源码优先直接按官方依赖在宿主构建。只有选择 BPI 回退源码时才使用其官方
Docker 镜像 `sinovoip/bpi-build-android-11:ubuntu20.04`；不要把这个 Android 11
构建环境误当成 Orange Pi 的官方环境，也不要使用不存在的 `latest`。若进入容器，
源码和输出目录必须 bind mount，避免把数百 GiB 输出写进 Docker overlay。

编译环境依赖（Ubuntu 22.04 实测缺项，缺了会怎样写清）：

- **JDK 11**：Android 12 必须 `openjdk-11`（soong/bootstrap 在 JDK 17 下报错）。
  `sudo apt-get install -y openjdk-11-jdk`，`JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64`。
- **libncurses5**：soong `m` 阶段大量脚本依赖 `libncurses.so.5`（22.04 默认只有
  ncurses6），缺失时报 `error while loading shared libraries: libncurses.so.5`。
  `sudo apt-get install -y libncurses5`（旧名 `libncurses5:i386` 不需要）。
- **AOSP 12 基础依赖**：除上面两项，`m systemimage` 还需以下包，缺任一会在
  envsetup/soong 早期失败：

  ```bash
  sudo apt-get install -y git-core gnupg flex bison build-essential zip curl \
    zlib1g-dev libc6-dev-i386 libncurses5 lib32ncurses5-dev x11proto-core-dev \
    libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig \
    python3 python3-venv
  ```

  （其中 `lib32ncurses5-dev`/`lib32z1-dev`/`libc6-dev-i386` 在 22.04 已改名为
  `libncurses5-dev`/`libz1g-dev`/`libc6-dev` 或移入多架构，缺报错时按提示装
  对应包即可，不必逐一对齐旧名。）
- **ccache（强烈建议）**：Android 12 的 soong 读 `CC_WRAPPER`（由 make 侧
  `ccache.mk` 设置），开启后失败重编能跳过已编译目标，大幅缩短迭代。关键坑：
  **`CCACHE_DIR` 不能放在 `/home` 下**——Android 的 sandbox（nsjail）对部分构建
  目录只读，`/home` 命中后报 `ccache: error: Failed to create ...`。设到
  `/tmp/ccache`（本任务实测可用，命中率约 30%）。启用方式：

  ```bash
  export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache \
    CCACHE_DIR=/tmp/ccache \
    CCACHE_COMPILERCHECK=content \
    CCACHE_SLOPPINESS=time_macros,include_file_mtime,file_macro \
    CCACHE_BASEDIR=/ CCACHE_CPP2=true
  ```

  改 ccache 相关 env 或换 `CCACHE_DIR` 后**必须清 soong 缓存**
  （`rm -rf out/soong out/.module_paths out/build-redroid_opi03.ninja`），否则
  ninja 不会带新的 CC_WRAPPER 重新生成。
- 改动任何 `Android.bp`/`Android.mk`/Go 插件后，同样先清上述 soong 缓存再
  `m`；soong 缓存会残留已删除目录（例如 openmax）的模块索引，不清会继续引用
  已移走的模块。

编译命令（注意：**主流程 Orange Pi 官方源在宿主 shell 直接跑，不需要容器**；
只有 BPI 回退源才进它的容器）：

```bash
# 主流程（Orange Pi 官方源，Ubuntu 宿主）：
cd "$(download-orangepi-android12.sh 打印的 source root)"
# 即 /home/zhyi/build/OPI03-H618-Android12-official/extracted/H618-Android12-Src
source build/envsetup.sh
lunch redroid_opi03-userdebug
m -j8 systemimage vendorimage
```

```bash
# BPI 回退源（用 sinovoip/bpi-build-android-11:ubuntu20.04 容器，源码须 bind
# mount 进来；该镜像是 Android 11 环境，JDK 默认 8，而 Android 12 需要 JDK 11，
# 进容器后必须补装并 export JAVA_HOME，否则 soong 会报 JDK 版本不匹配）：
docker run --rm -it -v /home/zhyi/build/BPI-H618-Android12:/src \
  sinovoip/bpi-build-android-11:ubuntu20.04 bash
# 容器内：
apt-get update && apt-get install -y openjdk-11-jdk
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 PATH=$JAVA_HOME/bin:$PATH
cd /src && source build/envsetup.sh
lunch redroid_opi03-userdebug
m -j8 systemimage vendorimage
```

如果 swap 持续增长或出现 OOM，降低到 `-j6`；禁止使用 `-j$(nproc)`。不要把这类
Android 大包交给 opi03、opi5p、pve-5700u 或 Nix 分布式构建链。目标输出必须同时
存在：

```bash
ls -lh \
  out/target/product/redroid_opi03/system.img \
  out/target/product/redroid_opi03/vendor.img
```

打包也是长任务。**前提：`m -j8 systemimage vendorimage` 已成功**，`system.img`
与 `vendor.img` 已存在于 `$ANDROID_ROOT/out/target/product/redroid_opi03/`。
脚本内部用 `sudo mount -o loop,ro` 挂载两个镜像，因此**必须以 root 或可免密
sudo 的用户运行**。参数是 Android 源码根（与编译用同一个）：

```bash
sudo /path/to/nixos-config/tools/redroid-opi03/pack-rootfs.sh \
  /home/zhyi/build/OPI03-H618-Android12-official/extracted/H618-Android12-Src
```

输出为 `opi03-redroid-android12-h618-rootfs.tar.zst`，默认写到源码根的
`$ANDROID_ROOT/opi03-redroid-android12-h618-rootfs.tar.zst`（脚本 25 行
`output=${2:-"$android_root/..."}`，可用第二个参数改路径）。
脚本遵循 reDroid 官方布局：
system image 作为容器根，vendor image 放入 `/vendor`。压缩前会挂载两个镜像并验证
Stage 1 必需的 Mali 32/64 位用户态与 Apollo gralloc，以及 `redroid.opi03.rc`；
这项门禁通过才值得把大归档传到板卡。视频解码（Allwinner Codec2 服务、`cedarc.conf`、
codec XML、H.264/H.265 动态插件）属于 Stage 2，打包时用
`--stage2-codec2` 才会强制检查：

## 导入并启动

把 rootfs 包和导入脚本复制到 opi03，在设备上执行：

```bash
sudo /path/to/import-on-opi03.sh \
  /path/to/opi03-redroid-android12-h618-rootfs.tar.zst
```

**前置**：先确认 opi03 上 `/nix/persistent` 已挂载且可写（烧录后至少启动过一次
NixOS，tmpfs `/` 下才挂上持久分区）。若在 `/nix/persistent` 不存在时导入，
脚本的 `mkdir -p /nix/persistent/...` 会建到 tmpfs 根下、重启即丢。检查：

```bash
findmnt /nix/persistent   # 有输出=已挂载；无输出=先启动一次系统
```

导入脚本创建本地镜像 `localhost/opi03-redroid:android12-h618`，确认镜像存在后才写
`/nix/persistent/var/lib/redroid-opi03/.image-ready`，随后启动容器。Podman image store
位于已持久化的 `/var/lib`，Android `/data` 单独位于 `/nix/persistent`。

ADB 暂时只绑定主机 loopback。通过 SSH 转发：

```bash
ssh -p 2222 -L 5555:127.0.0.1:5555 root@OPI03_ADDRESS
adb connect 127.0.0.1:5555
```

安全姿态（临时，验收后必须收紧）：当前容器是
`privileged=true` + `androidboot.selinux=permissive` + `ro.adb.secure=0`
（ADB 无认证）的组合，只适合在内网通过 SSH 隧道调试。**验收完成后的收尾步骤**：
把 `ro.adb.secure` 恢复为 `1`（或删除 ADB 属性），SELinux 改回
`enforcing`，并复核容器是否仍需 `privileged`（Mali/gralloc 需要哪些设备节点就
只 bind 哪些，而不是整容器提权）。在没有完成这步前，不要把这个镜像/容器暴露到
不受信任的网络。

## 实机调试记录（2026-08-04）

首次用 SD 镜像启动 Zero 3 的串口日志：

- U-Boot 2026.07 → extlinux → NixOS kernel 5.4.125（opi03-h618-redroid）加载
  initrd/DTB 正常，内核开始启动；
- 早期 5 条告警均非致命：`axp2101-pek without irq`、`sunxi-rtc reset_control
  failed`、`pinctrl_get for HDMI2.0 DDC fail`、`uart0 get regulator failed`、
  `uart0 error to get fifo size property`；
- 日志停在 `uart uart0` 两条告警之后（loglevel=4 过滤了后续），疑似 sunxi-uart
  驱动 probe 阶段。

已做：`loglevel=8 ignore_loglevel` 加入 kernelParams（提交 `11de0cfd`）待重建镜像
确认卡点。**镜像重建被 aarch64 btrfs 打包阻塞**：`nix-btrfs-fs.img.zst` 的
`system=aarch64-linux`，调度到 opi5p（唯一 aarch64 builder）时其 `nix-daemon`
inactive（socket 拒绝连接，`nix-builder` 用户无权启动）；改用 ml-builder 本机
binfmt（`--builders ''`）时打包脚本的 `unshare --user --map-root-user` 在 qemu
仿真下 `Invalid argument`。两个方向都需要环境修复（启动 opi5p nix-daemon，或改
打包逻辑），尚未完成。

## 验收：Stage 1 只有 GPU 门禁，Stage 2 才加 VPU

Stage 1 静态检查（GPU-only）：

```bash
sudo opi03-redroid-check
```

注意：脚本默认还会一并校验**主机四个设备节点**（`/dev/mali0`、`/dev/cedar_dev`、
`/dev/ion`、`/dev/g2d`，见"vendor kernel 启动后先验证主机 ABI"）与
`debug.stagefright.ccodec=4` 属性。这些属于"宿主前置条件"而不是 Stage 1 的 GPU
门禁，但缺任一节点时 Mali 正常也会 FAIL——先保证内核侧节点齐全再跑验收。

必须全部满足：

- `ro.hardware.egl=mali`；
- `ro.hardware.gralloc=apollo`；
- `ro.hardware.vulkan=apollo`；
- SurfaceFlinger renderer 包含 Mali，且不含 SwiftShader、ANGLE、Pastel、llvmpipe。

只有 SurfaceFlinger 的 Mali renderer 证据成立，Stage 1 才算完成——这是当前唯一
验收目标。Codec2/视频硬解（`android.hardware.media.aw.c2` 进程与 HAL、
`stagefright -i` 枚举 `c2.allwinner.*`、Cedar 中断增长）属于 Stage 2，用
`sudo opi03-redroid-check --stage2-codec2` 才会执行；Stage 2 的完整门禁（生成
H.264 测试流、`decode-test` 强制硬件解码、Cedar/VE 中断计数增长、logcat
Allwinner/Cedar 证据）保持不变：

```bash
tools/redroid-opi03/generate-test-video.sh /tmp/opi03-h264-test.mp4
sudo opi03-redroid-check --stage2-codec2 redroid decode-test /tmp/opi03-h264-test.mp4
```

交互排障时仍可运行：

```bash
sudo opi03-redroid-check redroid watch-vpu
```

播放期间至少取得一项动态证据：

- Cedar/VE 对应中断计数持续增加；或
- Android Codec2 进程持续打开 `/dev/cedar_dev`。

只有 Stage 1 的 Mali renderer 与 Stage 2 的 Cedar 动态证据同时成立，才可以把本
任务标为完成。仅有容器 `sys.boot_completed=1`、codec XML 或节点存在都不算硬件
加速验收。

## 已封住的坑

- reDroid `gpu_config.sh` 默认 `guest` 会覆盖为 ANGLE/SwiftShader；专用
  `androidboot.redroid_gpu_mode=opi03` 分支阻止覆盖。
- reDroid common rc 默认 `debug.stagefright.ccodec=0`；opi03 在 `early-boot`
  恢复为 `4`。
- 主机没有本地 image 时不会访问 Docker Hub，也不会让激活失败。
- ADB 不发布到 `0.0.0.0`；首次 bring-up 使用 SSH tunnel。
- Android 32 位 ABI仍由 `redroid_arm64` BoardConfig 保留；没有改成 64-only 产品。
- `CMA=256 MiB` 同时写入 kernel config 和命令行，避免图形/视频连续内存不足被误判
  为 userspace 故障。
- BPI BSP 是单体 Git 仓库；reDroid 官方 patch 的项目相对路径通过 `git apply
  --directory` 映射到外层仓库，并先做 reverse-check 保证脚本可重复运行。
- BPI 的 blobless partial clone 不能依赖逐文件 lazy checkout；先关闭仓库级自动
  GC，再用 `hydrate-partial-clone.sh` 一次枚举和可恢复分批抓取，否则会不断 repack。
- Stage 2：Android 12 不会扫描所有 `media_codecs*.xml`；专用 primary XML 的显式 Include
  是 Allwinner Codec2 被发现的必要条件。
- H618 BSP 的 `libstagefright_foundation` 相对 AOSP ABI dump 扩展了 `ParsedMessage`
  （`GetAttribute`/`GetInt32Attribute`），`header-abi-diff` 在 arm64 vendor 变体报
  ABI EXTENDING。容器内全同源编译、运行时自洽，跳过编译期检查无影响；模块
  Android.bp 已设 `header_abi_checker: { enabled: false }`
  （见 `patches/stagefright-foundation-abi-check.patch`）。
- H618 是 `ARCH_SUN50IW9`，deinterlacer 必须选择 `SUNXI_DI_V3X`（DI300）。只启用
  `SUNXI_DI` 而不选择 V1XX/V2X/V3X，会生成一个没有组成对象的
  `deinterlace.o`，Kbuild 最终报 `No rule to make target`；不能通过关闭 DI 来掩盖。
- vendor MMC 子驱动全部是 `default y`，但 H618 的 SD 节点使用 v4p1x，v4p6x eMMC
  节点复用 v4p5x；必须像官方 `sun50iw9p1smp_h618_android_defconfig` 一样禁用
  `MMC_SUNXI_V4P10X`。否则会编译无关代际，并因其引用私有 pinctrl 类型而失败。
- Orange Pi uwe5622 顶层 Makefile 使用 `/bin/pwd` 计算 include path，传统 Ubuntu
  构建能通过，Nix sandbox 没有 `/bin`。在尚未同时打包 firmware、定制
  `hciattach` 和启动服务前，按生成器关闭整个 `SPARD_WLAN_SUPPORT` 依赖链；不能
  只修 Makefile 后就把 Wi-Fi/蓝牙标为可用。
- vendor 5.4 没有主线 MPTCP。板级必须同步移除 MPTCP sysctl、daemon 和 socket
  protocol，不能只把 `mptcp` 从 `boot.kernelModules` 列表删掉。
- 官方 H618 Android defconfig 默认开启 `CONFIG_SUNXI_NAND`，会把
  `drivers/block/../../modules/nand` 这个 Longan out-of-tree 驱动拉进
  modbuiltin。它的 Makefile 用 `$(LICHEE_KDIR)` 推导 `KERNEL_SRC_DIR`，Nix
  sandbox 没有该变量，构建直接报 `KERNEL_SRC_DIR not setup`。Zero 3 从
  microSD/eMMC 经 MMC 启动，不存在 raw NAND 设备，因此生成器禁用
  `SUNXI_NAND`（连带 `SUNXI_RAWNAND`）并在断言里要求两者都必须关闭。
  `modules/gpu` 是 Longan 外置 Mali，未被 kernel 构建引用，无需处理。
- vendor 5.4 的 `mali_kbase.ko`（`pkgs/opi03-mali-kbase`）构建有两个独立坑：
  1. **不能开 `CONFIG_MALI_DMA_FENCE`**：该选项引用 `linux/reservation.h`，5.4
     已把该头改名 `dma-resv.h`（上游只保留别名到 4.x），编译直接
     `No such file or directory`。官方默认就是 `n`，保持关闭即可。
  2. **不能走 `modules_install` 装进 lib/modules 树**：会递归进
     `modules/gpu/mali-bifrost` 再构建一份；installPhase 应直接把构建出的
     `mali_kbase.ko` 放到 `$out/lib/modules/5.4.125/extra/`，由
     `boot.extraModulePackages` 挂载。
- **Google 会话 cookie 曾误提交进 git**（`bc9d625a` 引入 `.reasonix/` 附件，
  `12e5876c` 移除并补 `.gitignore`）。下载脚本用 gdown 时把 cookie 放在
  `$HOME/.cache/gdown/`，**绝不能把含 SID/HSID/SSID/APISID 的文件 `git add`
  进仓库**；`.reasonix/`、`*.cookie*`、`.tmp-*` 都应忽略。cookie 一旦入库，
  仅删当前树不够——历史 blob 仍在，需要 `git filter-repo`（或
  `filter-branch`）清洗并 force-push，且用户必须去 Google 安全中心吊销该会话。
- mac 上 `diskutil list external physical` 先确认盘符再烧录；`dd of=/dev/rdisk4`
  （rdisk 裸设备，比 `/dev/disk4` 快）；写完 `sync`/`conv=fsync` 后 eject。
  FAT32 boot 分区被 mac 以只读挂载（fskit），不要指望直接改卡上
  `/extlinux/extlinux.conf` 调参数。
