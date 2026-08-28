# GreenCloud 东京存储 VPS（greencloud-jp）

本机的固定事实与装机记录。装机流程遵循
[新主机接入规范](../../agent/new-host-standard.md) 与
[NixOS 完整重装指南](../../agent/nixos-reinstallation-guide.md)。

## 固定事实

| 项目 | 值 |
| --- | --- |
| 供应商/位置 | GreenCloud APAC，东京（xTom 机房，IIJ 线路） |
| 套餐 | StorageAPAC-1：$45/年，2C / 3G / 1T 数据盘 / 2T 月流量 / 10Gbps |
| 网络 | v4 `45.159.48.76/24`（网关 `45.159.48.1`）；v6 `2403:71c0:2000:1253::a/64`（网关 `2403:71c0:2000::1`，onlink） |
| DNS | `greencloud-jp.zhyi.xin`（由 `dns/common/host-recs.nix` 自动生成） |
| 磁盘 | `vda` 40G 系统盘（BIOS 三分区：bios_grub / ext4 `/boot` / btrfs `/nix`）；`vdb` 1T 数据盘（btrfs `/data`） |
| host.nix | index 130，`ssh.ed25519` 指纹 `SHA256:GJ8IBWu9Q3aPIOaYm8uc62XlJQaPagPjQ+4dyxaZGgk`，`zerotier` = `f4ec4a081c` |
| 角色 | 异地备份目标：SFTP（chroot `/data/sftp-server`，restic root `/backups/restic`）；S3 网关待部署 |

## 装机记录（2026-08-29）

1. GreenCloud 原装系统，用 bin456789/reinstall 装了一个**磁盘版** Alpine；
   按指南要求又以 `reinstall.sh alpine --hold 1` 重启进 RAM 救援环境。
2. 只读预检确认：BIOS 引导、vda 40G / vdb 1T（断言容量后才动手）、
   v6 静态地址与 onlink 网关在救援环境实测采集。
3. vda 三分区 + vdb btrfs（UUID 均已写入 hardware-configuration.nix）；
   正式 host key 生成于 `/mnt/nix/persistent/etc/ssh`。
4. secrets 侧：`ssh-to-age` 派生 age recipient 加入 `.sops.yaml`；
   `per-host/wg-priv/greencloud-jp.yaml`；`wg-pubkey.nix` 回填；
   **全部 75 个受管 YAML 执行 `sops updatekeys`**（否则新主机解密失败）。
5. ml-builder 构建闭包并 `nix copy` 至目标机，`nixos-install` 后
   `switch-to-configuration boot` 完成 GRUB，REBOOT_GATE=PASS 后重启。

## 踩坑

- **rust 版 nixos-install 的 bootloader 步骤失败**：
  1) Alpine 救援环境需先 `mount --bind /dev /proc /sys /run` 进 `/mnt`；
  2) `/boot/kernels` 目录缺失需手动创建（与 tencent 2026-08-13 记录同款）；
  3) 仍失败时改用 `nix-env -p .../system --set $CLOSURE` +
     `chroot /mnt $CLOSURE/bin/switch-to-configuration boot` 走标准激活路径。
- **该机房 DHCPv4 拿不到租约**：首启后 v4 不通、仅 v6 可达；
  已改为 v4/v6 双静态（`configuration.nix`），网关取救援环境实测值。
- **sops updatekeys 忘记做会连锁失败**：sops-install-secrets 起不来 →
  依赖 secrets 的 wg/dn42/nginx/filebeat 连环挂；updatekeys 需交互确认，
  非交互用 `yes | sops updatekeys $f`。
- **rsync-nix-sync-servers 首跑 chgrp EPERM**：serviceHarden 清空了
  capability bounding set，dn42 registry 部分文件属组为 gid 60，chgrp 被拒。
  首次以裸 rsync 手动同步一次（组对齐后沙箱内增量不再改组）即恢复。

## 首启验收（2026-08-29）

- [x] SSH 2222（v4/v6 双栈可达）；host key 指纹与 host.nix 一致。
- [x] `/` tmpfs、`/boot` ext4、`/nix` btrfs（zstd）、`/data` btrfs 1T。
- [x] `sops-install-secrets`、ZeroTier（`f4ec4a081c`，LTNET `198.18.0.130`）、
      wg-mesh 全 peer、bird、pdns-recursor、nginx 全部 active；
      `systemctl --failed` 为空。
- [x] rsync-nix-sync-servers 成功，`/nix/sync-servers` 内容齐备。
- [x] greencloud 控制器声明式授权该成员；`greencloud-jp.zhyi.xin` A/AAAA
      已由 dnscontrol 发布，greencloud 上 ACME 证书签发中。

## 待办

- [ ] SFTP 登录端到端验证（需要 Bitwarden 中的 sftp 客户端私钥）。
- [ ] S3 网关选型与部署（Garage / MinIO，数据盘 `/data`）。
- [ ] 决策是否把各服务器 `lantian.backup.sftpEndpoint` 从 `opi5p.zhyi.xin`
      切换到 `greencloud-jp.zhyi.xin`。
