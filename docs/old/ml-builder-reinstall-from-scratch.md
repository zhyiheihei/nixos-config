# ml-builder 从零重装复刻指南

本文用于新对话直接接手 `ml-builder` 测试机重装。

目标是尽量原汁原味复刻作者配置，而不是在旧系统上继续 `switch`。上一轮已经证明，在单 ext4 根分区的旧 NixOS 上直接切到作者式 impermanence 会导致 local-fs、preservation、sshd 等 unit 连锁失败。

## 1. 当前目标

目标机器：

```text
host: ml-builder
ip: 192.168.3.176
arch: x86_64-linux
boot: BIOS/legacy GRUB, not EFI
```

目标 host 文件：

```text
hosts/ml-builder/host.nix
hosts/ml-builder/configuration.nix
hosts/ml-builder/hardware-configuration.nix
```

目标模块：

```nix
imports = [
  ../../nixos/minimal.nix
  ./hardware-configuration.nix
];
```

原汁原味标准：

- 用户名保持作者默认 `lantian`。
- SSH 端口保持作者 hardened SSH 默认 `2222`。
- `/` 使用 tmpfs，由 `nixos/minimal-components/impermanence.nix` 声明。
- 持久数据放在 `/nix/persistent`。
- SOPS age key 路径保持 `/nix/persistent/etc/ssh/ssh_host_ed25519_key`。
- 优先使用作者默认 kernel：`pkgs.nur-xddxdd.lantianLinuxCachyOS.lts-lto`。
- 不改公共模块绕过问题；个人化只放在 `hosts/ml-builder/*` 和私有 `nixos-secrets`。

## 2. 目标磁盘布局

`hosts/ml-builder/hardware-configuration.nix` 当前按这个布局写：

```text
/dev/sda1 -> /boot, ext4
/dev/sda2 -> /nix,  btrfs
/          -> tmpfs, 由 impermanence 模块声明
```

对应 Nix 配置：

```nix
boot.loader.grub.device = "/dev/sda";

fileSystems."/boot" = {
  device = "/dev/sda1";
  fsType = "ext4";
};

fileSystems."/nix" = {
  device = "/dev/sda2";
  fsType = "btrfs";
  options = [
    "compress-force=zstd"
    "autodefrag"
    "nosuid"
    "nodev"
  ];
};
```

注意：

- 不要再用单分区 ext4 当 `/`。
- 不需要在硬件配置里声明 `/`，作者模块会把 `/` 设成 tmpfs。
- 如果虚拟磁盘不是 `/dev/sda`，必须同步修改 `boot.loader.grub.device` 和分区路径。

## 3. 启动安装环境

从 NixOS installer ISO 启动测试机。

进入 installer 后先确认磁盘：

```bash
lsblk -f
cat /sys/firmware/efi/fw_platform_size 2>/dev/null || echo "legacy BIOS"
```

期望：

```text
legacy BIOS
```

如果机器实际是 EFI 启动，不要继续套本文的 BIOS GRUB 布局，需要改成 EFI 分区方案。

设置 root 密码或直接放 SSH key，保证 Mac 能连进 installer。

临时启用 SSH：

```bash
systemctl start sshd
ip addr
```

从 Mac 测试：

```bash
ssh -A root@192.168.3.176
```

## 4. 处理 SOPS host key

作者配置中 SOPS 解密使用：

```nix
sops.age.sshKeyPaths = [ "/nix/persistent/etc/ssh/ssh_host_ed25519_key" ];
```

因此安装前必须决定 host key 策略。

### 方案 A：能从旧系统/救援环境拿到旧 key

优先保留旧 key，这样不需要重加密 secrets。

如果旧分区可挂载：

```bash
mkdir -p /mnt-old
mount /dev/sda1 /mnt-old
ls -l /mnt-old/etc/ssh/ssh_host_ed25519_key
```

先复制到 installer 内存目录备份：

```bash
mkdir -p /root/ml-builder-key-backup
cp -a /mnt-old/etc/ssh/ssh_host_ed25519_key /root/ml-builder-key-backup/
cp -a /mnt-old/etc/ssh/ssh_host_ed25519_key.pub /root/ml-builder-key-backup/ 2>/dev/null || true
chmod 600 /root/ml-builder-key-backup/ssh_host_ed25519_key
umount /mnt-old
```

### 方案 B：拿不到旧 key

生成新 key：

```bash
mkdir -p /root/ml-builder-key-backup
ssh-keygen -t ed25519 -N "" -f /root/ml-builder-key-backup/ssh_host_ed25519_key
```

然后必须更新私有 `nixos-secrets`：

1. 从新 host key 计算 age recipient。
2. 加到 `.sops.yaml`。
3. 重新加密会在 `ml-builder` 上解密的 SOPS 文件。

如果跳过这步，系统可能能启动，但 `sops-install-secrets.service` 会失败。

## 5. 重新分区

警告：本节会清空 `/dev/sda`。

确认目标盘：

```bash
lsblk -f /dev/sda
```

分区：

```bash
parted /dev/sda -- mklabel msdos
parted /dev/sda -- mkpart primary ext4 1MiB 1025MiB
parted /dev/sda -- set 1 boot on
parted /dev/sda -- mkpart primary btrfs 1025MiB 100%
partprobe /dev/sda
```

格式化：

```bash
mkfs.ext4 -F -L boot /dev/sda1
mkfs.btrfs -f -L nix /dev/sda2
```

检查：

```bash
lsblk -f /dev/sda
```

期望：

```text
sda1 ext4  boot
sda2 btrfs nix
```

## 6. 挂载安装目标

作者式目标挂载：

```bash
mount -t tmpfs tmpfs /mnt
mkdir -p /mnt/boot /mnt/nix
mount /dev/sda1 /mnt/boot
mount /dev/sda2 /mnt/nix
mkdir -p /mnt/nix/persistent
```

准备持久目录：

```bash
mkdir -p /mnt/nix/persistent/etc/ssh
mkdir -p /mnt/nix/persistent/var/lib/nixos
```

放入 host key：

```bash
cp -a /root/ml-builder-key-backup/ssh_host_ed25519_key /mnt/nix/persistent/etc/ssh/
cp -a /root/ml-builder-key-backup/ssh_host_ed25519_key.pub /mnt/nix/persistent/etc/ssh/ 2>/dev/null || true
chmod 600 /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key
```

检查挂载：

```bash
findmnt /mnt /mnt/boot /mnt/nix
ls -l /mnt/nix/persistent/etc/ssh
```

## 7. 准备配置仓库

推荐从 Mac 把当前工作树同步到 installer，避免 installer 内处理 GitHub 私有仓库认证。

在 installer：

```bash
mkdir -p /mnt/etc/nixos
```

在 Mac 仓库目录：

```bash
rsync -a \
  --exclude .git \
  --exclude result \
  --exclude 'result-*' \
  --exclude .DS_Store \
  ./ root@192.168.3.176:/mnt/etc/nixos/
```

回到 installer 检查：

```bash
cd /mnt/etc/nixos
ls hosts/ml-builder
sed -n '1,120p' hosts/ml-builder/hardware-configuration.nix
```

必须确认：

- `configuration.nix` 没有 `lantian.kernel = pkgs.linux;`。
- `hardware-configuration.nix` 使用 `/dev/sda1` 和 `/dev/sda2`。
- `flake.lock` 锁到个人 secrets `a6cf395` 或更新后的有效提交。

## 8. 安装前构建检查

在 installer：

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
cd /mnt/etc/nixos
```

先 eval 关键项：

```bash
nix eval --raw .#nixosConfigurations.ml-builder.config.networking.hostName
nix eval --raw .#nixosConfigurations.ml-builder.pkgs.stdenv.hostPlatform.system
nix eval --raw .#nixosConfigurations.ml-builder.config.boot.kernelPackages.kernel.name
nix eval --json .#nixosConfigurations.ml-builder.config.users.users.lantian.openssh.authorizedKeys.keys
```

期望：

```text
ml-builder
x86_64-linux
linux-cachyos-lts-lto-...
["ssh-ed25519 ..."]
```

如果 kernel 不是 `linux-cachyos-lts-lto`，说明还残留了临时 kernel 覆盖，不符合原汁原味目标。

构建：

```bash
nix build .#nixosConfigurations.ml-builder.config.system.build.toplevel --show-trace -L
```

已知风险：

- 作者默认 CachyOS LTO kernel 可能耗时很长。
- 之前在 `192.168.3.176` 本地构建 `linux-cachyos-lts-lto-6.18.36` 时，`ld.lld` 在 `amdgpu.o` 崩溃。
- 如果要百分百使用作者内核，建议准备能命中的 binary cache，或用另一台 builder 构建后复制 store path。

## 9. 执行安装

构建过后安装：

```bash
nixos-install --flake .#ml-builder --no-root-passwd --show-trace
```

安装完成后不要立刻重启，先检查：

```bash
ls -l /mnt/boot
ls -l /mnt/nix/persistent/etc/ssh
findmnt /mnt /mnt/boot /mnt/nix
```

如果安装过程报 SOPS 解密失败：

- 检查 `/mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key` 是否存在。
- 检查该 host key 是否对应 `nixos-secrets` 里的 age recipient。
- 必要时更新并重新加密 secrets 后再安装。

## 10. 首次重启

重启：

```bash
reboot
```

首次启动后从 Mac 测试：

```bash
ssh -A -p 2222 lantian@192.168.3.176
```

如果 `lantian` 登录失败，试 root：

```bash
ssh -A -p 2222 root@192.168.3.176
```

登录后检查：

```bash
hostname
findmnt / /boot /nix /nix/persistent
readlink -f /run/current-system
systemctl --failed --no-pager
systemctl status sops-install-secrets.service --no-pager -l
systemctl status sshd.service --no-pager -l
```

期望：

- `hostname` 是 `ml-builder`。
- `/` 是 tmpfs。
- `/boot` 是 `/dev/sda1` ext4。
- `/nix` 是 `/dev/sda2` btrfs。
- `/nix/persistent` 存在。
- SSH 在 2222 端口工作。
- `sops-install-secrets.service` 不失败。

## 11. 如果启动失败

如果 SSH 连不上：

1. 通过 VM 控制台进入机器。
2. 在 GRUB 里查看是否有 NixOS generation。
3. 如果无法进入系统，重新从 installer ISO 启动。
4. 挂载检查：

```bash
mount -t tmpfs tmpfs /mnt
mkdir -p /mnt/boot /mnt/nix
mount /dev/sda1 /mnt/boot
mount /dev/sda2 /mnt/nix
ls -l /mnt/nix/persistent/etc/ssh
```

5. 检查 bootloader 文件：

```bash
find /mnt/boot -maxdepth 3 -type f | sort | head -100
```

6. 检查是否能 chroot：

```bash
nixos-enter --root /mnt
```

## 12. 新对话接手摘要

给新对话的最短上下文：

```text
目标：重装 ml-builder，百分百按作者 NixOS 配置复刻。
机器：192.168.3.176，x86_64，BIOS/legacy GRUB。
目标布局：/dev/sda1 -> /boot ext4，/dev/sda2 -> /nix btrfs，/ -> tmpfs。
必须准备：/nix/persistent/etc/ssh/ssh_host_ed25519_key，用作 SOPS age key。
secrets：主仓库 flake.lock 已更新到个人 secrets a6cf395，ssh/lantian.nix 已有登录公钥。
不要做：不要把 / 改回 ext4，不要关闭 preservation，不要把用户改成 zhyi，不要临时切 pkgs.linux。
已知风险：作者默认 CachyOS LTO kernel 本地构建可能失败，需要缓存或其它 builder。
安装命令：nixos-install --flake .#ml-builder --no-root-passwd --show-trace。
首次登录：ssh -A -p 2222 lantian@192.168.3.176。
```

