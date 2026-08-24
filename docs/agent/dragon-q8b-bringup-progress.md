# dragon-q8b NixOS 适配进度文档

> 本文档用于会话崩溃后快速接手。最后更新：2026-08-24 22:25

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
  转发到 opi5p:443 再反代到 router:9000。
- 各链路 curl 均通（403 是 S3 无凭据正常响应，1s 内）：
  - router:9000 direct、opi5p 443 vhost（--resolve）、公网 8443 均 403。
- **关键实证**：`.multipart` 目录最后修改时间 `8月25日 01:02`（正是 attic
  push 报 500 时间 UTC 17:01 = 北京 01:01），说明 attic 的 S3 上传**到达了
  vaults3** 并留下 multipart 残留。所以 500 真实发生在 S3 写入层（NFS
  存储），不是 8443 链路问题。
- vaults3 存储是 NFS 挂载 `192.168.0.40:/nixos`（`/mnt/storage`），历史上有
  `multipart part could not be moved` rename 失败错误（8/20）。

### ⚠️ 新阻塞：闭包不完整（已 GC 部分依赖）

- `nix-store -qR` 新 closure `dhjirsw...`，918 个依赖，其中 **15 个路径
  MISSING**（不在 store）：`gen-hostid`（0kac5cvjsbrnlh2saa2lkjqyn2ik2xq8）、
  `bird`、`sshd.conf-final`、`hm_gitconfig`、`hm_homezhyi.cache.keep` 等。
- 这就是复制报缺签名的同一路径。原因：之前构建成功但没固定 root，被 GC
  删了部分依赖。闭包残缺 → attic push 引用不存在路径会失败。

### 解决方案（进行中）

- **重建 toplevel 并用 out-link 固定 root**（文档「手动补推流程」）：
  `nix build .#nixosConfigurations.dragon-q8b.config.system.build.toplevel \
    --out-link /root/cache-roots/dragon-q8b --max-jobs 28 --cores 28`
- 已在 ml-builder 后台启动（log `/tmp/q8b-rebuild.log`）。
- 完成后 attic push 补推：`attic push lantian /root/cache-roots/dragon-q8b`。

### 待办（新会话接手点）

1. 等待重建完成（约 20 分钟），验证闭包完整（`nix-store -qR` 无 MISSING）。
2. `attic push lantian /root/cache-roots/dragon-q8b` 上传完整闭包。
3. opi5p 用 `nix copy --from https://attic.zhyi.xin/lantian` 拉取（opi5p
   require-sigs=true，但 attic 服务端会签名，用 lantian 公钥校验）。
4. 用户重新接串口，抓带 console 参数的内核启动日志，确认内核启动与网卡
   驱动加载。
5. 若网卡驱动未加载，改 `nixos/hardware/dragon-q8b/default.nix` 的
   `kernelModules`/`initrd.availableKernelModules`。
6. 若 Arbian vendor 内核网卡驱动有问题，换官方 `radxa-pkg/linux-qcom` +
   `radxa_qcom_7_0_defconfig`。