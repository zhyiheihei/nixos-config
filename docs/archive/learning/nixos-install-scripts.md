# nixos-install-scripts 学习笔记

## 1. 是什么

`nixos-install-scripts` 是一组一次性 bash 脚本，用于在各类服务器厂商
和硬件上快速安装 NixOS：一条命令、等几分钟就能装好。159 star，无
flake/CI，纯 shell 脚本 + 注释文档。

## 2. 覆盖的厂商与磁盘方案

- Hetzner Cloud（amd64 ISO）：单盘 GPT，删除并重建分区扩容，ext4，
  GRUB；
- Hetzner Cloud（Ampere/ARM ISO）：GPT + EFI system partition +
  ext4 根分区，systemd-boot，SSH key 从环境变量传入；
- Hetzner Dedicated（BIOS）：双盘 GPT，1MB BIOS boot + RAID1 + LVM +
  ext4，GRUB legacy；
- Hetzner Dedicated（ZFS）：NVMe by-id 镜像 ZFS + UEFI，需要先向
  Hetzner 申请开启 UEFI；
- Leaseweb Dedicated：双 HDD RAID1 + LVM + ext4；
- OVH Dedicated：UEFI + RAID1 + LUKS + LVM + ext4，需要预置 LUKS
  keyfile。

## 3. 通用模式

```bash
ssh root@YOUR_SERVERS_IP bash -s < hosters/<hoster>/script.sh
```

脚本内固定套路：

- 先 `lsblk` 检查磁盘，停止 mdadm 数组并写
  `mdadm.conf` 的 `<ignore>` 防止自动重组旧 RAID；
- 分区（GPT BIOS boot / ESP）、RAID / ZFS / LUKS / LVM、mkfs、
  `udevadm trigger`；
- 在 rescue 系统装 Nix，`nix-channel --add` 指定 NixOS 版本，
  `nix-env -iE` 拿 `nixos-generate-config` / `nixos-install` /
  `nixos-enter`；
- `nixos-generate-config --root /mnt` 后向 `configuration.nix` 追加
  GRUB/systemd-boot、SSH pubkey、root 空密码和 sshd 配置；
- `nixos-install --no-root-passwd`，然后 `poweroff`。

## 4. 细节质量

- 每个脚本顶部有详尽的解释（BIOS/UEFI 限制、mdadm HOMEHOST、
  parted GPT 分区名、NVMe 不能 legacy 启动等）；
- Hetzner Cloud README 还给了 Floating IP 静态网络配置和 DNS
  故障排查（DHCP 租约续期丢路由、glibc MAXNS=3）；
- 默认在脚本里留 FIXME（SSH key、磁盘 by-id、hostname），必须改
  后才能用。

## 5. 对我们仓库的启发

- 我们日常部署用 colmena + ml-builder，不常做裸机安装；
- 如果以后迁移到 Hetzner/OVH 等厂商，这些脚本是现成模板，尤其
  “RAID/LVM/ZFS/LUKS 分层 + 详细注释”的磁盘方案值得照抄；
- 我们文档里已有类似的物理机重装约束（tmpfs root、持久化 /nix、
  SSH host keys），这些脚本的思路一致。

## 6. 参考

- [nixos-install-scripts](https://github.com/nix-community/nixos-install-scripts)
- [NixOS manual: installing from other distro](https://nixos.org/manual/nixos/stable/index.html#sec-installing-from-other-distro)
