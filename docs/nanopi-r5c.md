# NanoPi R5C NixOS 镜像适配与安装

本文记录 NanoPi R5C（Rockchip RK3568）在本仓库中的适配、构建和刷写流程。目标布局
遵循作者物理主机的约定，而不是使用普通的持久化 ext4 根目录：

- tmpfs `/`
- FAT32 `/boot`，卷标 `FIRMWARE`
- Btrfs `/nix`，卷标 `NIXOS_NIX`
- 持久化目录 `/nix/persistent`

当前主机配置位于 [`hosts/nanopi-r5c/`](../hosts/nanopi-r5c/)。

## 1. 构建环境与分工

本次使用两台机器：

| 机器 | 系统 | 用途 |
| --- | --- | --- |
| `zhyi@192.168.0.60` | Ubuntu | 运行官方 Armbian build framework，验证内核、DTB 和 U-Boot |
| `root@192.168.0.50:2222` | NixOS `ml-builder` | 求值并构建最终 NixOS SD 镜像 |

Armbian 构建框架依赖 Debian/Ubuntu 宿主环境。直接在 NixOS 上执行
`./compile.sh` 会缺少 `dialog`、`fuser`、`linux-version`、`locale-gen` 等宿主工具，
且框架不能在非 Debian/Ubuntu 系统上自动安装依赖。因此 Armbian 侧使用 Ubuntu，
最终镜像仍由 NixOS 构建机生成。

配置仓库以 Git 远端为唯一同步基准。修改必须先在本地提交并 push，再由构建机
pull；不要用 `rsync` 覆盖构建机的正式工作树。

```bash
# 本地
git push

# ml-builder
cd /nix/src/nixos-config
git pull --ff-only
```

## 2. Armbian 硬件支持验证

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

Armbian 内核配置已确认包含 Rockchip、MMC、PCIe、DWMAC/STMMAC、RTL8169、ext4、
Btrfs 和串口支持。

这些 Armbian 产物用于确认硬件支持和提供故障回退依据。当前 NixOS 镜像不直接
复制 Armbian 的 Debian 包，而是使用 Nixpkgs 的 Linux 6.18、R5C DTS 和 U-Boot
源码完成可复现构建。

## 3. NixOS 配置设计

### 内核

不要直接设置：

```nix
boot.kernelPackages = pkgs.linuxPackages_6_18;
```

这会绕过作者在 `nixos/minimal-components/kernel.nix` 中的
`myKernelPackageFor`，导致 `nft-fullcone`、`nullfsvfs`、`r8125` 等自定义内核
模块属性消失。R5C 与作者 `lt-rpi4` 使用同一接口：

```nix
lantian.kernel = lib.mkForce pkgs.linux_6_18;
```

设备树选择：

```nix
hardware.deviceTree.name = "rockchip/rk3568-nanopi-r5c.dtb";
```

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

镜像第一分区从 16 MiB 开始，避免覆盖两个引导载荷。

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

镜像预先创建：

```text
/nix/persistent/etc/ssh
/nix/var/nix/profiles/system
/nix/nix-path-registration
```

首次启动时生成独立的 Ed25519 SSH host key，私钥不会进入 Nix store 或镜像
derivation。

## 4. 求值与构建

先确认分支和提交：

```bash
ssh -p 2222 root@192.168.0.50
cd /nix/src/nixos-config

git status --short --branch
git pull --ff-only
```

求值 SD 镜像：

```bash
nix eval \
  .#nixosConfigurations.nanopi-r5c.config.system.build.sdImage.drvPath \
  --show-trace
```

提交 `60c9f2b9` 已成功求值得到：

```text
/nix/store/85ak4s247bkimdm3xzq8xh72vq6a0wxg-nixos-image-sd-card-26.11pre-git-aarch64-linux.img.zst.drv
```

正式构建建议放入 tmux：

```bash
tmux new -s r5c-build
cd /nix/src/nixos-config

nix build \
  .#nixosConfigurations.nanopi-r5c.config.system.build.sdImage \
  --out-link result-r5c \
  --print-build-logs \
  --show-trace
```

断线后恢复：

```bash
tmux attach -t r5c-build
```

成功后检查：

```bash
find -L result-r5c -maxdepth 3 -type f -printf '%p  %s bytes\n'

IMAGE="$(find -L result-r5c/sd-image -type f -name '*.img.zst' -print -quit)"
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
  .#nixosConfigurations.nanopi-r5c.config.system.build.sdImage \
  --out-link result-r5c \
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

## 6. 首次启动与验收

串口不方便连接时，将两个网口中的任意一个接入带 DHCP 的局域网再上电。配置会在
所有 Ethernet 接口请求 DHCP，并尝试把两个 PCIe RTL8125 网口命名为 `lan1` 和
`wan1`。

通过路由器租约查找地址，或尝试：

```bash
ping nanopi-r5c.local
ssh -p 2222 root@nanopi-r5c.local
```

也可以使用 22 端口或实际 DHCP 地址。登录后检查：

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

test -s /nix/persistent/etc/ssh/ssh_host_ed25519_key
readlink -f /nix/var/nix/profiles/system
```

必须确认：

- `/` 的类型是 tmpfs；
- `/boot` 来自 `FIRMWARE`；
- `/nix` 来自 `NIXOS_NIX`，并启用预期的 Btrfs 选项；
- 至少一个网口取得地址；
- SSH host key 位于持久目录；
- 冷启动后仍能找到 system closure 并正常进入系统。

## 7. 尚待真机确认

镜像构建成功不等于硬件验收完成。首次刷写后仍需确认：

- U-Boot 能从目标介质启动并读取 extlinux；
- Linux 6.18 的 R5C DTB 与整机硬件版本匹配；
- 两个 RTL8125 网口的 PCI 路径和 `lan1`/`wan1` 命名正确；
- TF、eMMC、NVMe（如安装）工作正常；
- 重启和完全断电后的冷启动正常；
- 无串口条件下可持续通过 DHCP、mDNS 和 SSH 找回设备。

首次启动稳定后，再按[新主机接入规范](./new-host-standard.md)补正式 host key、
SOPS recipient、固定网络身份和后续服务，不能把首次启动自动生成的密钥遗漏在
正式 secrets 流程之外。
