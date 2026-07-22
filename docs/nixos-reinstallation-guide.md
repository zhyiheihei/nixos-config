# NixOS 完整重装指南

本文用于把物理机或虚拟机重新安装为本仓库管理的 NixOS。入口分为两种：

1. 机器已经从 NixOS ISO 启动。
2. 原系统不是 NixOS，且无法挂载 ISO，需要先进入 Alpine RAM 救援环境。

两条路线最终得到相同布局：`/` 是 tmpfs，`/boot` 独立，`/nix` 是持久化
Btrfs，SSH host key 位于 `/nix/persistent/etc/ssh`。目标机只接收已经在
`ml-builder` 构建好的闭包，不在安装机上求值或编译。

本文包含会清空整块磁盘的命令。没有控制台、没有确认磁盘型号、没有保存正式
host key 时，不得执行分区步骤。

## 1. 安装前准备

### 1.1 仓库侧准备

先按[新主机接入规范](./new-host-standard.md)准备：

- `hosts/<hostname>/host.nix`
- `hosts/<hostname>/configuration.nix`
- `hosts/<hostname>/hardware-configuration.nix`
- 唯一的 host `index`、DN42 地址和 ZeroTier node ID
- 每主机 WireGuard 私钥及 `wg-pubkey.nix`
- 正式 SSH host 公钥及对应 SOPS age recipient

个人登录密钥与 SSH host key 是两类密钥：

- 个人登录私钥由 Bitwarden 管理，只把公钥放进 `authorized_keys`。
- SSH host 私钥保存在目标机
  `/nix/persistent/etc/ssh/ssh_host_ed25519_key`，同时用于服务器身份和 SOPS
  解密；其公钥写入 `host.nix`。

如果复用已有 host key，先把私钥安全备份到 Bitwarden。允许在构建机上短期保存
一份 `0600` 权限的灾难恢复副本，但不得提交到 Git，安装验收后应删除该副本。

### 1.2 记录安装变量

以下变量只用于说明。每次安装必须按实际机器填写：

```bash
HOST=usvm
TARGET_IP=35.212.152.140
INSTALL_SSH_PORT=22
DISK=/dev/sda
```

不要假定系统盘一定是 `/dev/sda`。NVMe、VirtIO 和云平台可能显示为
`/dev/nvme0n1`、`/dev/vda` 或其他设备。

### 1.3 只读预检

进入安装环境后先执行：

```bash
date -Is
uname -a
test -d /sys/firmware/efi && echo UEFI || echo BIOS
lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,UUID,PARTUUID,MOUNTPOINTS
ip -brief address
ip route
```

必须从容量、型号、序列号三项确认目标磁盘。安装介质、数据盘和系统盘不明确时
立即停止。

## 2. 选择磁盘布局

入口环境不决定磁盘布局，固件和主机类型才决定。

### 2.1 UEFI 两分区布局

适用于 `usvm` 这类 UEFI VPS，也适用于作者体系中的物理 client：

| 分区 | 大小 | 文件系统 | 挂载点 |
| --- | --- | --- | --- |
| 1 | 512 MiB | FAT32 | `/boot` |
| 2 | 剩余空间 | Btrfs | `/nix` |

最终 `/` 由 `impermanence.nix` 创建为 tmpfs，不创建磁盘根分区。

对应的核心 Nix 配置应类似：

```nix
boot.loader.grub = {
  efiSupport = true;
  device = "nodev";
};

fileSystems."/boot" = {
  device = "/dev/disk/by-uuid/<BOOT_UUID>";
  fsType = "vfat";
  options = [ "fmask=0077" "dmask=0077" ];
};

fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/<NIX_UUID>";
  fsType = "btrfs";
  options = [ "compress-force=zstd" "autodefrag" "nosuid" "nodev" ];
};
```

### 2.2 BIOS 三分区布局

适用于 `sgvm` 这类 BIOS QEMU VM：

| 分区 | 大小 | 文件系统 | 挂载点 |
| --- | --- | --- | --- |
| 1 | 2 MiB | `bios_grub` | 不挂载 |
| 2 | 1 GiB | ext4 | `/boot` |
| 3 | 剩余空间 | Btrfs | `/nix` |

对应的核心 Nix 配置应类似：

```nix
boot.loader.grub.device = "/dev/vda";

fileSystems."/boot" = {
  device = "/dev/disk/by-uuid/<BOOT_UUID>";
  fsType = "ext4";
};

fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/<NIX_UUID>";
  fsType = "btrfs";
  neededForBoot = true;
  options = [ "compress-force=zstd" "autodefrag" "nosuid" "nodev" ];
};
```

云平台设备名稳定时仓库中可能仍使用 `/dev/sda2` 或 `/dev/vda3`。新接入设备默认
使用 UUID；只有确认平台设备名稳定并有明确理由时才保留设备路径。

## 3. 公共分区步骤

本节在 NixOS ISO 和 Alpine RAM 中相同。先设置实际磁盘：

```bash
DISK=/dev/sda

partdev() {
  case "$DISK" in
    *nvme*|*mmcblk*) printf '%sp%s\n' "$DISK" "$1" ;;
    *) printf '%s%s\n' "$DISK" "$1" ;;
  esac
}

lsblk -d -o NAME,SIZE,MODEL,SERIAL "$DISK"
read -r -p "Type ERASE $DISK to continue: " CONFIRM
[ "$CONFIRM" = "ERASE $DISK" ] || exit 1
```

确认字符串是最后一道擦盘门。不得从聊天记录中整段粘贴并跳过确认。

### 3.1 创建 UEFI 布局

```bash
wipefs -a "$DISK"
parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB 513MiB
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart NIX btrfs 513MiB 100%
partprobe "$DISK"
command -v udevadm >/dev/null && udevadm settle

BOOT_DEV=$(partdev 1)
NIX_DEV=$(partdev 2)

mkfs.fat -F 32 -n BOOT "$BOOT_DEV"
mkfs.btrfs -f -L NIX "$NIX_DEV"
```

### 3.2 创建 BIOS 布局

```bash
wipefs -a "$DISK"
parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart BIOSBOOT 1MiB 3MiB
parted -s "$DISK" -- set 1 bios_grub on
parted -s "$DISK" -- mkpart BOOT ext4 3MiB 1027MiB
parted -s "$DISK" -- mkpart NIX btrfs 1027MiB 100%
partprobe "$DISK"
command -v udevadm >/dev/null && udevadm settle

BOOT_DEV=$(partdev 2)
NIX_DEV=$(partdev 3)

mkfs.ext4 -F -L BOOT "$BOOT_DEV"
mkfs.btrfs -f -L NIX "$NIX_DEV"
```

### 3.3 挂载目标系统

```bash
mkdir -p /mnt
mount -t tmpfs -o mode=755,nosuid,nodev,size=80% none /mnt
mkdir -p /mnt/boot /mnt/nix
mount "$BOOT_DEV" /mnt/boot
mount -o compress-force=zstd,autodefrag,nosuid,nodev "$NIX_DEV" /mnt/nix

findmnt -R /mnt
lsblk -f
blkid "$BOOT_DEV" "$NIX_DEV"
```

把现场读取的 UUID 更新到
`hosts/<hostname>/hardware-configuration.nix`，不要照抄其他机器的 UUID。

### 3.4 准备正式 host key

如果已有私钥，从安全介质安装：

```bash
install -d -m 700 /mnt/nix/persistent/etc/ssh
install -m 600 /secure/path/ssh_host_ed25519_key \
  /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key
ssh-keygen -y -f /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key \
  > /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
chmod 644 /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
```

如果这是新主机并决定生成新 host key：

```bash
install -d -m 700 /mnt/nix/persistent/etc/ssh
ssh-keygen -t ed25519 -N '' \
  -f /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key
```

随后核对并记录：

```bash
cat /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -lf /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
```

此时暂停安装，完成以下仓库动作后再构建：

1. 把公钥写入 `hosts/<hostname>/host.nix`。
2. 按 secrets 仓库的 `docs/sops-manual.md` 加入 age recipient 并重新加密。
3. 提交并推送 secrets。
4. 更新主仓库 secrets input，提交并推送主仓库。
5. 构建机 `git pull --ff-only`，确认使用同一个提交。

## 4. 情况一：已经挂载 NixOS ISO

这是首选路线。物理机、PVE VM 或支持虚拟光驱的云平台都应优先使用 ISO。

### 4.1 开启安装环境 SSH

在控制台进入 root shell：

```bash
sudo -i
mkdir -p /root/.ssh
chmod 700 /root/.ssh
printf '%s\n' '<个人登录公钥>' > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
systemctl start sshd
ss -lntp | grep ':22 '
```

先从管理端验证可以登录 ISO，再执行第 3 节的分区、挂载和 host key 步骤。

### 4.2 在构建机生成系统闭包

```bash
cd /nix/src/nixos-config
git pull --ff-only

HOST=usvm
CLOSURE=$(nix build --no-link --print-out-paths \
  ".#nixosConfigurations.${HOST}.config.system.build.toplevel" -L)

printf 'CLOSURE=%s\n' "$CLOSURE"
```

先确认闭包存在：

```bash
test -x "$CLOSURE/bin/switch-to-configuration"
nix-store --query --requisites "$CLOSURE" >/dev/null
```

### 4.3 把闭包直接写入目标 store

NixOS ISO 自己的 `/nix` 通常在内存中。不要先把完整闭包复制到 ISO 的临时
store，应把 remote store 根指向 `/mnt`：

```bash
TARGET_IP=35.212.152.140
INSTALL_SSH_PORT=22

NIX_SSHOPTS="-p ${INSTALL_SSH_PORT} -o IdentitiesOnly=yes" \
  nix copy --no-check-sigs \
  --to "ssh-ng://root@${TARGET_IP}?remote-store=local%3Froot%3D%2Fmnt" \
  "$CLOSURE"
```

使用 Bitwarden SSH agent 时，给 `NIX_SSHOPTS` 增加一个只包含目标公钥的
`-i /path/to/login-key.pub`，避免 `Too many authentication failures`。

### 4.4 执行安装

回到 NixOS ISO，把构建机输出的完整 store path 填入 `CLOSURE`：

```bash
CLOSURE=/nix/store/<hash>-nixos-system-<hostname>-<version>

test -x "$CLOSURE/bin/switch-to-configuration"
# 使用 --no-root-passwd 前，必须确认该闭包已包含正式个人登录公钥。
nixos-install --root /mnt --system "$CLOSURE" \
  --no-root-passwd --no-channel-copy
```

安装完成后执行第 6 节的重启前验收。

## 5. 情况二：原系统不是 NixOS

适用于只能 SSH 登录原 Linux、无法挂载 ISO 的 VPS。不要在 Ubuntu、Debian 或
Alpine 的现有根文件系统上运行 `nixos-rebuild switch`，也不要让一键脚本直接
生成最终磁盘布局。

### 5.1 进入 Alpine RAM 救援环境

在原系统中下载 [bin456789/reinstall](https://github.com/bin456789/reinstall)，
先检查脚本和当前网络参数，然后只启动救援环境：

```bash
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
bash reinstall.sh alpine --hold 1 \
  --ssh-key '<个人登录公钥>' \
  --ssh-port 22
```

`--hold 1` 只进入内存安装环境，不自动重装。脚本明确不支持 OpenVZ/LXC；这类
虚拟化必须由宿主机或供应商镜像处理。

重启后从控制台确认运行的是 Alpine RAM，而不是旧系统：

```bash
cat /etc/os-release
findmnt /
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
```

如果重启又进入旧系统，说明云平台启动顺序或 EFI 引导没有进入救援环境。先修正
启动项，不得在仍挂载旧根分区时格式化系统盘。

### 5.2 安装分区工具

```bash
apk update
apk add bash coreutils curl btrfs-progs dosfstools e2fsprogs \
  findutils gptfdisk openssh-client parted rsync util-linux
```

执行第 3 节的分区、挂载和 host key 步骤。

### 5.3 让 Alpine 的 Nix store 位于目标 Btrfs

第 3 节已经把目标 Btrfs 挂载在 `/mnt/nix`。把它绑定到救援环境的 `/nix`：

```bash
mkdir -p /nix
mount --bind /mnt/nix /nix
findmnt /nix
findmnt /mnt/nix
```

启用与当前 Alpine 版本一致的 community 仓库；禁止混用不同 Alpine 分支：

```bash
ALPINE_BRANCH="v$(cut -d. -f1,2 /etc/alpine-release)"
COMMUNITY="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/community"
grep -qxF "$COMMUNITY" /etc/apk/repositories || \
  printf '%s\n' "$COMMUNITY" >> /etc/apk/repositories

apk update
apk add nix nix-openrc
```

配置仅供 RAM 救援环境使用的 Nix daemon：

```bash
install -d -m 755 /etc/nix
cat > /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
sandbox = false
trusted-users = root
EOF

rc-service nix-daemon start
nix store ping --store local
```

### 5.4 构建并复制闭包和安装工具

在 `ml-builder`：

```bash
cd /nix/src/nixos-config
git pull --ff-only

HOST=usvm
CLOSURE=$(nix build --no-link --print-out-paths \
  ".#nixosConfigurations.${HOST}.config.system.build.toplevel" -L)
INSTALL_TOOLS=$(nix build --no-link --print-out-paths \
  nixpkgs#nixos-install-tools)

printf 'CLOSURE=%s\nINSTALL_TOOLS=%s\n' "$CLOSURE" "$INSTALL_TOOLS"
```

Alpine 的 `/nix` 已经是目标磁盘，因此直接复制到默认 remote store：

```bash
TARGET_IP=35.212.152.140
INSTALL_SSH_PORT=22

NIX_SSHOPTS="-p ${INSTALL_SSH_PORT} -o IdentitiesOnly=yes" \
  nix copy --no-check-sigs \
  --to "ssh-ng://root@${TARGET_IP}" \
  "$CLOSURE" "$INSTALL_TOOLS"
```

如果目标内存较小，保持目标机只接收闭包；不要在 Alpine 中运行 flake 求值或构建。

### 5.5 使用官方安装工具安装

回到 Alpine RAM，把上一步输出的完整 store path 填入变量：

```bash
CLOSURE=/nix/store/<hash>-nixos-system-<hostname>-<version>
INSTALL_TOOLS=/nix/store/<hash>-nixos-install-tools-<version>

test -x "$CLOSURE/bin/switch-to-configuration"
test -x "$INSTALL_TOOLS/bin/nixos-install"

"$INSTALL_TOOLS/bin/nixos-install" \
  --root /mnt --system "$CLOSURE" \
  --no-root-passwd --no-channel-copy
```

这一步只使用构建机已经产出的闭包。它不会把 Alpine 变成长期系统，重启后直接
进入目标 NixOS。

## 6. 重启前验收

任何入口都必须完成以下检查后才能重启。

### 6.1 文件系统和 profile

```bash
findmnt -R /mnt
lsblk -f
blkid "$BOOT_DEV" "$NIX_DEV"

readlink -f /mnt/nix/var/nix/profiles/system
test -x /mnt/nix/var/nix/profiles/system/bin/switch-to-configuration
test -f /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key
ssh-keygen -lf /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
```

profile 必须指向目标 Btrfs 内真实存在的闭包。这里缺失会导致
`initrd-find-nixos-closure.service` 启动失败。

### 6.2 引导文件

UEFI：

```bash
find /mnt/boot/EFI -maxdepth 3 -type f -print
case "$(uname -m)" in
  x86_64) FALLBACK=/mnt/boot/EFI/BOOT/BOOTX64.EFI ;;
  aarch64) FALLBACK=/mnt/boot/EFI/BOOT/BOOTAA64.EFI ;;
  *) echo "Check the UEFI fallback filename for this architecture"; exit 1 ;;
esac
test -f "$FALLBACK" || efibootmgr -v
```

云平台不保存 EFI NVRAM 时，必须存在对应架构的 fallback 路径；x86_64 是
`EFI/BOOT/BOOTX64.EFI`，aarch64 是 `EFI/BOOT/BOOTAA64.EFI`。

BIOS：

```bash
test -f /mnt/boot/grub/i386-pc/normal.mod
test -f /mnt/boot/grub/i386-pc/btrfs.mod
```

缺少这两个模块时不要重启，否则可能进入 `grub rescue>`。

### 6.3 卸载并重启

NixOS ISO：

```bash
sync
umount -R /mnt
reboot
```

Alpine RAM 先解除 `/nix` bind mount：

```bash
sync
umount /nix
umount -R /mnt
reboot
```

不要在系统重新上线前卸载控制台或删除云平台救援入口。

## 7. 第一次冷启动验收

安装环境通常使用 SSH 22，仓库正式系统通常使用 2222。先等待系统完成首次启动，
再依次测试：

```bash
ssh -p 2222 root@<target>
```

进入后检查：

```bash
hostname
readlink -f /run/current-system

findmnt -no SOURCE,FSTYPE,OPTIONS /
findmnt -no SOURCE,FSTYPE,OPTIONS /boot
findmnt -no SOURCE,FSTYPE,OPTIONS /nix

systemctl is-active sshd sops-install-secrets
systemctl --failed --no-pager
ss -lntp | grep ':2222 '
ssh-keygen -lf /nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
```

预期结果：

- `/` 为 tmpfs。
- `/boot` 为预期的 vfat 或 ext4。
- `/nix` 为 Btrfs，包含 `compress-force=zstd`、`nosuid`、`nodev`。
- 当前 system closure 与构建机输出一致。
- SSH host key 指纹与 `host.nix` 一致。
- SOPS 可以使用持久化 host key 解密。

验证 host key 后再更新管理端 `known_hosts`。不要用
`StrictHostKeyChecking=no` 长期绕过冲突。

Server 继续检查：

```bash
zerotier-cli listnetworks
wg show
birdc show protocols
systemctl start rsync-nix-sync-servers.service
```

ZeroTier `OK`、WireGuard 有近期 handshake、BIRD 为 `Established` 才表示 LTNET
完整。首次证书同步或 BGP 尚未建立导致 nginx/rsync 失败，不代表磁盘、UUID或引导
失败，应按网络层继续排查。

冷启动验收完成后，才使用 Colmena 部署后续配置：

```bash
cd /nix/src/nixos-config
nix run .#colmena -- apply --on <hostname>
```

## 8. 两阶段安装适用场景

以下情况使用 bootstrap + final 两阶段，不要在安装环境在线激活完整配置：

- 物理 client 带桌面和大量服务。
- 安装时网卡名、GPU 或引导方式还未完全确认。
- 完整闭包很大，需要先证明硬盘可以独立启动。

第一阶段安装仓库中已准备好的最小 bootstrap closure，只提供磁盘、DHCP、SSH 和
持久化 host key。冷启动验证成功后，在构建机复制 final closure，然后只设置为
下次启动：

```bash
FINAL=/nix/store/<hash>-nixos-system-<hostname>-<version>
nix-env -p /nix/var/nix/profiles/system --set "$FINAL"
"$FINAL/bin/switch-to-configuration" boot
systemctl reboot
```

完整实操参考 [`old/ml-2700u/reinstall-log.md`](./old/ml-2700u/reinstall-log.md)。

## 9. 常见故障判断

| 现象 | 优先检查 | 处理原则 |
| --- | --- | --- |
| `initrd-find-nixos-closure.service` 失败 | `/nix` 是否挂载、system profile 是否指向存在的闭包 | 从救援环境重新挂载并修 profile，不要再次格式化 |
| `grub rescue>` | BIOS GRUB 的 `normal.mod`、`btrfs.mod` 和安装磁盘 | 修复 GRUB 文件或重装 bootloader，不动 `/nix` |
| EFI 找不到启动项 | 对应架构的 `EFI/BOOT/BOOT*.EFI`、NVRAM 启动项 | 补 fallback 引导文件或修云平台启动顺序 |
| SSH host key 改变 | 持久化私钥是否为安装前确定的那把 | 先核对指纹，再更新 `known_hosts` |
| 22 和 2222 都暂时不通 | 控制台、启动日志、DHCP、sshd | 先确认系统是否启动，不要把网络故障当磁盘故障 |
| `No route to host`、BIRD Idle | WireGuard endpoint、WSS transport、对端配置 | 修 LTNET 对端和路由，不改分区 |
| rsync/nginx 首次失败 | 证书尚未从 colocrossing 同步 | 先恢复 LTNET，再重跑 rsync 和 nginx |
| Colmena 返回 code 4 | `systemctl --failed` 中的具体应用 | 系统可能已经切换成功，单独修失败服务 |
| `Too many authentication failures` | SSH agent 提供了过多密钥 | 使用 `IdentitiesOnly=yes` 和公钥 selector 文件 |
| 闭包复制看似长时间无输出 | 目标 substituter 超时或正在复制大路径 | 检查进程；必要时使用 Colmena `--no-substitute` 直接传输 |

## 10. 安装完成清单

- [ ] 目标磁盘、固件模式和分区表有安装记录。
- [ ] `hardware-configuration.nix` 与现场 UUID、文件系统一致。
- [ ] `/`、`/boot`、`/nix` 挂载符合本仓库结构。
- [ ] 正式 SSH host 私钥已持久化，并在 Bitwarden 有恢复副本。
- [ ] host 公钥、SOPS recipient 和 secrets rekey 已提交。
- [ ] 冷启动后 SSH 2222、SOPS 和当前 closure 已验证。
- [ ] ZeroTier、WireGuard、BIRD 和 rsync 链路已验证。
- [ ] `systemctl --failed` 中每个失败单元都已解释或修复。
- [ ] 管理端 `known_hosts` 已用核验后的新记录更新。
- [ ] 安装期临时密码、临时登录公钥和临时私钥副本已清理。
