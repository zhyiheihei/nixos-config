# dragon-q8b NixOS 适配进度文档

> 本文档用于会话崩溃后快速接手。最后更新：2026-08-24 20:40

## 主机基本信息

| 项目 | 值 |
| --- | --- |
| 主机名 | dragon-q8b |
| 硬件 | Radxa Dragon Q8B（Qualcomm SC8280XP / Snapdragon 8cx Gen 3） |
| 架构 | aarch64-linux |
| 引导方式 | UEFI firmware + systemd-boot（不是 extlinux/u-boot，区别于其他 ARM 板） |
| 内网 IP | 192.168.0.66 |
| host.nix index | 129 |
| 角色 | server + lan-access |

## 引导特征（关键差异）

dragon-q8b 是 UEFI 板子，UEFI firmware 自带 DTB 传递给内核，不需要 dtb= 参数。
用 systemd-boot 引导，不用 GRUB，不用 extlinux。configuration.nix 中：
- `boot.loader.grub.enable = lib.mkForce false`
- `boot.loader.systemd-boot.enable = true`
- `boot.loader.efi.canTouchEfiVariables = lib.mkForce true`

kernelParams: `clk_ignore_unused pd_ignore_unused`

## 磁盘分区方案（hardware-configuration.nix）

当前 UUID 对应的是 SD 卡上的分区布局（Btrfs 多 subvol）：

| 挂载点 | 设备 | FS | subvol | 备注 |
| --- | --- | --- | --- | --- |
| /boot | /dev/disk/by-uuid/DB72-1C49 | vfat | - | EFI 分区 |
| /nix | /dev/disk/by-uuid/e9ab9a38-49d2-48c9-a2b3-85dce405e99b | btrfs | nix | neededForBoot |
| /nix/persistent | 同上 | btrfs | persistent | neededForBoot |
| /nix/persistent/home | 同上 | btrfs | home | |

导入 `nixos/hardware/disable-watchdog.nix`。

## 内核包

### 包定义

`pkgs/sc8280xp-kernel/default.nix`：
- 从 Armbian 的 radxa-dragon-q8b.conf + sc8280xp.conf 家族配置照搬
- 源码：`github.com/radxa/kernel`，分支 `linux-7.0.11`，pin 到 commit `4a7a039590c7185ed9c53453b163806311799eed`
- modDirVersion = `7.0.11`
- 使用 `crossPkgs.linuxManualConfig`（x86_64 交叉编译 aarch64）
- vendored config：`sc8280xp_vendor_config`（4231 行）+ `sc8280xp_vendor_config.nix`（4154 行 attrset）
- `olddefconfig` 在 `oldconfig` 之前运行，避免交互式提示卡死
- derivation name 被 override 为 `"k"`（避免 Armbian extlinux/grub 菜单标签截断长名）

### flake.nix 中的导出

```nix
sc8280xp-kernel = inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/sc8280xp-kernel {
  nixpkgsPath = inputs.nixpkgs.outPath;
};
```

位于 `flake.nix` 约 362 行，在 `packages.x86_64-linux` 里，和 opi5p-kernel、rock5c-kernel 同级。

## ml-builder 上的未 push 提交

> **已解决**：ml-builder 的 5 个本地提交已同步到 origin，master 已全部对齐。
> 通过 format-patch 生成、本地 git am 重建，逐文件 diff 确认一致后 push，
> ml-builder `git pull --ff-only` 对齐到 origin（当前 HEAD = 2e02b886）。

历史上这些提交的改动范围：
1. `pkgs/sc8280xp-kernel/` — 新增内核包（default.nix + vendor config + config attrset）
2. `flake.nix` — 添加 sc8280xp-kernel 导出
3. `hosts/ml-builder/configuration.nix` — 注释掉 hydra（内存压力导致构建时冻机）
4. `nixos/hardware/lvm.nix` — initrd 加载 dm-thin-pool 模块（PVE thin pool 修复，和 q8b 无关）

## 已解决的构建阻塞

### 1. 内存不足（j28 OOM）→ 加 64GiB 磁盘 swap

- 根因：ml-builder 只有 56GiB 物理内存，zram 54.6G 是压缩内存，j28 并发 GCC
  吃光物理内存时 zram 来不及压缩就 OOM 段错误（GCC internal compiler error:
  Segmentation fault）。
- 解决：在 `hosts/ml-builder/configuration.nix` 加 `swapDevices` 64GiB 磁盘
  swap 文件（/nix/swapfile），已 push（commit 9b70e40）。
- 生效：`nixos-rebuild switch` 后 swap 生效。当前：zram 54.6G + /nix/swapfile 64G
  = 118G 总交换。j28 不再 OOM。
- 注意：这是 ml-builder 上这个任务产生的第 1 个新提交，master 对齐后它在历史里。

### 2. GCC 15 类型不兼容 → 改用 GCC 14 交叉编译

- 根因：内核 7.0.11 用 Nixpkgs 默认 GCC 15.3 交叉编译报错：
  `cred.h:174 cap_issubset(cred->cap_ambient)` → `incompatible type for argument 1`。
- Armbian 用 Ubuntu GCC 11.4 编译正常。Nixpkgs 已移除 GCC 11/12。
- 尝试：`gcc13Stdenv` → 交叉编译器本身构建失败；改为 `gcc14Stdenv`（当前）。
- 改在 `pkgs/sc8280xp-kernel/default.nix`，给 `linuxManualConfig` 传 `stdenv = crossPkgs.gcc14Stdenv`。

## 当前构建状态

### 正在构建（GCC 14 交叉编译）

在 ml-builder 上用 tmux 虚拟终端运行：

```bash
cd /nix/src/nixos-config && tmux new-session -d -s q8b-kernel \
  "nix build .#sc8280xp-kernel --no-link --print-out-paths --max-jobs 28 --cores 28 2>&1 | tee /tmp/q8b-kernel-build.log"
```

- tmux session: `q8b-kernel`
- 构建日志: `/tmp/q8b-kernel-build.log`
- 状态：正在构建 GCC 14.4 交叉编译器 + stdenv + 内核（session 还在，make 进程 >0）
- 如果成功会输出 /nix/store/xxx-k-aarch64-unknown-linux-gnu 路径

### 接手后检查构建状态的命令

```bash
ssh -A ml-builder 'tmux ls'
ssh -A ml-builder 'tail -10 /tmp/q8b-kernel-build.log'
ssh -A ml-builder 'pgrep -c make'
# 构建成功看 store path，失败看 Error
```

注意连接要用 `ssh -A ml-builder`（agent forwarding），因为 ml-builder 需要
本地 Mac 的 SSH key 才有 GitHub 访问权限，否则 git fetch/pull 报 Permission denied。

## 待完成步骤

### 1. 等内核构建完成

构建成功后 `nix build` 会输出 store path。验证：

```bash
ssh ml-builder 'cat /tmp/q8b-kernel-build.log | tail -5'
# 应该看到一行 /nix/store/xxx-k-aarch64-unknown-linux-gnu 路径
```

### 2. 将内核包接入 dragon-q8b 的 NixOS 配置

当前 `hosts/dragon-q8b/configuration.nix` 还没有引用 sc8280xp-kernel。需要类似 rock5c 的方式：

```nix
# 在 configuration.nix 中（或新建 nixos/hardware/dragon-q8b/default.nix）
lantian.kernel = lib.mkForce self.packages.x86_64-linux.sc8280xp-kernel;
```

参考其他 ARM 板的做法（如 rock5c、lubancat-1）：
- `nixos/hardware/rock-5c/default.nix` 第 88 行：`lantian.kernel = lib.mkForce rock5cKernel;`
- 需要考虑是否创建 `nixos/hardware/dragon-q8b/default.nix` 硬件模块

### 3. 构建 dragon-q8b 系统包

```bash
# 在 ml-builder 上
cd /nix/src/nixos-config
nix build .#nixosConfigurations.dragon-q8b.config.system.build.toplevel --max-jobs 28 --cores 28
```

### 4. 构建 SD 卡镜像

dragon-q8b 是 UEFI 板子，不需要 u-boot/extlinux。需要确认 SD 卡镜像方案：

- 现有 ARM 板都用 `nixos/modules/installer/sd-card/sd-image.nix` + extlinux + u-boot dd
- dragon-q8b 用 systemd-boot + EFI，分区表不同（需要 EFI 分区而非 extlinux firmware 分区）
- 可能需要参考 nixos/modules/installer/sd-card/sd-image.nix 但用 EFI 分区布局
- 或者直接手动分区 SD 卡、安装 systemd-boot、复制 NixOS closure

**这是需要解决的关键问题：现有 sdImage 框架是给 extlinux/u-boot 板设计的，UEFI 板需要不同的镜像方案。**

### 5. 刷入 SD 卡验证

在 SD 卡上验证系统可启动、网络可达、SSH 可连。

### 6. 刷入 NVMe 正式使用

SD 卡验证通过后，将系统刷入 NVMe 正式使用。

## 交接注意事项（本次会话新增）

1. **连 ml-builder 必须 `ssh -A`**（agent forwarding），否则 git 同步失败。
2. **GCC 版本链**：默认 GCC 15 → 类型不兼容；GCC 13 → 交叉编译器构建失败；
   当前 GCC 14（gcc14Stdenv）正在构建。若 GCC 14 仍编译失败，需考虑其他方案。
3. **swap 已固化**在 ml-builder 配置里，重启不丢，118G 总交换，j28 不会 OOM。
4. **git 同步铁律**：本地改 → push origin → ml-builder `git pull --ff-only`。
   ml-builder 不能直接 push（无权限），需通过本地中转。

## 参考的其他 ARM 板硬件模块

| 板子 | 硬件模块 | 引导方式 | 内核来源 |
| --- | --- | --- | --- |
| rock-5c (RK3588S) | nixos/hardware/rock-5c/ | extlinux + Armbian U-Boot dd | self.packages.x86_64-linux.rock5c-kernel |
| lubancat-1 (RK3566) | nixos/hardware/lubancat-1/ | extlinux + U-Boot dd | 共享 nanopi-r5c 内核 config |
| nanopi-r5c (RK3568) | nixos/hardware/nanopi-r5c/ | extlinux + U-Boot dd | nixpkgs vendor kernel |
| orangepi-5-plus (RK3588) | nixos/hardware/orangepi-5-plus/ | extlinux + U-Boot dd | vendor kernel |
| orangepi-zero3 (RK3588S) | nixos/hardware/orangepi-zero3/ | extlinux + U-Boot dd | vendor kernel |
| hinlink-h28k (RK3568) | nixos/hardware/hinlink-h28k/ | extlinux + U-Boot dd | vendor kernel |
| taishanpi | nixos/hardware/taishanpi/ | extlinux + U-Boot dd | vendor kernel |
| **dragon-q8b (SC8280XP)** | **待创建** | **systemd-boot + EFI** | **self.packages.x86_64-linux.sc8280xp-kernel** |

## 配置参考来源

所有配置参考 Armbian 的 radxa-dragon-q8b 板配置：
- `config/boards/radxa-dragon-q8b.conf`
- `config/sources/families/sc8280xp.conf`
- `config/kernel/linux-sc8280xp-vendor.config`

Armbian 支持我们就支持，Armbian 不支持的暂不管。