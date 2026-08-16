# nixos-avf 学习笔记

## 1. 是什么

`nixos-avf` 让 NixOS 跑在 Android 的 **AVF（Android Virtualization
Framework）** 里，mkg20001 维护，366 star，GPL-3.0。Android 15 QPR2
起系统自带的 Terminal App 就基于 AVF，这个仓库提供能在里面直接
运行的 NixOS 镜像。配套的安装 App 已单独学过（`nixos-avf-image-app`）。

## 2. Flake 结构

`flake.nix` 输入固定到 `nixpkgs/nixos-25.11`，输出三件事：

- `nixosModules.avf`：真正可用的 NixOS 虚拟机模块；
- `nixosModules.avfDebug`：调试模块（串口日志、无密码 root、getty
  autologin）；
- `nixosModules.avfInitial`：首次启动镜像的初始化模块；
- `packages.initialImage`：产出 AVF 安装包。

`initial.nix` 是老的 `nix-build` 入口，通过 `CROSS_SYSTEM`
环境变量在 x86_64 上交叉构建 aarch64 镜像。

## 3. AVF 模块做了什么

`avf/default.nix` 是整个仓库的核心，值得拆开看：

- 用 `pkgs.formats.json` 生成 `vm_config.json`，虚拟机名固定为
  `debian`（Terminal App 的显示输出依赖这个名字），磁盘是 ESP +
  NixOS 根分区，还有 virtiofs 的 `/mnt/shared` 和 `/mnt/internal`；
- 内核固定 6.1，叠加 AOSP Virtualization 仓库的两个补丁：
  `arm64-balloon.patch`（内存气球）和 `virtual-cpufreq.patch`
  （虚拟 CPU 频率）；
- 从 `android.googlesource.com` 的 `android-16.0.0_r3` fetch 来
  `forwarder_guest`、`shutdown_runner`、`storage_balloon_agent`
  三个 Rust 客户机服务，用 `rustPlatform.buildRustPackage` + 仓库内
  `Cargo.lock` 构建，再以 systemd service 方式运行；
- ttyd 提供 Web 终端（`_http._tcp` 7681 端口），avahi 发布服务，
  而且显式关掉 avahi IPv6，因为 Terminal 有时只发现 IPv6 地址再只
  放行该地址给 gRPC（README 里的 issue #5）；
- 图形默认开启：Weston + gfxstream/Zink + seatd，用 `VK_ICD_FILENAMES`
  和 `MESA_LOADER_DRIVER_OVERRIDE=zink` 走无硬件的虚拟 GPU；
- 网络走 systemd-networkd，开 nftables，只放行 7681；
- zram-generator 用 zstd 压缩，内存不足时可缓解崩溃。

## 4. 镜像构建流程

`avf/finish.nix` 把标准 NixOS disk image 改造成 AVF 需要的
`tar.gz` 载荷：

1. `sfdisk` 读分区偏移，把 raw disk 切成 `efi_part` 和 `root_part`；
2. `tune2fs -O ^orphan_file` 关掉 Android e2fsck 不认的特性；
3. 把 `vm_config.json` 里的分区 GUID 占位符替换成真实 UUID；
4. 连同 `build_id`、README、`replace.sh` 一起打进 tar。

`initial/default.nix` 负责首次开机：复制 `/etc` 文件、建目录、写入
默认 `/etc/nixos/configuration.nix`，并用 `nix-channel` 加
`nixos` 和 `nixos-avf` 两个频道，后续更新直接 `nixos-rebuild`。
镜像里还内置 `replace.sh`：它分两步把新 root 分区写进现有 VM，绕开
crosvm 对 virtiofs 大写入不稳定的问题，并自动改 `vm_config.json`
加一个 `nixos_root` 分区用于替换。

## 5. CI 与发布

GitHub Actions 有两套：

- `build.yml`：每次 push/PR 都从 `NixOS/infra/channels.nix` 动态生成
  `nixos-*` 矩阵，在 nscloud 的 aarch64/x86_64 上跑测试构建；
- `image.yml`：每天 + 手动 + trunk push 时构建正式镜像，上传到
  GitHub Releases；release 同时充当频道服务器，供首次安装和后续
  `nix-channel` 使用。

发布产物有 `image-*.tar.gz`、`nixos-channel-*.tar.xz` 和
`avf-channel-*.tar.xz`，构建走 nix-community cachix。

## 6. 对我们仓库的启发

- 我们不做 AVF 客户机，但“虚拟化平台自带启动器 + Web 终端 +
  avahi 发现”的组合值得参考；
- 把标准 disk image 拆分区、替换 GUID、关旧文件系统特性再打包，
  是“给不标准平台做安装包”的实用例子；
- 用 GitHub Releases 当包频道，省掉自建 HTTP 服务器，和我们的
  release 流程思路一致。

## 7. 参考

- [nixos-avf](https://github.com/nix-community/nixos-avf)
- [nixos-avf-image-app](https://github.com/nix-community/nixos-avf-image-app)
