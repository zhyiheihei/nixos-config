# raspberry-pi-nix 学习笔记

## 1. 是什么

`raspberry-pi-nix` 是一个 **Raspberry Pi 的 NixOS flake**（Nix，
MIT，311 star，已归档），目标是把内核、设备树、bootloader、固件和
`config.txt` 全部用 Nix 声明出来，并能直接产出可刷写 SD 卡的镜像。
它支持 `bcm2711`（Pi 4）和 `bcm2712`（Pi 5）两代 board，master 是
开发分支。

设计上的三个卖点：

1. 用与官方固件兼容的方式配置内核、设备树和 bootloader；
2. 提供类似树莓派 `config.txt` 的 Nix 接口；
3. 不需要先走安装媒介，`nix build` 直接得到 SD 卡镜像。

## 2. 核心模块

flake 输出 `nixosModules.raspberry-pi` 和 `nixosModules.sd-image`，
还带 `rpi-example` 示例配置供 CI 构建：

- `rpi/default.nix`：选择内核版本和 board，设置串口、initrd 模块、
  kernel params、默认 `config.txt`，并生成一个在系统切换时原地更新
  固件分区的 service；
- `rpi/config.nix`：实现 `config.txt` 的 Nix DSL；
- `rpi/i2c.nix`：`hardware.raspberry-pi.i2c.enable` 快捷开关；
- `sd-image/`：直接产出 MBR + FAT `FIRMWARE` + ext4 `NIXOS_SD`
  分区布局的 SD 镜像。

## 3. `config.txt` DSL

`hardware.raspberry-pi.config` 按 `[board]` 分区配置：

- `options`：普通固件选项，如 `arm_boost=1`；
- `base-dt-params`：生成 `dtparam=...`；
- `dt-overlays`：生成 `dtoverlay=...` 以及参数，并自动追加一行空
  `dtoverlay=` 结束 overlay。

每个键都有 `enable`（是否写入）和 `value`（值），生成结果可在
`config.hardware.raspberry-pi.config-output` 预览。README 里给了
`[all]` / `[cm4]` / `[pi4]` 的完整示例，`mkDefault` 负责默认值和
用户覆盖的优先级。

## 4. 固件分区与 bootloader

树莓派闭源固件会在交内核前对设备树做不少未文档化的修改，所以这个
项目刻意**使用固件已经处理过的设备树**，而不是让 NixOS 直接传
FDTDIR。硬件检测（相机、显示器、具体 Pi 型号）都交给固件在启动时
自动完成。

固件分区有两种启动方式：

- 默认不用 u-boot：内核 `kernel.img`、initrd、`cmdline.txt` 直接放进
  固件分区，`initScript` 加载；
- 开 `raspberry-pi-nix.uboot.enable`：固件先启动
  `u-boot-rpi-arm64.bin`，u-boot 再去 `NIXOS_SD` 分区找 extlinux
  config；这样支持 CM4 等更特殊的启动路径。

`raspberry-pi-firmware-migrate.service` 是 oneshot，用
`MountImages=` 挂载固件分区，然后按 store path 版本号增量拷贝
内核、initrd、`cmdline.txt`、`config.txt` 和 `raspberrypifw`
固件。这样每次 `nixos-rebuild switch` 后固件分区自动跟上新配置，
不需要手动重刷。

## 5. SD 镜像

`sd-image.nix` 从 nixpkgs 安装器代码借来并裁剪：

- 镜像按内容大小自动计算，FIRMWARE 默认 128 MiB；
- rootfs 用 make-ext4-fs 生成，再和 FAT 分区拼进一个 MBR 镜像；
- 首启 `postBootCommands` 自动扩容根分区、`resize2fs`，并加载初始
  Nix store 注册信息；
- u-boot 模式会在根分区生成 extlinux，非 u-boot 模式写一个
  `sbin/init` 包装脚本执行 system closure。

`overlays/core` 提供：

- `pkgs.rpi-kernels.<version>.<board>`：从
  `raspberrypi/linux` 各 stable 分支构建，`buildLinux` 用
  `bcm2711_defconfig` / `bcm2712_defconfig`，并关掉会导致 VC4
  KUnit 测试在启动时崩溃的 `KUNIT`；
- `raspberrypifw`：覆盖为仓库 pin 的树莓派固件源；
- `uboot-rpi-arm64`；
- Wireless/Bluetooth 固件（非自由许可证，但归到
  `hardware.enableRedistributableFirmware`）。

## 6. CI 与工程习惯

- GitHub Actions 只有 weekly `update-flake-lock`，用
  DeterminateSystems action 自动更新 flake lock 并开 PR；
- flake 的 `checks.aarch64-linux` 就是全部 packages，`rpi-example`
  SD 镜像由 CI 构建，并把内核推到 nix-community cachix，避免用户
  每次自己编 linux；
- 内核版本、固件、libcamera/rpicam 等全部作为 `flake = false`
  input 锁在仓库里，保证可复现。

## 7. 对我们仓库的启发

- 我们不跑树莓派主机，但“让固件处理硬件探测、Nix 只管内核和启动
  配置”的边界划分，对嵌入式 NixOS 很有参考价值；
- 用 store path 作为版本号做“增量迁移到不可声明分区”，比每次都
  全量覆盖更稳，也适合我们的 `/boot` 固件类文件；
- `config.txt` 这种平台 DSL 用 Nix 子模块包一层，再生成真实配置
  文件，正是我们仓库大量做配置生成时的惯用模式。

## 8. 参考

- [raspberry-pi-nix](https://github.com/nix-community/raspberry-pi-nix)
- [树莓派 config.txt 文档](https://www.raspberrypi.com/documentation/computers/config_txt.html)
