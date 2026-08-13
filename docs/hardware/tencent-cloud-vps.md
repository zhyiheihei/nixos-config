# 腾讯云 CVM（`tencent`）NixOS 接入

本文记录腾讯云首尔 CVM（主机名 `tencent`，index 128）的接入与重装过程。安装
入口与完整步骤以 [`../operations/nixos-reinstallation-guide.md`](../operations/nixos-reinstallation-guide.md)
（路线二：原系统非 NixOS、无法挂 ISO，走 Alpine RAM 救援环境）为准；本文只记录
本机的固定事实与验收状态。

## 固定事实

| 项 | 值 |
| --- | --- |
| 主机名 | `tencent`，`tencent.zhyi.cc` |
| index | 128 |
| 角色 | `server` + `public-facing` + `cn-accel` + `dn42` |
| 地域 | 首尔，KR（Tencent Cloud，AS132203） |
| 公网 IPv4 | `43.155.239.124` |
| dn42 IPv4 | `172.20.46.228`（`172.20.46.224/27`，region Asia-E） |
| dn42 IPv6 | `fdd8:1938:4e88:128::1`（由 index 推导） |
| 规格 | 2 vCPU / 4 GiB（`cpuThreads = 2`，不配 swap） |
| 虚拟化 | KVM（VirtIO，系统盘预期 `/dev/vda`；实机以安装环境 `lsblk` 为准） |

存储架构与仓库其他 server 统一：`/` 为 tmpfs（`impermanence.nix`），`/boot`
独立分区，`/nix` 为持久化 Btrfs（`neededForBoot = true`），持久数据（SSH host
key、SOPS 身份）在 `/nix/persistent`。详细布局见
`hosts/tencent/hardware-configuration.nix`。

## 预装占位状态

`hosts/tencent/host.nix` 当前按 h28k 先例处于预部署状态：

- `ssh.ed25519 = null`、`zerotier = null`：首启生成 host key 后回填；
- `manualDeploy = true`：不进 `@default` 批量部署集，验收完成后移除。

## 重装过程记录

按重装指南路线二执行（本机为无法挂载 ISO 的 VPS）：

1. 原系统下载并运行 [bin456789/reinstall](https://github.com/bin456789/reinstall)
   的 `reinstall.sh alpine --hold 1`，进入 Alpine RAM 救援环境（只进内存，不自动
   重装；不支持 OpenVZ/LXC）。
2. 只读预检：固件（`test -d /sys/firmware/efi`）、磁盘型号/容量、网络。
3. 分区：UEFI 两分区（512 MiB FAT32 `/boot` + 剩余 Btrfs `/nix`）或 BIOS 三分区
   （2 MiB `bios_grub` + ext4 `/boot` + Btrfs `/nix`），以预检固件为准。
4. tmpfs 挂 `/mnt`（`size=80%`）+ `/boot` + `/nix`（`compress-force=zstd,
   autodefrag,nosuid,nodev`）。
5. 生成正式 host key：`/mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key`。
6. 暂停安装：公钥写入 `host.nix`；`ssh-to-age` 加 SOPS recipient 并 rekey
   secrets；push secrets 后主仓库 `nix flake update secrets`。
7. ml-builder 构建 closure 并 `nix copy` 到 Alpine RAM（`/nix` 已 bind 到目标
   Btrfs），官方 `nixos-install-tools` 的 `nixos-install --root /mnt --system
   $CLOSURE --no-root-passwd --no-channel-copy` 安装。
8. 重启前四层验收（文件系统/早期挂载、目标 store 完整性、system profile、
   bootloader 同一 closure）→ 重启。

## 首启验收清单

- [ ] `hostname` 为 `tencent`；`findmnt / /boot /nix` 符合仓库结构。
- [ ] `/nix` Btrfs、`neededForBoot` 求值为 `true`；`/` 为 tmpfs。
- [ ] `sops-install-secrets`、`sshd`（2222）active；`systemctl --failed` 全解释。
- [ ] SSH host key 指纹与 `host.nix` 一致；`known_hosts` 更新。
- [ ] `zerotier-cli info` 取 node ID 写入 `host.nix`，控制器（colocrossing）放行。
- [ ] `wg show` 有近期 handshake、`birdc show protocols` 为 `Established`。
- [ ] `manualDeploy` 移除，`colmena apply --on tencent` 正常。

DN42 的 BGP 对等（`services.dn42` peer 或 peerfinder secret）在 LTNET 建立后
按需配置；`tencent.zhyi.dn42` 记录由 `dns/common/host-recs.nix` 的 `hostRecs.DN42`
自动生成，无需手改。
