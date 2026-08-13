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

2026-08-13 实机验收后已全部回填：`ssh.ed25519` =
`SHA256:mQsADD14m6vckwHEmIan3gOcixlPtRos7eaNQQNiCEo`，`zerotier` = `7edc5323e0`，
`manualDeploy` 已移除。

## 重装过程记录（2026-08-13 实机执行）

按重装指南路线二执行（本机为无法挂载 ISO 的 VPS）：

1. 原系统（Debian 13，cloud-init DHCP）下载并运行
   [bin456789/reinstall](https://github.com/bin456789/reinstall) 的
   `reinstall.sh alpine --hold 1 --ssh-key ... --ssh-port 22`，进入 Alpine 3.24
   RAM 救援环境。
2. 只读预检：**固件为 BIOS**；磁盘 `/dev/vda` 60G VirtIO（无序列号）；eth0 DHCP
   `10.8.0.15/22`（腾讯云内网，公网 43.155.239.124 为 NAT）；2 vCPU / 3.6 GiB。
3. 分区（BIOS 三分区，GPT）：1 MiB-3 MiB `bios_grub` + 3 MiB-1027 MiB ext4
   `/boot`（UUID `746229e1-c137-4110-ae9e-40049529b4b0`）+ 1027 MiB-100% Btrfs
   `/nix`（UUID `3f591231-0d3e-4952-a5bf-f87f4fbce9b3`）。
4. tmpfs 挂 `/mnt`（`size=80%`）+ `/boot` + `/nix`（`compress-force=zstd,
   autodefrag,nosuid,nodev`）。
5. 生成正式 host key：`/mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key`。
6. 暂停安装：公钥写入 `host.nix`；`ssh-to-age` 加 SOPS recipient（
   `age1h44el8ssf57cmfc4j7xj89z0adjkglwd8td8n0juu326n8p7rspqk9rcxt`）并全库
   rekey（65 个 yaml）；push secrets 后主仓库 `nix flake update secrets`。
7. ml-builder 构建 closure（`2lfa0bd9...`）并 `nix copy` 到 Alpine RAM（`/nix`
   已 bind 到目标 Btrfs），官方 `nixos-install-tools` 的 `nixos-install --root
   /mnt --system $CLOSURE --no-root-passwd --no-channel-copy` 安装。
   **踩坑**：首次 bootloader 安装失败（install-ng 写 `/boot/kernels` 目标缺失），
   手动 `mkdir /mnt/boot/kernels` 后重跑成功。
8. 重启前四层验收全部 PASS（REBOOT_GATE=PASS）→ 重启。

## 首启验收结果（2026-08-13）

- `hostname` 为 `tencent`；`/` tmpfs、`/boot` vda2 ext4、`/nix` vda3 Btrfs
  （`compress-force=zstd,nosuid,nodev`）符合仓库结构。
- `/nix` `neededForBoot` 求值为 `true`；`/` 为 tmpfs。
- [ ] `sops-install-secrets`、`sshd`（2222）active；`systemctl --failed` 全解释。
- [x] SSH host key 指纹与 `host.nix` 一致；管理端 `known_hosts` 更新。
- [x] `zerotier-cli info` 取 node ID（`7edc5323e0`）写入 `host.nix`，控制器
      （greencloud）放行，`listnetworks` 为 OK，分配到
      `198.18.0.128/24` / `fdd8:1938:4e88::128/64`。
- [x] `wg show` 7 个 peer handshake（greencloud/cnvm/google/ml-builder/rock5c/
      lubancat1/opi5p），babel 路由收敛，`birdc show protocols` ltdocker up。
      **hostdare 例外**：部署时 hostdare（36.50.85.113）从 mac/ml-builder 均不可达
      （既有问题），wgmesh128 待其恢复后部署。
- [x] `manualDeploy` 移除，colmena 部署 tencent/cnvm/google/ml-builder/rock5c/
      lubancat1/opi5p 成功（新 netdev 需手动 `systemctl restart systemd-networkd`
      生效）。
- [x] rsync-nix-sync-servers 同步 ACME 证书（lets-encrypt + zerossl）与
      ltnet-scripts 成功；nginx active，`systemctl --failed` 为空。

DN42 的 BGP 对等（`services.dn42` peer 或 peerfinder secret）在 LTNET 建立后
按需配置（当前全 fleet 均未启用，与本机无关）；`tencent.zhyi.dn42` 记录由
`dns/common/host-recs.nix` 的 `hostRecs.DN42` 自动生成，无需手改。
