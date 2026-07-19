# ml-2700u 两阶段重装实操记录

本文记录 2026-07-11 对 `ml-2700u` 的实际重装过程。目标是先按作者的
impermanence 磁盘结构安装一个可独立启动的最小系统，确认已经脱离 ISO，
再安装仓库中的完整 client 配置。

## 最终磁盘结构

安装目标是 238.5 GiB 的 T253T SSD。安装时它是 `/dev/sdc`，拔除或忽略
安装介质后变为 `/dev/sda`，因此配置必须使用 UUID，不能依赖设备名。

| 挂载点 | 文件系统 | UUID | 说明 |
| --- | --- | --- | --- |
| `/` | tmpfs | - | `mode=755,nosuid,nodev,size=80%` |
| `/boot` | FAT32 | `E619-53C2` | 1 GiB EFI System Partition |
| `/nix` | Btrfs | `6fd54081-54f1-4977-8263-ca83cf81e55f` | 其余磁盘空间 |

`/nix` 使用作者的挂载选项：

```text
compress-force=zstd,autodefrag,nosuid,nodev
```

SSH host key 持久化在：

```text
/nix/persistent/etc/ssh/ssh_host_ed25519_key
```

这台机器的 ED25519 host key 指纹应为：

```text
SHA256:ce3yUHrCHmF9p6IDKkej9pe1fYsZQscYNXGBNXips74
```

## 安装原则

1. 不在旧 ext4 根文件系统上直接切换到 tmpfs 根。
2. 不把完整仓库配置当作 ISO 环境中的第一次安装配置。
3. 第一阶段只安装可启动、可联网、可 SSH 的 bootstrap 系统。
4. 重启并确认机器已经从 SSD 启动后，才进入第二阶段。
5. 第二阶段先复制完整系统闭包，再把它设置为下一次启动项。
6. 使用 `switch-to-configuration boot`，重启后才激活完整系统。

## 第一阶段：安装 bootstrap

进入 NixOS ISO 后，先确认启动模式、磁盘和网卡：

```bash
test -d /sys/firmware/efi && echo UEFI
lsblk -o NAME,SIZE,MODEL,FSTYPE,MOUNTPOINTS
ip -brief address
```

本次保留原 GPT 分区尺寸，重新格式化 ESP 和 Nix 分区。执行任何格式化前，
必须再次用磁盘型号和容量确认目标不是 Ventoy 安装 U 盘。

安装挂载结构：

```bash
mount -t tmpfs -o mode=755,nosuid,nodev,size=80% none /mnt
mkdir -p /mnt/boot /mnt/nix
mount /dev/disk/by-uuid/E619-53C2 /mnt/boot
mount -o compress-force=zstd,autodefrag,nosuid,nodev \
  /dev/disk/by-uuid/6fd54081-54f1-4977-8263-ca83cf81e55f /mnt/nix
```

bootstrap 配置只包含以下能力：

- tmpfs `/`、FAT32 `/boot` 和 Btrfs `/nix`
- GRUB UEFI 启动
- NetworkManager DHCP
- OpenSSH 端口 22，使用密钥登录
- 从 `/nix/persistent/etc/ssh` 读取持久化 host key
- `git` 和基础维护工具

执行 `nixos-install` 后先重启，不立即加载完整 client 配置。

## 脱离 ISO 后的检查

bootstrap 第一次从 SSD 启动后检查：

```bash
findmnt /
findmnt /boot
findmnt /nix
systemctl is-system-running
systemctl --failed --no-pager
ssh-keygen -lf /nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
```

本次检查结果为：根目录是 tmpfs、`/nix` 是新 Btrfs、DHCP 地址正常、SSH
端口 22 正常、没有失败单元，并且 host key 指纹保持不变。

## 第二阶段：安装完整仓库系统

本地仓库是配置基准，远端机器只允许拉取。本次用于磁盘布局的提交是：

```text
2944f109 ml-2700u: adopt persistent nix disk layout
```

构建机先构建完整系统：

```bash
nix build \
  .#nixosConfigurations.ml-2700u.config.system.build.toplevel \
  -L --out-link /root/cache-roots/ml-2700u
```

然后从构建机通过局域网向仍运行 bootstrap 的目标机复制完整闭包：

```bash
NIX_SSHOPTS='-p 22 -o HostKeyAlias=ml-2700u.zhyi.cc' \
  nix copy --to ssh://root@192.168.2.237 /root/cache-roots/ml-2700u
```

本次共复制 8989 个 store path，闭包逻辑大小约 71.6 GiB。复制完成后先验证：

```bash
FINAL=/nix/store/l1ah1blhnn7fy7s5jn29cm9y3p8zafzg-nixos-system-ml-2700u-26.11pre-git
test -x "$FINAL/bin/switch-to-configuration"
nix-store --query --requisites "$FINAL" >/dev/null
```

只把它设置为下次启动系统，不在 bootstrap 中在线激活：

```bash
nix-env -p /nix/var/nix/profiles/system --set "$FINAL"
"$FINAL/bin/switch-to-configuration" boot
systemctl reboot
```

GRUB 安装成功后，正式系统使用 SSH 端口 `2222`。

## 最终验收

```bash
ssh -A -p 2222 root@192.168.2.237

readlink -f /run/current-system
findmnt /
findmnt /boot
findmnt /nix
systemctl is-system-running
systemctl --failed --no-pager
systemctl status sshd --no-pager
ss -lntp | grep 2222
ssh-keygen -lf /nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
```

本次最终系统成功进入图形桌面，Niri 与 DMS 用户服务均正常运行，端口
`2222` 可以使用原 host key 登录。

## 重要避坑

- `/dev/sdX` 会随安装介质和启动顺序变化，只在确认磁盘时使用，配置写 UUID。
- 不要覆盖原 SSH host key，否则客户端会出现主机身份变更警告。
- 完整闭包复制时间很长，大量 `copying path` 输出不代表卡死。
- 不要同时启动多个 `nixos-rebuild` 或 `nix copy`。
- 首次完整启动可能比 bootstrap 慢，先等待，再检查 `22` 和 `2222` 端口。
- 新系统正常启动前保留 bootstrap generation，便于从 GRUB 回退。

