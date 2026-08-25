# dragon-q8b NixOS 适配进度文档

> 本文档用于会话崩溃后快速接手。最后更新：2026-08-25 21:15

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

### 3. pahole 段错误 → 根因是 vendored config 多了 CONFIG_DEBUG_INFO_BTF

- 现象：GCC 14 第二次构建，modules 阶段 `gen-btf.sh: line 70: Segmentation fault (core dumped) ${PAHOLE} -J ...`（Error 139）。
- 根因：pahole 处理交叉编译的 aarch64 .ko 时段错误。对照 Radxa 官方 defconfig
  `radxa_qcom_7_0_defconfig` 发现：官方**完全没有 `CONFIG_DEBUG_INFO_BTF`**（只有
  `CONFIG_DEBUG_INFO_DWARF5=y`），而我的 vendored config `sc8280xp_vendor_config`
  第 4189 行多了 `CONFIG_DEBUG_INFO_BTF=y`（来自 Armbian 的
  `linux-sc8280xp-vendor.config` 第 4171 行）——这就是 pahole 段错误的根源。
- pahole 版本：nixpkgs 1.31（段错误），Ubuntu 机器 1.25。
- 待办：从 vendored config 移除 `CONFIG_DEBUG_INFO_BTF=y`（回归 Radxa 官方配置），重新构建。

## 调研发现（Radxa 官方 vs Armbian 编译方式）

> 用户要求认真研究 Armbian 官方版本和 Radxa 官方文档
> （https://docs.radxa.com/dragon/q8b），理解正确编译方式后再动手。

### 内核源码：Radxa 官方用 linux-qcom，不是 Armbian 的 radxa/kernel

- **Radxa 官方内核源码是 `radxa-pkg/linux-qcom`**（mainline qcom 分支），
  **不是** Armbian 用的 `radxa/kernel`（vendor 分支）。这是"抄作业抄不明白"的核心。
- 当前 `pkgs/sc8280xp-kernel` 用的是 Armbian 的 `radxa/kernel` linux-7.0.11 vendor 分支。
- 若后续要完全对齐 Radxa 官方，需考虑换到 `radxa-pkg/linux-qcom` 源码 + 官方 defconfig。

### 编译方式：Radxa 官方用 devenv (Nix dev container) + make deb

- Radxa 官方用 **devenv（Nix dev container）** + `make deb` 编译内核。
- 基础镜像 Debian bookworm，用 `crossbuild-essential-arm64`（GCC 12）。
- Armbian 用系统包 `aarch64-linux-gnu-gcc`（Ubuntu GCC 11.4）。
- 官方 defconfig：`radxa_qcom_7_0_defconfig`（3778 行，3660 CONFIG 条目）。
  - `CONFIG_EFI_ZBOOT=y`（第 778 行）
  - `CONFIG_DEBUG_INFO_DWARF5=y`，**无 `CONFIG_DEBUG_INFO_BTF`**
  - `CONFIG_EFIVAR_FS=y`（第 3533 行，systemd-boot/EFI 需要）
  - `CONFIG_ARCH_QCOM=y`，q8b dtb 会编译（`sc8280xp-radxa-dragon-q8b.dtb`）
- 对比：Armbian `sc8280xp_vendor_config`（4231 行，4152 CONFIG 条目）多出
  `CONFIG_DEBUG_INFO_BTF=y`（第 4189 行）。

### Armbian debs 里没有 sc8280xp 构建产物

- 检查 Armbian debs：只有 rockchip64/rk35xx，**没有 sc8280xp 构建产物**。
- 说明 Armbian 在这台机器上还没成功构建过 sc8280xp 内核，不能直接抄它的产物。

### 结论

- 当前用 Armbian vendored config 构建，需先移除 `CONFIG_DEBUG_INFO_BTF=y` 修复 pahole 段错误。
- 若后续要完全对齐 Radxa 官方，可考虑换 `radxa-pkg/linux-qcom` 源码 + `radxa_qcom_7_0_defconfig`
  （defconfig 格式，需在 configurePhase 里 `make radxa_qcom_7_0_defconfig` 展开）。

## 当前构建状态

### ✅ 内核交叉编译成功（2026-08-24 21:33）

移除 `CONFIG_DEBUG_INFO_BTF` 后重新构建成功，全程无 Error/段错误，干净输出 store path：

- **out**：`/nix/store/spnibagqyg904r3ycips3rh3k4cgd2nr-k-aarch64-unknown-linux-gnu`
  - `vmlinuz.efi`（15MB，UEFI 启动镜像）
  - `System.map`
  - `dtbs/qcom/sc8280xp-radxa-dragon-q8b.dtb`（+ `-el2.dtb`）
- **modules**：`/nix/store/k5srn51b4f5l2knvxk3bsm9wfm47hvl8-k-aarch64-unknown-linux-gnu-modules`
  - 3822 个 `.ko.zst` 模块 + 完整模块元数据（modules.dep/builtin/alias/symbols）
  - 含 tc956x 网卡驱动（`dwmac-tc956x.ko.zst`）、wireguard、tls

derivation 有三个 output：`out`（内核镜像）、`dev`（编译开发树）、`modules`（内核模块）。
注意 `--print-out-paths` 只打印主 output `out`，模块在单独 output 里。

### ✅ 内核接入 NixOS 配置（2026-08-24 21:40）

新建 `nixos/hardware/dragon-q8b/default.nix` 硬件模块，同 rock5c/opi5p 边界：

- 引入 `self.packages.x86_64-linux.sc8280xp-kernel`（cross vendor 内核）
- `extraModulePackages = lib.mkForce [ ]`（out-of-tree 模块无法对 cross 内核构建）
- `kernelModules` 保留 server 角色所需 `tls`/`wireguard`
- 关闭 `fileSystems."/run/nullfs".enable`
- 主机 `hosts/dragon-q8b/hardware-configuration.nix` import 该模块

UEFI 板走 systemd-boot，boot 配置已在 `configuration.nix` 设好，硬件模块不重复设置。
验证：`nix eval .#nixosConfigurations.dragon-q8b.config.boot.kernelPackages.kernel.version`
返回 `7.0.11-armbian`。

### ✅ dragon-q8b toplevel 构建成功（2026-08-24 22:22）

store path：`/nix/store/hb0b9galapx9mmd8g0ba6wx1d6myr39y-nixos-system-dragon-q8b-26.11pre-git`

vendor 内核正确打包进系统（kernel → `/nix/store/86jz1hw83...-k-aarch64-unknown-linux-gnu`，
含 MMAP 配置版本）。initrd、boot.json、dtbs 齐全。

构建过程中解决三个阻塞点（见下方「toplevel 构建阻塞」）。

## toplevel 构建阻塞（均已解决）

### 1. systemd-boot 断言：This kernel does not support the EFI boot stub

- 现象：toplevel 求值失败，`Failed assertions: This kernel does not support the EFI boot stub`。
- 根因：nixpkgs `systemd-boot.nix` 断言要求内核有 `features.efiBootStub`。
  `linuxManualConfig` 默认 `features={}`，而 nixpkgs generic `kernel` 设 `efiBootStub=true`。
- 解决：`pkgs/sc8280xp-kernel/default.nix` 传 `features = { efiBootStub = true; }`。
  vendor 内核产出 vmlinuz.efi，该声明合理。
  （features 只是 passthru 元数据，不改变 derivation 输入，不触发内核重编）

### 2. aslr sysctl 模块：Unable to determine mmap_rnd_bits_max

- 现象：`55-nixos-aslr-entropy.conf` 构建失败
  `Unable to determine mmap_rnd_bits_max. Check your kernel configfile is valid.`
- 根因：nixpkgs `sysctl.nix` 无条件从内核 `configfile`（vendored 静态文件）grep
  `CONFIG_ARCH_MMAP_RND_BITS_MAX`。Armbian vendored config 缺整组 arm64 MMAP
  选项（rock5c 的 gnull vendor config 有）。
- 解决：在 `sc8280xp_vendor_config` 和 `.nix` 两处补上 arm64 MMAP 选项
  （值参照同为 arm64 的 rock5c vendor config：MIN=18/MAX=33/compat 11/16）。
  注意该变更改 configfile，会触发内核重编。

### 3. toplevel 并行构建 GCC 段错误（OOM）

- 现象：toplevel 并行编内核+initrd+系统单元时，GCC 段错误
  `drivers/power/supply/bq27xxx_battery_hdq.mod.o Error 1`。
- 根因：toplevel 同时编译多个大 derivation（内核+其他）内存过载，GCC 段错误。
- 解决：**先单独编完内核**（`nix build .#sc8280xp-kernel`），缓存就绪后
  toplevel 只编其余依赖，不再 OOM。

## 构建命令（ml-builder tmux）

```bash
# 先单独编内核（避免 toplevel 并行 OOM）
cd /nix/src/nixos-config && tmux new-session -d -s q8b-kernel \
  "nix build .#sc8280xp-kernel --no-link --print-out-paths --max-jobs 28 --cores 28 2>&1 | tee /tmp/q8b-kernel-build.log"

# 内核缓存就绪后再编 toplevel
cd /nix/src/nixos-config && tmux new-session -d -s q8b-toplevel \
  "nix build .#nixosConfigurations.dragon-q8b.config.system.build.toplevel --no-link --print-out-paths --max-jobs 28 --cores 28 2>&1 | tee /tmp/q8b-toplevel-build.log"
```

## 待完成步骤

### 1. ✅ 内核交叉编译成功（已完成）

移除 `CONFIG_DEBUG_INFO_BTF` 后构建成功。store path：
`/nix/store/spnibagqyg904r3ycips3rh3k4cgd2nr-k-aarch64-unknown-linux-gnu`
（见上方「当前构建状态」）。

### 2. ✅ 内核接入 NixOS 配置（已完成）

新建 `nixos/hardware/dragon-q8b/default.nix` 硬件模块引入 vendor 内核
（见「当前构建状态」），`hosts/dragon-q8b/hardware-configuration.nix` 已 import。

### 3. ✅ dragon-q8b toplevel 构建成功（已完成）

store path：`/nix/store/hb0b9galapx9mmd8g0ba6wx1d6myr39y-nixos-system-dragon-q8b-26.11pre-git`

### 4. 刷入 SD 卡/存储验证

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
   当前 GCC 14（gcc14Stdenv）。若 GCC 14 仍编译失败，需考虑其他方案。
3. **swap 已固化**在 ml-builder 配置里，重启不丢，118G 总交换，j28 不会 OOM。
4. **git 同步铁律**：本地改 → push origin → ml-builder `git pull --ff-only`。
   ml-builder 不能直接 push（无权限），需通过本地中转。
5. **pahole 段错误根因是 BTF（已解决）**：vendored config 从 Armbian 引入了
   `CONFIG_DEBUG_INFO_BTF=y`，Radxa 官方 defconfig 没有。移除后构建成功。
6. **Radxa 官方内核源码是 `radxa-pkg/linux-qcom`**（mainline），不是 Armbian 的
   `radxa/kernel`（vendor）。当前包用 Armbian 的 vendor 分支；若后续要完全对齐
   官方，需换源码 + 官方 defconfig（`make radxa_qcom_7_0_defconfig` 展开）。
7. **toplevel 构建三个阻塞已解决**（详见「toplevel 构建阻塞」）：
   systemd-boot 需 `features.efiBootStub`；aslr 需 configfile 有
   `CONFIG_ARCH_MMAP_RND_BITS_MAX`；并行构建 OOM 需先单独编内核。
8. **构建顺序铁律**：先 `nix build .#sc8280xp-kernel` 编完内核缓存，
   再 `nix build .#nixosConfigurations.dragon-q8b...toplevel`，避免并行 OOM。

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
| **dragon-q8b (SC8280XP)** | **nixos/hardware/dragon-q8b/** | **systemd-boot + EFI** | **self.packages.x86_64-linux.sc8280xp-kernel** |

## 配置参考来源

所有配置参考 Armbian 的 radxa-dragon-q8b 板配置：
- `config/boards/radxa-dragon-q8b.conf`
- `config/sources/families/sc8280xp.conf`
- `config/kernel/linux-sc8280xp-vendor.config`

Armbian 支持我们就支持，Armbian 不支持的暂不管。

## SD 卡安装（2026-08-24 完成）

### 安装方式

用户要求「直接 nix install 方式，UEFI 安装到 SD 卡」。SD 卡插在 opi5p
（aarch64 原生主机）上，识别为 `/dev/mmcblk1`（119.4G）。

### 关键步骤与坑

1. **closure 复制方向**：ml-builder（x86_64）→ opi5p（aarch64）。
   - ml-builder 能 ssh 到 opi5p，反之不行（opi5p 无 ml-builder 的 key）。
   - `nix copy --to ssh-ng://root@192.168.0.62`，NIX_SSHOPTS 必须带
     `-p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null`。
   - **不要用 tmux 后台跑**（若 mac 可能休眠）：之前复制失败那次
     `Permission denied (publickey)` 的根因不是 tmux，而是
     **bitwarden 的 ssh agent 因为 mac 电脑休眠失效**（agent socket 变陈旧，
     需重新唤起 agent / 重新认证）。直接前台跑（长 timeout）最可靠。
2. **UUID 更新**：新 SD 卡分区后 UUID 变化，必须更新
   `hosts/dragon-q8b/hardware-configuration.nix` 并重新构建 closure。
   - BOOT=`56C0-FB03`，NIX=`66493006-e89d-41dc-800f-9c437b92474a`。
   - 新 closure：`4xms4a4qrf58fbrf9c97w3dnjfwkk94q-nixos-system-dragon-q8b-26.11pre-git`。
3. **nixos-install-tools 架构坑**：从 ml-builder 复制的 install-tools 是
   x86_64 二进制，在 aarch64 的 opi5p 上执行报
   `unshare: 无法执行二进制文件: 可执行文件格式错误`（EXIT=126）。
   **必须在 opi5p 上构建 aarch64 版**：
   `nix build nixpkgs#nixos-install-tools`，得到
   `bg139k1nijb4j1zwmipah6qhhf9q8apc-nixos-install-tools-26.11pre-git`。
4. **分区布局**：UEFI 两分区（512M EFI + 剩余 Btrfs），创建
   `nix`/`persistent`/`persistent/home` 三个 subvol。
5. **nixos-install 成功**：`nixos-install --root /mnt --system $CLOSURE
   --no-root-passwd --no-channel-copy`，systemd-boot 装到
   `/boot/EFI/BOOT/BOOTAA64.EFI`，bootloader entry 生成，profile 建立。

### 安装结果

- systemd-boot 已装，`/boot/EFI/BOOT/BOOTAA64.EFI` 存在。
- 引导成功（用户确认系统指示灯正常），但**网卡全失效**（见下）。

## 网卡失效排查（进行中）

### 现象

- dragon-q8b 引导成功（指示灯正常），但**所有网卡失效**，包括板载
  TC956x 2.5GbE 和 USB 网卡 rtl8125b。
- 192.168.0.66 完全不可达：ping 不通、2222 关闭、router ARP 表无此 MAC、
  kea DHCP 无租约。

### 已确认的内核 config 事实

vendored config `pkgs/sc8280xp-kernel/sc8280xp_vendor_config` 中网卡驱动
**全是模块（=m）**，不是内建（=y）：

```
CONFIG_STMMAC_ETH=m        # 板载 TC956x 2.5GbE 的 stmmac 驱动
CONFIG_TOSHIBA_TC956X_PCI=m # TC956x PCI 桥
CONFIG_USB_RTL8152=m       # USB 网卡 rtl8125b 的 r8152 驱动
CONFIG_USB_RTL8150=m
```

而 `nixos/hardware/dragon-q8b/default.nix` 里 `kernelModules` 只强制加载
`tls`/`wireguard`，`extraModulePackages = lib.mkForce []`。这些网卡驱动模块
是否被正确打包进 initrd/系统并自动加载，是排查重点。

### Radxa 官方文档关键发现（docs.radxa.com/dragon/q8b）

1. **引导方式**：Radxa OS 用 systemd-boot，启动配置在
   `/boot/efi/loader/entries/`，**默认不含 `devicetree` 参数**（用 BIOS/UEFI
   提供的 DTB）。与我们的 systemd-boot 方案一致。
2. **BIOS 启动顺序**：默认 **USB → SD Card → NVMe → UFS**。
3. **BIOS 有「Device Tree Settings」和「Third-party OS Compatibility
   Settings」**：UEFI 在启动 Linux 前是否加载/修正/传递 DTB，以及第三方
   OS 兼容性配置，可能影响网卡初始化。
4. **官方内核源码是 `radxa-pkg/linux-qcom`**（mainline qcom 分支），不是
   Armbian 的 `radxa/kernel`（vendor 分支）。官方 defconfig 是
   `radxa_qcom_7_0_defconfig`。

### 下一步排查方向

1. 确认网卡驱动模块（st_bridge/tc2xx/r8152）是否打进 initrd 或系统模块目录，
   以及是否被自动加载。
2. 对比 Radxa 官方 defconfig 与 Armbian vendored config 的网卡相关选项。
3. 检查 BIOS 的 Device Tree Settings / Third-party OS Compatibility 是否
   需要调整（UEFI 传递 DTB 的方式可能影响网卡）。
4. 若 Armbian vendor 内核本身网卡驱动有问题，考虑换官方
   `radxa-pkg/linux-qcom` 源码 + `radxa_qcom_7_0_defconfig`。

## 串口诊断与 console 参数（2026-08-25 会话）

> 本节记录最近一次会话（serial + 签名复制）的进展。

### 串口：唯一诊断通道

- dragon-q8b 完全不可达（192.168.0.66 ping 不通、2222 关、ARP 无记录），
  串口是当前唯一能看内核日志的通道。
- mac 串口设备：`/dev/cu.usbmodem57920206431`，参数 **115200 8N1 无流控**。
- tio 命令（`-L` 是布尔开关，日志用 `--log-file`）：
  `tio -b 115200 --log-file /tmp/dragon-q8b-serial.log /dev/cu.usbmodem57920206431`

### 串口日志关键结论

- 日志**停在 UEFI End（ExitBootServices 后）**，没有任何 Linux 内核输出。
- UEFI 版本 `6.0.260818.BOOT.MXF.1.1.c1-00167-MAKENA-1`，SBL1 BUILD 2026-08-18。
- EEPROM：product='RS782-D8S32W0X110' ver='V1.305' sn='H4CO47JI'。
- **根因：kernelParams 缺 console 参数**，内核日志没输出到串口。
   Radxa OS 官方启动参数含 `console=ttyMSM0,115200n8 earlycon ... console=tty1`，
   我们的 `boot.kernelParams` 只有 `clk_ignore_unused pd_ignore_unused`。

### 已改：kernelParams 加 console 参数（commit 405ce264，已 push）

`hosts/dragon-q8b/configuration.nix` 的 kernelParams 改为：
```
clk_ignore_unused pd_ignore_unused console=ttyMSM0.115200n8 earlycon
```
已 push origin，ml-builder 仓库（`/nix/src/nixos-config`）`git pull --ff-only`
对齐到 405ce264。

### ⚠️ 新 toplevel 构建 + 复制签名阻塞（未解决）

1. 在 ml-builder 构建含 console 参数的新 toplevel，约 21 分钟后成功：
   `/nix/store/dhjdrswvnzqsyax45cgc35lbk6drv93r-nixos-system-dragon-q8b-26.11pre-git`
2. `nix copy --to ssh-ng://root@192.168.0.62` 报签名错误：
   `cannot add path ... because it lacks a signature by a trusted key`，
   具体是 `gen-hostid`（0kac5cvjsbrnlh2saa2lkjqyn2ik2xq8）缺签名。整个复制失败。
3. **根因**：opi5p 的 nix.conf `require-sigs=true`，trusted-public-keys 含
   `lantian:...`。而 ml-builder 的签名私钥 `nix-privkey` 是 **0 字节空文件**
   （`/run/secrets/nix-privkey`，真实路径 `/run/secrets.d/1/nix-privkey`），
   构建出的新路径没有 lantian 签名，opi5p 拒收。
4. attic 中转尝试失败：attic push 持续 `InternalServerError`；attic 服务器
   attic.zhyi.xin 解析到 greencloud（192.168.0.119），但 greencloud 上找不到
   atticd 服务/单元/nginx 反代。attic cache info 能返回
   `Public: true, Public Key: lantian:Pi7qMC8lIOrR8cTh4vfcRuSL/...`。

### 待办（新会话接手点）

1. 让新 closure 到 opi5p。可行的路：
   - **治本**：修好 ml-builder 的 `nix-privkey`（0 字节空文件）——解密
     `secrets/common/nix.yaml` 看该字段是否真空、是否 age key 缺失导致 sops
     写空。或换用 `nix store sign` 从有私钥的主机签名。
   - **绕路**：dragon-q8b 是 aarch64，opi5p 也是 aarch64，直接在 opi5p 原生
     构建 toplevel，避免跨架构复制（opi5p 需先建仓）。
   - **绕路2**：opsh/其他已能打通的 chain，或先在 opi5p 把 `require-sigs`
     放宽（但那是改全局安全配置，需用户同意）。
2. 复制成功后，用户重新接串口，抓带 console 参数的内核启动日志，确认
   内核真正启动、网卡驱动模块（stmmac/tc956x/r8152）是否加载、报什么错。
3. 若网卡驱动未加载，改 `nixos/hardware/dragon-q8b/default.nix` 的
   `kernelModules`/`initrd.availableKernelModules` 加入网卡驱动模块，重建。
4. 若 Armbian vendor 内核网卡驱动本身有问题，换官方 `radxa-pkg/linux-qcom`
   源码 + `radxa_qcom_7_0_defconfig`。

### 会话健康提示

- 上一会话在 attic 服务器位置反复排查。接手后**不要在 attic 上反复绕**，
  优先走签名治具（修 nix-privkey）或 opi5p 原生构建两条路。
- `nix-privkey` 空文件是签名失败的直接根因，`require-sigs` 信任链到它为止。

## attic 路线推进（2026-08-25 第二会话）

> 用户明确要求走 attic 路线。铁律：**任何问题先看文档**（`docs/agent/` 里
> 的知识库齐全）。本会话所有研究都先读文档。

### 关键认知纠正（读 `docs/agent/attic-s3-cache.md`）

1. **attic 服务确实在 greencloud**，`nixos/optional-apps/attic.nix` 由
   `hosts/greencloud/configuration.nix` 导入。之前没找到是查错了地方。
2. **`nix-privkey` 根本不是 attic 的签名密钥**——文档明确：att 缓存签名
   私钥由服务端管理，客户端和上传端都不应持有。所以 attic push 会让 attic
   用自身密钥签名，opi5p 拉取时用 `lantian` 公钥校验——**完全绕开
   ml-builder 的 nix-privkey 空文件问题**。这是 attic 路线的意义。
3. 手动上传凭据在 ml-builder：`/run/secrets/attic-upload-key`（只应含
   `--pull lantian --push lantian`）。

### attic 服务健康检查（文档命令）

- `systemctl is-active atticd nginx postgresql`（greencloud）→ 均 `active`。
- atticd 已运行 1 天，但日志显示 upload_path 报 `500 Internal Server Error`，
  latency 29s/15s/18s，`dispatch failure: io error: stream closed broken pipe`。
- vaults3 S3 后端：attic 的 `storage.type=s3`，endpoint
  `https://vaults3.zhyi.xin:8443`，bucket `nix-cache`。

### vaults3 / S3 链路实证（用户提示非标准端口找问题）

- vaults3 服务在 **router（192.168.0.1）**，监听 `:9000`（vaults3.nix）。
- opi5p（edge 入口）vhost `vaults3.zhyi.xin` proxyPass 到 router:9000。
- 公网入口 `vaults3.zhyi.xin:8443`（443 被运营商封锁，用 8443），router
  直通到 opi5p:8443（nginx 原生监听 8443，端口不变）再反代到 router:9000。
- 各链路 curl 均通（403 是 S3 无凭据正常响应，1s 内）：
  - router:9000 direct、opi5p 443 vhost（--resolve）、公网 8443 均 403。
- **关键实证**：`.multipart` 目录最后修改时间 `8月25日 01:02`（正是 attic
  push 报 500 时间 UTC 17:01 = 北京 01:01），说明 attic 的 S3 上传**到达了
  vaults3** 并留下 multipart 残留。所以 500 真实发生在 S3 写入层（NFS
  存储），不是 8443 链路问题。
- vaults3 存储是 NFS 挂载 `192.168.0.40:/nixos`（`/mnt/storage`），历史上有
  `multipart part could not be moved` rename 失败错误（8/20）。

### ⚠️ 新阻塞：闭包不完整（已 GC 部分依赖）——【已证伪，闭包完整】

- 曾用 `nix-store -qR` 列出 918 个依赖，用 `[ -d "$p" ]` 判断发现 15 个
  `MISSING`（gen-hostid、bird、sshd.conf-final 等），误以为被 GC 删了。
- **证伪**：改用 `[ -e "$p" ]`（文件/软链感知）重查，**918 个依赖全部存在**，
  闭包完整。`gen-hostid` 等是**文件**不是目录，`-d` 误报。
- 结论：out-link `dhjirsw...` 一直有效，重建时 nix build 短路跳过（结果
  已存在）。真正阻塞仍是**签名**（路径没带 lantian 签名，opi5p require-sigs
  =true 拒收）。

### 解决方案（进行中）

- 已用 `--out-link /root/cache-roots/dragon-q8b` 固定 root（指向
  `dhjirsw...`，完整闭包）。
- 走 attic 服务端签名绕开本地 nix-privkey 空文件：
  `attic push lantian /root/cache-roots/dragon-q8b`
- **注意**：之前 attic push 报 500 是 vaults3 S3 存储层问题（multipart 残留
  实证到达 vaults3），重试前先确认 S3 写入正常。

### 待办（新会话接手点）

1. 等待重建完成（约 20 分钟），验证闭包完整（`nix-store -qR` 无 MISSING）。
   【已证伪闭包不完整：918 依赖全在，重建短路跳过】
2. `attic push lantian /root/cache-roots/dragon-q8b` 上传完整闭包。
   【注意此前 500 是 vaults3 S3 存储层问题，重试前确认 S3 写入】
3. opi5p 用 `nix copy --from https://attic.zhyi.xin/lantian` 拉取（opi5p
   require-sigs=true，但 attic 服务端会签名，用 lantian 公钥校验）。
4. 用户重新接串口，抓带 console 参数的内核启动日志，确认内核启动与网卡
   驱动加载。
5. 若网卡驱动未加载，改 `nixos/hardware/dragon-q8b/default.nix` 的
   `kernelModules`/`initrd.availableKernelModules`。
6. 若 Arbian vendor 内核网卡驱动有问题，换官方 `radxa-pkg/linux-qcom` +
   `radxa_qcom_7_0_defconfig`。

## attic push 500 根因定位与清理重传（2026-08-25 第三会话）

> 本次会话把 attic push 一直 500 的根因彻底定位到 **vaults3 S3 后端 chunk
> 对象被截断**，并清库重传成功。核心收获记在这里，新会话直接从“验证
> opi5p 拉取”接手。

### 根因：nginx client_body 临时目录权限错 → 大 PUT 被截断

- 此前 attic push 报 500，`storage error: dispatch failure`，后定位到
  **opi5p 的 nginx `client_body` 临时目录** `/var/cache/nginx/client_body`
  owner=nobody 且 700，nginx worker（User=nginx）写入时 `Permission
  denied`，大对象（内核/initrd/modules 等，几十 MB）PUT 被 500 中断。
- **修复**：`chown -R nginx:nginx /var/cache/nginx/client_body`。
- 但 500 中断已造成**部分大 chunk 只传了一半**，attic 数据库却标记为
  valid——这是后续“push 显示 ✅ 但下载 not valid”的根源。

### 定位过程（证据链）

1. `attic push` 报 500 后重试显示 `✅ already cached`，但
   `nix path-info --store https://attic.zhyi.xin/lantian <path>` 对内核
   `86jz1hw...` 报 `is not valid`。
2. attic DB 里 object/nar/chunk 记录都在（nar state=`V` valid，num_chunks=1）。
3. chunk 元数据指向 S3 key，`curl` vaults3 实际下载该 chunk 对象只有
   **18MB**，而 DB 记录 chunk_size=**69MB**——**S3 对象被截断/残缺**。
4. 一一核对：5 个残缺 chunk（内核、nginx-lantian、initrd、pkgs-patched、
   sops-install-secrets）DB 记录的大小都远大于 vaults3 实际对象大小。

> 注意：attic chunk 是 zstd 压缩的，S3 对象大小小于 chunk_size（未压缩）是
> 正常的。真正的异常是**残缺对象**——DB 记录 chunk_size 与对象实际内容不一致
> 导致下载校验失败。判断“截断”不能只看大小差，要核对下载后 NAR 校验是否通过。

### 清理残缺 chunk 并重传（用户批准）

- 备份 attic DB：`sudo -u postgres pg_dump atticd > /tmp/atticd-backup-*.sql`
  （greencloud）。
- 删 5 个残缺 chunk 的 DB 记录（chunkref + chunk）与 S3 对象（router 上
  `/mnt/storage/vaults3-data/nix-cache/<key>.chunk`）。每个 chunk 仅被一个
  nar 引用（已确认），安全。
- 再删对应 5 个 object + nar 记录，让 attic 完全重建。
- 重跑 `attic push` 这 5 个路径 → 全部重新上传成功。
- 验证：`nix copy --from <attic> <k-image> --to file:///tmp/verify` 成功，
  NAR 校验通过。**attric 上的闭包已完整可用**。

### 新阻塞（已解决）：opi5p 从 attic 拉取时 307 到 vaults3.zhyi.xin:8443 连不上

> 已由下文「已落地：opi5p HTTPS vhost 补 8443 监听」解决（nginx 现在 443 与 8443 同时监听）。
> 本段保留作为排查过程记录。

- opi5p 的 `/etc/hosts` 把 `vaults3.zhyi.xin` 覆盖到本机
  （192.168.0.62 / interconnect），但当时 opi5p nginx 只监听 443，未监听
  8443。attic 的 NAR 下载 307 重定向到 `vaults3.zhyi.xin:8443`（S3
  presigned URL 用 :8443），opi5p 连自己 192.168.0.62:8443 无监听 → 失败。
- ml-builder 无此 hosts 覆盖走公网 8443 反而能通。

### 已落地：opi5p 的 HTTPS vhost 补 8443 监听（home-ddns 专属特色）

> 用户拍板：把 8443 监听加上，作为 home-ddns（家宽入口）专属特色。

- 目标文件：`hosts/opi5p/edge-vhosts.nix`。
- 做法：该文件基于 `config.lantian.nginxVhosts` 重新生成
  `services.nginx.virtualHosts`，给每个启用 TLS 的 vhost 追加一条 8443
  监听，443 与 8443 同时服务同一套证书与路由（仅 opi5p 生效）。
- vhost 机制见 `nixos/common-apps/nginx/vhost-options/vhost-options.nix`：
  `listenHTTPS` 选项默认监听 `LT.port.HTTPS`(443)，一个 vhost 一次只能
  一个 HTTPS listen；额外 8443 在 `services.nginx.virtualHosts` 层 mkForce
  追加 8443 监听实现。
- **防火墙**：router 把公网/家内 8443 DNAT 直通到 opi5p:8443（端口不变，
  `hosts/router/firewall.nix` 两处）。确认 `networking.firewall` 或 nftables
  允许 8443 入站。
- 验证：opi5p 上 `curl -k https://127.0.0.1:8443 -H "Host: vaults3.zhyi.xin"`
  应返回 403（S3 无凭据），再跑 attic 拉取确认 NAR 307 落到本机 8443 通。
- 改完走 nix 部署（在 ml-builder 上 `colmena apply --on opi5p`）。

### 接手提示（新会话）

- 当前 attic 上闭包已完整可用（清理重传后 NAR 校验通过）。剩余核心：
  让 opi5p 成功从 attic 拉到完整闭包。
- 优先解决 opi5p 8443 监听（上述待办），或考虑 ml-builder 中继（opi5p
  从 ml-builder `ssh-ng`/`nix copy` 拉已签名路径）作为临时绕过。
- **不要直接清 attic 库**（文档铁律），若仍遇"已缓存但下载失败"，
  先核 chunk DB 记录 vs vaults3 对象内容，而非盲删。

## SD 卡安装（2026-08-25 第二次，本次会话）

> 闭包齐全（attic 上 dhjirsw closure 完整可用，opi5p 8443 监听已生效），
> SD 卡 UUID 匹配 hardware-configuration（上次分区沿用），直接开工。

### 安装流程

1. **opi5p 从 attic 拉取完整闭包**：`nix copy --from https://attic.zhyi.xin/lantian
   --no-check-sigs /nix/store/dhjirswvnzqsyax45cgc35lbk6drv93r-nixos-system-dragon-q8b-26.11pre-git`，
   全部 918 依赖拉取成功（内核 modules、initrd、toplevel 等）。
2. **构建 nixos-install-tools（aarch64 原生）**：`nix build nixpkgs#nixos-install-tools`
   → `bg139k1nijb4j1zwmipah6qhhf9q8apc-nixos-install-tools-26.11pre-git`。
3. **OOM 处置**：第一次 nixos-install 被 OOM kill（opi5p 15G 内存仅剩 614M，
   load 28，systemd-journald 反复被 OOM kill）。临时停掉 resilio/clamav/
   tachidesk/peerbanhelper/immich/redis-immich/bitmagnet×3/frigate 共 10 个
   服务，释放约 4G 内存（可用 1.4G→5.5G）。安装完后恢复。
4. **bootloader 挂载坑**：nixos-install 只挂 neededForBoot=true 的文件系统
   （/nix、/nix/persistent），不挂 /boot（neededForBoot 默认 false），导致
   systemd-boot 报 `efiSysMountPoint = '/boot' is not a mounted partition`。
   解决：手动挂载所有文件系统到 /mnt/q8b（含 /boot），再重跑 nixos-install，
   bootloader 安装成功。
5. **安装成功**：systemd-boot 装到 `/boot/EFI/BOOT/BOOTAA64.EFI`，
   bootloader entry 含 `console=ttyMSM0,115200n8 earlycon` 参数，
   kernel(vmlinuz.efi 15MB)+initrd(24MB) 复制到 EFI 分区，profile 建立。

### 安装结果

- closure：`dhjirswvnzqsyax45cgc35lbk6drv93r-nixos-system-dragon-q8b-26.11pre-git`
- bootloader entry：`nixos-e3d658e7...conf`，options 含 console 参数
- kernel：`86jz1hw83...-k-aarch64-unknown-linux-gnu`（vmlinuz.efi）
- initrd：`r7dhj347...-initrd-k-aarch64-unknown-linux-gnu`
- dtbs：含 `sc8280xp-radxa-dragon-q8b.dtb` + `-el2.dtb`（UEFI 自带 DTB 传递，entry 不含 devicetree 参数）
- SD 卡挂载已全部卸载，opi5p 服务已恢复

### ⚠️ 已知 bug：hardware-configuration.nix home subvol 路径错误

`hosts/dragon-q8b/hardware-configuration.nix` 中 `/nix/persistent/home` 的
btrfs 选项写的是 `subvol=home`，但实际 btrfs subvol 路径是
`persistent/home`（nested under persistent subvol，top level 257）。
`subvol=home` 挂载失败（`fsconfig() failed: 没有那个文件或目录`）。
应改为 `subvol=persistent/home`。该 subvol 不是 neededForBoot，不影响
安装和启动，但系统启动后 /nix/persistent/home 会挂载失败。需后续修正
+重建 closure。

### 待办（新会话接手点）

1. **用户操作**：把 SD 卡从 opi5p 拔出，插到 dragon-q8b，接串口
   （mac: `/dev/cu.usbmodem57920206431`，115200 8N1），启动抓日志。
   这次有 console 参数，应该能看到内核启动输出。
2. **串口日志重点**：确认内核真正启动、网卡驱动模块
   （stmmac/tc956x/r8152）是否加载、报什么错。
3. **网卡驱动未加载**：改 `nixos/hardware/dragon-q8b/default.nix` 的
   `kernelModules`/`initrd.availableKernelModules` 加入网卡驱动模块，重建。
4. **UEFI DTB 设置**：检查 BIOS 的 Device Tree Settings / Third-party OS
   Compatibility 是否需要调整（UEFI 传递 DTB 的方式可能影响网卡初始化）。
5. **home subvol bug**：✅ 已修正 `subvol=home` → `subvol=persistent/home`（commit 20675783）。
6. **Armbian vendor 内核网卡问题**：若 vendor 内核驱动有问题，换官方
   `radxa-pkg/linux-qcom` + `radxa_qcom_7_0_defconfig`。

## initrd 模块修复 + 第二次安装（2026-08-25 11:20）

### 根因定位（串口日志）

第一次安装后串口日志显示内核成功启动（console 参数生效），但卡在 initrd：
```
[ TIME ] Timed out waiting for device dev-disk-by\x2duuid-66493006...device
[DEPEND] Dependency failed for sysroot-nix.mount - /sysroot/nix
```

根因：`nixos/hardware/dragon-q8b/default.nix` 里 `initrd.availableKernelModules
= lib.mkForce []` 和 `initrd.kernelModules = lib.mkForce []` 清空了所有 initrd
模块。而 `CONFIG_BTRFS_FS=m`（btrfs 是模块），initrd 里没有 btrfs.ko，blkid
无法读取 btrfs superblock 识别分区 UUID，by-uuid 设备永不出现导致根挂载超时。

网卡驱动（stmmac/tc956x/r8152）同为模块（=m），也不在 initrd 中。

### 修复（commit 20675783）

1. `nixos/hardware/dragon-q8b/default.nix`：initrd 加入 btrfs、dwmac_tc956x、
   gpio_tc956x、r8152（及依赖模块 stmmac/tc956x_pci/pcs_xpcs/phylink/mii/xor/
   xor-neon/raid6_pq/libblake2b，共 13 个 .ko.zst）。
2. `hosts/dragon-q8b/hardware-configuration.nix`：`subvol=home` →
   `subvol=persistent/home`（btrfs subvol 实际路径是 persistent/home，
   嵌套在 persistent subvol 下）。

### 构建与安装

- 新 closure：`7zg8wq1g0w55wf2gi0i146qwwv3b7mf1-nixos-system-dragon-q8b-26.11pre-git`
- 新 initrd：`gi5vp6xydaysr02bwpzb9nr2rxvpgbfy-initrd-k-aarch64-unknown-linux-gnu`
  （含 13 个模块，25.7MB vs 旧 24.5MB）
- **复制路径突破**：`nix copy --to ssh-ng://root@192.168.0.62 --no-check-sigs`
  绕过 opi5p require-sigs=true 签名检查（--no-check-sigs 选项生效），
  只复制 10 个差异路径（大部分依赖 opi5p 已有）。
- nixos-install 成功，Generation 2 bootloader entry 生成，
  旧 Generation 1 保留作为 fallback。
- home subvol `subvol=persistent/home` 挂载验证通过。

### 待验证

1. 用户把 SD 卡插到 dragon-q8b，接串口启动。
2. 预期：btrfs 模块加载 → by-uuid 设备出现 → 根文件系统挂载 → 系统启动。
3. 关注网卡驱动模块加载情况（stmmac/dwmac-tc956x/r8152）。
4. 若网卡仍不工作，检查 UEFI Device Tree Settings / Third-party OS Compatibility。

## NVMe 安装（2026-08-25 12:35）

### 系统启动成功

SD 卡安装（closure 7zg8wq1g）后系统完整启动：
- btrfs 模块加载 → by-uuid 设备出现 → 根文件系统挂载成功
- systemd 全部启动到 multi-user.target
- 网卡驱动完全工作：TC956x 双口 2.5GbE（QCA8081 PHY）+ r8152 USB NIC
  - eth0: 192.168.0.66/24, 2500Mb/s, 获取到公网 IPv6
  - SSH -p 2222 root@192.168.0.66 可连
- 剩余失败服务（sops-install-secrets/nginx/filebeat）因 dragon-q8b
  的 age key 未加入 secrets 仓库 `.sops.yaml` 导致，需后续 colmena 部署。
- remoteproc firmware（adsp/cdsp/video-codec）加载失败：正常，无 Qualcomm 固件。
- 网卡 NO-CARRIER 问题：用户确认是网线插错口，换到 eth0 后链路正常。

### NVMe 安装流程

- NVMe: Samsung MZVLW256HEHP-00000, 238.5G, PCIe Gen.3 x2
- NVMe 已有分区（vfat + btrfs），UUID: DB72-1C49 / e9ab9a38-...
- 调整 btrfs subvol：删除顶层 home，在 persistent 下创建 persistent/home
  （与 SD 卡布局统一）
- hardware-configuration.nix UUID 切换到 NVMe（commit 69182ca3）
- 新 closure：`9cx1232z4av13gfn97ijh0z721rmp6ix-nixos-system-dragon-q8b-26.11pre-git`
- nix copy --no-check-sigs 从 ml-builder 复制到 dragon-q8b（4 个差异路径）
- 在 dragon-q8b 本机 nixos-install → **EFI boot entry 写入 NVRAM 成功**
  （SD 卡安装时在 opi5p 上跑无法写 NVRAM，本机可以）
- efibootmgr 确认：Boot0000 → NVMe EFI, BootOrder 0000,0001

### 下一步

1. 拔掉 SD 卡，重启 dragon-q8b，从 NVMe 启动。
2. 验证网络和 SSH。
3. 后续：把 dragon-q8b 的 age key 加入 secrets 仓库 `.sops.yaml`，
   colmena apply --on dragon-q8b 部署 secrets。
4. 后续：考虑换官方 `radxa-pkg/linux-qcom` + `radxa_qcom_7_0_defconfig`。

## 换用 Radxa 官方内核（2026-08-25 12:50）

### 原因

Armbian vendor config 的 `CONFIG_IPV6=m`（模块）导致 `CONFIG_MPTCP_IPV6`
无法启用（Kconfig depends on IPV6=y），nginx `listen [::]:80 multipath`
报 `EPROTONOSUPPORT`。此外 GPU/VPU/NPU 固件全缺（linux-firmware 只有
LENOVO/21BX 目录的 SC8280XP 固件，没有 radxa/dragon-q8b 路径）。

### Radxa 官方内核信息

- 源码：`github.com/radxa/kernel` commit `f87cd1e7a6cf9e164ef1a34c846312f9055e3f29`
  （radxa-pkg/linux-qcom rsdk 打包仓库的 submodule 引用，2026-08-18）
- defconfig：`radxa_qcom_7_0_defconfig`（3778 行，在内核源码 arch/arm64/configs/ 里）
- 版本：7.0.11（和 Armbian 相同）
- hash：`sha256-e6Ic4NJ1H0xLbyezDAvqCFpRg7F9AaQpXZiFpBW+Dmw=`

### Radxa defconfig 关键优势

| 配置 | Armbian | Radxa | 影响 |
| --- | --- | --- | --- |
| CONFIG_IPV6 | =m | 默认 y | MPTCP_IPV6 自动启用 |
| CONFIG_BTRFS_FS | =m | =y | initrd 不需要 btrfs 模块 |
| CONFIG_EFIVAR_FS | ? | =y | systemd-boot EFI 变量 |
| CONFIG_DEBUG_INFO_BTF | =y（已删） | 不启用 | 避免 pahole 段错误 |
| CONFIG_MPTCP_IPV6 | 缺 | 默认 y | nginx IPv6 multipath |

### config fragment（额外添加）

Radxa defconfig 不含的板级/NixOS 配置：
- CONFIG_TC956X_PCI=m, CONFIG_DWMAC_TC956X=m, CONFIG_GPIO_TC956X=m
- CONFIG_USB_R8152=m
- CONFIG_ARCH_MMAP_RND_BITS_MAX=33 等（nixpkgs sysctl 需要）

### 构建状态

- ml-builder tmux session `q8b-kernel` 交叉编译中
- 日志：`/tmp/q8b-kernel-build.log`
- 闭包复制路径：`nix copy --to ssh-ng://root@192.168.0.66 --no-check-sigs`

### 硬件现状（当前 Armbian 内核）

| 硬件 | 状态 | 原因 |
| --- | --- | --- |
| 网络 TC956x 2.5GbE | ✅ 工作 | 驱动模块在 initrd |
| NVMe Samsung 238G | ✅ 工作 | 内建驱动 |
| SD 卡 | ✅ 工作 | 内建驱动 |
| USB | ✅ 工作 | |
| GPU Adreno 690 | ❌ bind failed -19 | 固件 + 驱动问题 |
| VPU Adreno 5th gen | ❌ 固件缺失 | qcom/vpu/vpu20_p4_gen2_s6.mbn |
| NPU/DSP ADSP+CDSP | ❌ offline | qcom/sc8280xp/radxa/dragon-q8b/qcadsp8280.mbn |
| Audio | ❌ 无声卡 | 依赖 ADSP 固件 |
| DisplayPort | ❌ probe failed | component add failed |

### 固件问题（换内核不解决）

linux-firmware 里只有 `qcom/sc8280xp/LENOVO/21BX/` 目录的固件
（ThinkPad X13s），dragon-q8b 需要 `qcom/sc8280xp/radxa/dragon-q8b/`
路径的固件。需从 Radxa deb 包或 Armbian 固件包获取。

### 待完成

1. 内核构建完成 → 构建 toplevel → nix copy 到 dragon-q8b → 重新安装
2. 硬件模块 `nixos/hardware/dragon-q8b/default.nix` 可能需要调整
   （btrfs 内建后 initrd 不需要 btrfs 模块）
3. 固件获取（Radxa deb 包或链接 LENOVO 固件）
4. colmena deploy greencloud 触发 ACME 证书申请（greencloud 构建
   需先修复 Python 3.14 pkg_resources 问题）

## 内核构建修复链（2026-08-25 13:30）

换用 Radxa 官方内核后，构建经历了多次失败，每次不同根因：

1. **ARCH=arm64 缺失**：`make radxa_qcom_7_0_defconfig` 在 x86_64 主机上
   默认找 `arch/x86/configs/`。修复：preConfigure 显式 `make ARCH=arm64`。
2. **configurePhase mkdir 冲突**：preConfigure 创建了 build 目录，
   linuxManualConfig 默认 configurePhase 也尝试创建。修复：完全覆盖
   configurePhase 为 `runHook preConfigure; runHook postConfigure`。
3. **config attrset 缺 CONFIG_ 前缀**：`isModular = config.isYes "MODULES"`
   查找 `CONFIG_MODULES`（带前缀），但 attrset 写了 `MODULES`。导致
   无 modules output，initrd 无法提取网卡驱动。修复：所有 attrset
   键改用 `CONFIG_` 前缀。
4. **AMD GPU 驱动交叉编译失败**：Radxa defconfig 启用了 `CONFIG_DRM_AMDGPU`，
   GCC 14 交叉编译 `drivers/gpu/drm/amd/amdgpu/` 链接失败。dragon-q8b
   用 Adreno 690 不需要 AMD GPU 驱动。修复：config fragment 添加
   `# CONFIG_DRM_AMDGPU is not set` 和 `# CONFIG_DRM_NOUVEAU is not set`。

### 当前构建状态

- ml-builder tmux session `q8b-build` 构建 toplevel（含新内核）中
- 日志：`/tmp/q8b-build3.log`
- 内核 derivation：`5kh2bfwx8ipfj0rhiakrb7m724c096ah`（每次 config 变更 hash 变）
- 修复 4 后正在重新编译（约 20-30 分钟）

### 关键文件变更清单

| 文件 | 变更 |
| --- | --- |
| `pkgs/sc8280xp-kernel/default.nix` | 换 Radxa commit + defconfig + fragment |
| `pkgs/sc8280xp-kernel/sc8280xp_vendor_config` | 保留但不再使用 |
| `pkgs/sc8280xp-kernel/sc8280xp_vendor_config.nix` | 保留但不再使用 |
| `nixos/hardware/dragon-q8b/default.nix` | initrd 移除 btrfs（内建），保留网卡 |
| `hosts/dragon-q8b/hardware-configuration.nix` | UUID 切换到 NVMe |
| `hosts/dragon-q8b/host.nix` | 添加 zerotier node ID |

### 接手提示

- 内核构建用 tmux 后台跑，检查 `tmux list-sessions` 和 `/tmp/q8b-build3.log`
- 构建成功后：`nix copy --to ssh-ng://root@192.168.0.66 --no-check-sigs
  $(readlink /root/cache-roots/dragon-q8b)` 复制到 dragon-q8b
- dragon-q8b 上挂载 NVMe + nixos-install（参考文档上方"安装命令参考"）
- ml-builder 上 flake.lock 有 nix 自动修改，git stash 后 pull

## Radxa 官方内核构建成功（2026-08-25 15:00）

### 最终方案

放弃在 Nix 构建里 `make defconfig` + hack configurePhase/postInstall
的方式，改为和 Armbian 一样的方式：
1. 在 ml-builder 上 clone 内核源码，`make radxa_qcom_7_0_defconfig` 展开
2. 添加 extra config（TC956x/R8152/MMAP/禁用 AMDGPU/禁用 DEBUG_INFO）
3. `make olddefconfig`，sed 强制 `CONFIG_DEBUG_INFO_NONE=y`，再 olddefconfig
4. 把生成的完整 .config（11066 行）保存到仓库
5. 从 .config 生成 config attrset（6168 行）
6. 用标准 `linuxManualConfig` 构建（只改 configurePhase 加 olddefconfig）

### 构建成功

- closure：`bq5v9ry9gzzagq061fd66163qyph68ph-nixos-system-dragon-q8b-26.11pre-git`
- nix copy --no-check-sigs 复制到 dragon-q8b
- nixos-install 到 NVMe 成功
- 重启后验证全部通过：
  - `uname -r` → 7.0.11（Radxa 内核）
  - `CONFIG_IPV6=y` + `CONFIG_MPTCP_IPV6=y` → nginx active ✅
  - `CONFIG_BTRFS_FS=y`（内建）
  - `CONFIG_DEBUG_INFO_NONE=y`
  - 零失败服务

### 之前构建失败的原因总结

之前在 Nix 构建里 `make defconfig` + 覆盖 configurePhase/postInstall 的方式
有多个不兼容问题：
1. `linuxManualConfig` 的 postInstall 包含 `make modules_install` 和 `cp vmlinux`，
   不能简单跳过（modules 不会安装，vmlinux 不存在）
2. `config` attrset 需要 `CONFIG_` 前缀（`isYes "MODULES"` 查找 `CONFIG_MODULES`）
3. GCC 14 DWARF5 段错误（需要禁用 DEBUG_INFO）
4. AMD GPU 驱动交叉编译失败（需要禁用 AMDGPU）

改为预先展开 defconfig 生成完整 .config 后，这些问题全部消失。

### 关键文件

| 文件 | 说明 |
| --- | --- |
| `pkgs/sc8280xp-kernel/default.nix` | 标准 linuxManualConfig，源码 commit f87cd1e7a6cf |
| `pkgs/sc8280xp-kernel/sc8280xp_radxa_config` | 展开后的完整 .config（11066 行）|
| `pkgs/sc8280xp-kernel/sc8280xp_radxa_config.nix` | config attrset（6168 行）|
| `pkgs/sc8280xp-kernel/sc8280xp_vendor_config` | 旧 Armbian config（保留不使用）|
| `pkgs/sc8280xp-kernel/sc8280xp_vendor_config.nix` | 旧 Armbian attrset（保留不使用）|

### 剩余待办

1. 固件：GPU/VPU/NPU 固件仍缺（linux-firmware 只有 LENOVO/21BX 路径）
2. ACME 证书：当前用 minica 自签名 bootstrap，后续需 colmena deploy greencloud
   申请正式证书（greencloud 构建需先修复 Python 3.14 pkg_resources 问题）
3. sops secrets：dragon-q8b 的 age key 已在 .sops.yaml，secrets 解密成功

## Radxa 官方固件安装成功（2026-08-25 17:35）

### 固件来源

从 `radxa-pkg/radxa-firmware` 仓库获取 SC8280XP 固件（commit e1761009）。
固件包通过 `hardware.firmware` 集成到 NixOS 配置。

### 固件加载结果

| 硬件 | 之前 | 之后 |
| --- | --- | --- |
| ADSP | offline（固件缺失）| ✅ running |
| CDSP | offline（固件缺失）| ✅ running |
| VPU | firmware download failed | ✅ video0/video1 存在 |
| GPU | bind failed -19 | ⚠️ DRM 设备存在，DPU 仍 bind failed |
| Audio | No soundcards | ⚠️ 编解码器绑定，声卡未完全就绪 |

### 固件文件清单

- `qcom/sc8280xp/radxa/dragon-q8b/qcadsp8280.mbn` (ADSP)
- `qcom/sc8280xp/qccdsp8280.mbn` (CDSP)
- `qcom/vpu/vpu20_p4_gen2_s6.mbn` (VPU)
- `qcom/sc8280xp/qcdxkmsuc8280.mbn` (GPU/display)
- `qcom/sc8280xp/qcslpi8280.mbn` (SLPI)
- `qcom/sc8280xp/qcvss8280.mbn` (VSS)

### 最终系统状态

- 内核：Radxa 官方 7.0.11（radxa_qcom_7_0_defconfig）
- 固件：Radxa 官方 SC8280XP 固件
- 网络：TC956x 2.5GbE 192.168.0.66
- 存储：NVMe Samsung 238G
- nginx：active（MPTCP_IPV6=y）
- sops：secrets 解密成功
- zerotier：已授权，LTNET 连通
- 失败服务：零
- ACME 证书：minica 自签名 bootstrap（后续需 colmena deploy greencloud 申请正式证书）

### 剩余待办

1. GPU DPU 绑定失败 (-19)：可能需要 DTB 调试或额外驱动配置
2. Audio 声卡未完全就绪：依赖 ADSP，可能需要额外配置
3. ACME 正式证书：greencloud 构建有 Python 3.14 pkg_resources 问题需修复
4. SD 卡可拔掉（系统从 NVMe 启动）

## GPU/Audio 问题研究（2026-08-25 18:30）

### GPU/DPU 绑定失败根因

GPU 驱动（adreno，CONFIG_DRM_MSM=y 内建）在启动 0.4 秒时 probe，
此时 udev 还没设置 `firmware_class.path`（在系统启动后才设置）。
GPU 驱动无法加载 ZAP shader 固件
（`qcom/sc8280xp/LENOVO/21BX/qcdxkmsuc8280.mbn`），不注册 `msm_drm`
auxiliary device，DPU 无法绑定（`adev bind failed: -19`）。

固件文件本身存在（linux-firmware + Radxa 固件包都有 qcdxkmsuc8280.mbn.zst），
内核支持 zstd 压缩固件（CONFIG_FW_LOADER_COMPRESS_ZSTD=y），
但加载时机不对。

**注意**：不要尝试 GPU unbind 操作——会导致 adreno_remove 内核 panic
（NULL pointer dereference），系统崩溃重启。

### jhovold X13s wiki 关键信息

- pd-mapper 在内核 6.11+ 不需要了（我们用 7.0.11）
- Audio：ADSP 偶尔无法注册服务（已知问题，very infrequent）
- UEFI：最近的固件如果启用 "Linux Boot" 选项，可以不需要 efi=noruntime
- 固件：需要 linux-firmware 20241210 或更新版本

### BrainWart/x13s-nixos 参考配置

- 使用 `dtb=` 参数指定内核 DTB（X13s 的 UEFI 不传递 DTB）
- `hardware.firmware = lib.mkBefore [ pkgs.x13s.firmware.graphics ]`
- initrd 包含固件：`boot.initrd.systemd.contents."/lib".source = modulesWithExtra/lib`
- initrd 模块包含 msm、gpucc_sc8280xp、dispcc_sc8280xp、phy_qcom_edp 等
- 但 X13s 用 mainline 内核（驱动是模块），dragon-q8b 用 vendor 内核（驱动内建）

### 待实施方案（等机器恢复）

1. **GPU 固件加载**：在 `boot.kernelParams` 添加
   `firmware_class.path=/lib/firmware`，确保 initrd 包含 ZAP shader 固件。
   NixOS initrd 通过 `makeModulesClosure` 包含 `hardware.firmware` 的固件到
   initrd 的 `/lib/firmware` 目录。设置内核命令行参数让 GPU 驱动在启动时
   就能搜索这个路径。
2. **Audio**：保留 qrtr/rmtfs 服务，pd-mapper 在 6.11+ 不需要但保留无害。
   alsa-ucm-conf 已添加。Audio 超时是已知问题。
3. **UEFI 设置**：检查 Radxa Q8B BIOS 的 "Third-party OS Compatibility" 和
   "Device Tree Settings"（Radxa 文档提到但页面 404）。

## GPU 模块化 + 服务精简（2026-08-25 20:15）

### 改动

1. CONFIG_DRM_MSM 从 =y 改为 =m（模块），让 GPU 驱动在 initrd 挂载后才加载
2. initrd 加入 msm 模块 + ZAP shader 固件（extraFirmwarePaths）
3. boot.kernelParams 添加 firmware_class.path=/lib/firmware
4. 移除 qrtr-ns 服务（内核 6.11+ 自带 nameserver）
5. 移除 pd-mapper 服务（jhovold wiki 确认 6.11+ 不需要）
6. rmtfs 服务独立运行（不依赖 qrtr）

### 结果

| 项目 | 状态 |
| --- | --- |
| msm 模块加载 | ✅ 在 initrd 阶段加载 |
| rmtfs | ✅ active |
| 零失败服务 | ✅ |
| nginx | ✅ active |
| ADSP/CDSP/VPU | ✅ running |
| GPU DPU 绑定 | ❌ 仍 adev bind failed -19 |
| Audio 声卡 | ❌ DP0 Playback codec dai not found |

### GPU/Audio 问题进一步分析

GPU DPU 绑定失败和 Audio 问题是**关联的**：
1. GPU 驱动（adreno）probe 但不注册 DPU 需要的 auxiliary device
2. DPU 无法绑定（adev bind failed -19）
3. DisplayPort 不工作
4. DP0 音频 codec DAI 不可用
5. 音频驱动 deferred probe（codec dai not found）

固件加载时机不再是问题（msm 模块在 initrd 阶段加载，固件在 initrd 里），
但 GPU auxiliary device 注册可能需要更深入的内核调试。

### 可能的后续方案

1. **换用 mainline 内核**（pkgs.linuxPackages_latest）— jhovold wiki 显示
   X13s 在 mainline 上 GPU/display 基本工作。Radxa vendor 7.0.11 可能有 bug
2. **检查 UEFI 设置** — Third-party OS Compatibility / Device Tree Settings
3. **接受当前状态** — 服务器角色不需要 GPU/display/audio，核心功能全部正常

## GPU 根因：nomodeset（2026-08-25 21:15）— 已解决

上一节的推测全部作废。真正根因是 **server 角色统一加的 `nomodeset`**：

- `nixos/server-components/boot-params.nix` 给所有 server 加 nofb/nomodeset/vga=normal
- `nomodeset` 让 DRM 驱动直接拒绝 probe → msm 从未加载成功
- 之前所有「adev bind failed -19」「DP0 codec dai not found」都是它的连锁反应
- X13s（client 角色）、Radxa 官方系统都没这参数，所以正常

### 修复过程中的两次失败（教训）

1. **mkForce 重建 kernelParams**：把模块级合并参数（root=fstab、nohibernate、
   lsm、vt.default_*、nowatchdog 等）全部顶掉 → gpt-auto-root 超时进 emergency，
   无法启动，用户从 systemd-boot 菜单回退旧代才救回。kernelParams 全集很多，
   手工重列必碎。
2. **正确做法：`disabledModules`**：主机级禁用 boot-params.nix。该模块其余
   功能（grub memtest86/netboot.xyz）是 x86 专用空操作，aarch64 上禁了没损失。
   模块级参数不再受影响。

### 同时修复

- **移除 rmtfs 服务**：DTB 无 rmtfs-mem 节点、/dev/qcom_rmtfs_mem1 不存在、
  此板无 modem（只有 adsp/cdsp remoteproc），rmtfs 无服务对象。之前
  journalctl 里 rmtfs 从未成功过（早期记录「rmtfs ✅ active」是误判）。
- **initrd 补 Adreno 固件**：a660_sqe.fw.zst、a660_gmu.bin.zst（linux-firmware
  里有但没进 initrd，msm 在 initrd 阶段 probe 就要加载）。

### 验证结果（2026-08-25 21:00 重启后）

```
msm_dpu ae01000: bound ae90000/ae98000/ae9a000 displayport-controller
adreno 3d00000.gpu: bound (ops a3xx_ops)
[drm] Initialized msm 1.13.0 for ae01000.display-controller on minor 1
loaded qcom/a660_sqe.fw from new location
loaded qcom/a660_gmu.bin from new location
/sys/class/drm/: card1-DP-1  card1-DP-2  card1-HDMI-A-1  renderD128
systemctl --failed: 0
```

GPU/display 完全工作。音频链路大幅前进但未通：wcd938x codec bound、
ADSP 服务加载（Radxa 专属固件 qcom/sc8280xp/radxa/dragon-q8b/qcadsp8280.mbn），
卡在 `qcom-apm ASoC error (-2): snd_soc_component_probe()` →
`snd-sc8280xp failed with error -2`。后续线索：linux-firmware 里有
`SC8280XP-LENOVO-X13S-tplg.bin`（audioreach 拓扑），vendor 内核是否需要
待查；或者参考 Radxa 官方系统的音频配置。

### UEFI 第三方 OS 兼容选项（用户问过，备忘）

当前 BIOS 四个兼容方案都「启用」，但系统能启动且 GPU 正常：

- 忽略 CLK/PD：等效于 kernelParams 里的 clk_ignore_unused/pd_ignore_unused，
  已有参数覆盖，BIOS 开关无所谓
- simple-bridge/gpio-shared 兼容：vendor 内核有 DRM_SIMPLE_BRIDGE=y、
  GPIO_SHARED_PROXY=y，按 Radxa 提示「用受支持系统时不建议启用」可关，
  但当前开着也没出问题，不动
- 强制较小 PCIe BAR：NVMe 正常，不动

结论：BIOS 维持现状，不动。

### 最终系统状态

- 内核：Radxa 官方 7.0.11（radxa_qcom_7_0_defconfig），DRM_MSM=m
- GPU/display：✅ msm 1.13.0，DP-1/DP-2/HDMI-A-1 + renderD128
- 固件：Radxa 官方 SC8280XP（ADSP/CDSP/VPU running）+ a660 SQE/GMU 进 initrd
- 网络：TC956x 2.5GbE 192.168.0.66
- 存储：NVMe Samsung 238G
- nginx：active；sops：解密成功；zerotier：LTNET 连通
- rmtfs：已移除（无 modem 无必要）
- 失败服务：零
- 音频：❌ qcom-apm probe -2（open item，见上）

### 串口通信方法（mac 本机）

- 串口设备：`/dev/cu.usbmodem57920206431`，115200 8N1
- Python 脚本：`/tmp/serial_cmd2.py`（用 termios 设置波特率，
  os.open 读写串口设备文件，发送命令并读取输出）
- 用法：`python3 /tmp/serial_cmd2.py "command"`
- dragon-q8b 网络通后可直接 SSH -p 2222 root@192.168.0.66

### 安装命令参考（ml-builder SSH 到 opi5p）

```bash
# 拉取闭包（已执行，闭包在 opi5p store）
nix copy --from https://attic.zhyi.xin/lantian --no-check-sigs \
  /nix/store/dhjirswvnzqsyax45cgc35lbk6drv93r-nixos-system-dragon-q8b-26.11pre-git

# 构建 install-tools（已执行）
nix build nixpkgs#nixos-install-tools --no-link --print-out-paths

# 临时停重型服务（若再装需要）
systemctl stop resilio.service clamav-daemon.service podman-tachidesk.service \
  peerbanhelper.service immich-server.service redis-immich.service \
  bitmagnet-dht.service bitmagnet-http.service bitmagnet-queue.service \
  podman-frigate.service

# 手动挂载 SD 卡（nixos-install 不挂 /boot）
mount -t btrfs -o subvol=nix,compress-force=zstd,autodefrag,nosuid,nodev \
  /dev/mmcblk1p2 /mnt/q8b/nix
mkdir -p /mnt/q8b/boot && mount -o fmask=0077,dmask=0077 /dev/mmcblk1p1 /mnt/q8b/boot
mkdir -p /mnt/q8b/nix/persistent && mount -t btrfs -o subvol=persistent,... /dev/mmcblk1p2 /mnt/q8b/nix/persistent
# home subvol 需先修 hardware-configuration 再挂

# 安装
nix shell nixpkgs#nixos-install-tools -c nixos-install --root /mnt/q8b \
  --system /nix/store/dhjirswvnzqsyax45cgc35lbk6drv93r-nixos-system-dragon-q8b-26.11pre-git \
  --no-root-passwd --no-channel-copy

# 卸载 + 恢复服务
umount /mnt/q8b/nix/persistent /mnt/q8b/boot /mnt/q8b/nix; rmdir /mnt/q8b
systemctl start resilio.service ...
```