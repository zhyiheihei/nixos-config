# ml-builder vanilla NixOS 安装日志

本文记录测试虚拟机 `ml-builder` 从 NixOS installer ISO 启动后，如何配置成当前这套磁盘布局，并安装一个可独立启动、可 SSH 登录的 vanilla NixOS 打底系统。

文档截止点：系统安装完成、脱离 ISO 后能从磁盘启动并通过 SSH 登录。后续作者配置构建、`switch-to-configuration`、网络故障分析不包含在本文内。

## 1. 目标状态

测试机：

```text
host: ml-builder
ip: 192.168.3.192
installer user: nixos
boot mode: BIOS / legacy GRUB
disk: /dev/sda
```

目标磁盘布局：

```text
/dev/sda1 -> /boot, ext4, label boot
/dev/sda2 -> /nix,  btrfs, label nix
/          -> tmpfs
```

安装完成后的验证结果：

```text
hostname: ml-builder
NixOS: 26.05.4028.80d591ed473c
/: tmpfs
/nix: /dev/sda2 btrfs
/boot: /dev/sda1 ext4
sshd: active
ssh user: nixos
```

## 2. 从 ISO 启动并进入安装环境

从 NixOS minimal installer ISO 启动 VM。

确认网络地址：

```bash
ip -brief addr
ip route
```

确认安装工具存在：

```bash
nixos-version
command -v nixos-install
command -v nixos-generate-config
```

本次 installer 版本：

```text
26.05.4028.80d591ed473c (Yarara)
```

从 Mac 侧使用 agent forwarding 登录：

```bash
ssh -A nixos@192.168.3.192
```

如果 host key 提示变化，说明这台测试 VM 曾重装或从 ISO 切到磁盘系统，按需清理本机 known_hosts：

```bash
ssh-keygen -R 192.168.3.192
```

## 3. 分区和格式化

警告：下面操作会清空 `/dev/sda`。

确认目标盘：

```bash
lsblk -f /dev/sda
```

创建 BIOS/GRUB 使用的 msdos 分区表：

```bash
sudo parted /dev/sda -- mklabel msdos
sudo parted /dev/sda -- mkpart primary ext4 1MiB 1025MiB
sudo parted /dev/sda -- set 1 boot on
sudo parted /dev/sda -- mkpart primary btrfs 1025MiB 100%
sudo partprobe /dev/sda
```

格式化：

```bash
sudo mkfs.ext4 -F -L boot /dev/sda1
sudo mkfs.btrfs -f -L nix /dev/sda2
```

本次实际 UUID：

```text
/dev/sda1 ext4  label boot  UUID 6c0cf136-42cf-4e04-8bae-f807d68bc806
/dev/sda2 btrfs label nix   UUID 6e81dd1d-ad3f-4c73-ba4c-cde8f256debd
```

## 4. 挂载目标系统

使用与作者 impermanence 思路一致的基础布局：根目录是 tmpfs，持久 Nix store 在 `/nix`，引导文件在 `/boot`。

```bash
sudo mount -t tmpfs tmpfs /mnt
sudo mkdir -p /mnt/boot /mnt/nix
sudo mount /dev/sda1 /mnt/boot
sudo mount /dev/sda2 /mnt/nix
```

检查：

```bash
findmnt /mnt /mnt/boot /mnt/nix
df -h /mnt /mnt/boot /mnt/nix
```

预期：

```text
/mnt      tmpfs
/mnt/boot /dev/sda1 ext4
/mnt/nix  /dev/sda2 btrfs
```

## 5. 准备 vanilla 安装配置

创建配置目录：

```bash
sudo mkdir -p /mnt/etc/nixos
```

写入 `/mnt/etc/nixos/bootstrap-vanilla.nix`：

```nix
{ config, pkgs, lib, ... }:
{
  imports = [ ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  boot.initrd.availableKernelModules = [ "ata_piix" "mptspi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=755" "size=50%" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/6c0cf136-42cf-4e04-8bae-f807d68bc806";
    fsType = "ext4";
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/6e81dd1d-ad3f-4c73-ba4c-cde8f256debd";
    fsType = "btrfs";
    neededForBoot = true;
  };

  networking.hostName = "ml-builder";
  networking.useDHCP = lib.mkDefault true;

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO+BqKSgF+cYVfGvmZJGN5LnWGv7GrLSMYgKwKYPJXvF"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAXn2roZsbvURS+faytLLz2OE1gemC19RMNsPj3Ypnha 2386656187@qq.com"
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    tmux
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
```

说明：

- 这个配置只是打底 vanilla NixOS，不是最终作者配置。
- 它保留 `/` tmpfs、`/nix` btrfs、`/boot` ext4 的目标布局。
- SSH 开在默认 22 端口，用户 `nixos` 和 `root` 都植入公钥。
- 没有写入作者 hardened SSH 的 2222 端口，也没有写 SOPS/impermanence 的完整作者逻辑。

## 6. 可选：给安装环境加临时 swap

如果在 installer 环境里需要构建较多内容，可以在 btrfs 的 `/mnt/nix` 上临时创建 swapfile。

优先使用 btrfs 专用命令：

```bash
sudo btrfs filesystem mkswapfile --size 64g /mnt/nix/swapfile
sudo swapon /mnt/nix/swapfile
free -h
swapon --show
```

如果误用普通 `fallocate`，可能出现：

```text
swapon failed: Invalid argument
```

这是 btrfs swapfile 的常见限制，不代表 NixOS 配置错误。

本次安装环境最终看到：

```text
Swap: 63Gi
```

## 7. 构建 vanilla 系统闭包

直接运行 `nixos-install -I nixos-config=...` 时曾遇到：

```text
error: no build method found
```

因此本次先手动构建 vanilla 系统闭包：

```bash
sudo nix-build '<nixpkgs/nixos>' \
  -A system \
  -I nixos-config=/mnt/etc/nixos/bootstrap-vanilla.nix \
  --no-out-link \
  --show-trace
```

本次构建出的系统闭包：

```text
/nix/store/y2pl8rk0pckhh9mdjbah9q4jqcjrk0h8-nixos-system-ml-builder-26.05.4028.80d591ed473c
```

## 8. 安装到目标磁盘

使用已构建闭包安装，避免 `nixos-install` 重复构建：

```bash
sudo nixos-install \
  --system /nix/store/y2pl8rk0pckhh9mdjbah9q4jqcjrk0h8-nixos-system-ml-builder-26.05.4028.80d591ed473c \
  --no-root-passwd \
  --show-trace
```

成功标志：

```text
installing the boot loader...
setting up /etc...
updating GRUB 2 menu...
installing the GRUB 2 boot loader on /dev/sda...
Installing for i386-pc platform.
Installation finished. No error reported.
installation finished!
```

安装后检查：

```bash
sudo ls -la /mnt/boot
sudo readlink -f /mnt/nix/var/nix/profiles/system
```

本次 `/boot` 出现：

```text
background.png
converted-font.pf2
grub/
kernels/
lost+found/
```

系统 profile 指向：

```text
/nix/store/y2pl8rk0pckhh9mdjbah9q4jqcjrk0h8-nixos-system-ml-builder-26.05.4028.80d591ed473c
```

## 9. 重启并验证脱离 ISO

重启：

```bash
sudo reboot
```

从 Mac 侧等待 SSH：

```bash
ssh -A nixos@192.168.3.192
```

如果 host key 变化，清理 known_hosts 后重连：

```bash
ssh-keygen -R 192.168.3.192
ssh -A nixos@192.168.3.192
```

登录后验证：

```bash
nixos-version
hostname
readlink -f /run/current-system
findmnt /
findmnt /nix
findmnt /boot
findmnt /iso || true
systemctl is-active sshd
hostname -I
```

本次结果：

```text
VERSION=26.05.4028.80d591ed473c (Yarara)
HOST=ml-builder
ROOT=tmpfs tmpfs rw,relatime,size=23222644k,mode=755
NIX=/dev/sda2 btrfs rw,relatime,space_cache=v2,subvolid=5,subvol=/
BOOT=/dev/sda1 ext4 rw,relatime
ISO_MOUNT=
SSHD=active
IP=192.168.3.192
```

这里就是本文截止点：vanilla NixOS 已安装完成，能从磁盘独立启动，SSH 可登录。

## 10. 快照点

建议在这个状态打 VM 快照：

```text
vanilla NixOS installed, disk boot OK, SSH OK
```

这个快照点还没有执行作者配置的 `switch-to-configuration`。

