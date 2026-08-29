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

## VaultS3 S3 网关（s3.zhyi.xin，2026-08-29）

- host-local 配置（对齐 router 上的既有实例）：数据 `/data/vaults3-data`
  （1T 盘），元数据 `/nix/persistent/var/lib/vaults3`，仅监听 loopback:9000，
  由 nginx 反代 `s3.zhyi.xin`（泛域名证书 + `client_max_body_size 0`）。
- SigV4 兼容：LT nginx 默认透传 `$host`，签名校验不受反代影响。
- 凭据沿用机群约定：access key `zhyi` / secret key 来自共享 `default-pw`
  （sops template `vaults3-credentials`）。
- DNS：`s3.zhyi.xin` CNAME → `greencloud-jp.zhyi.xin`，由 dnscontrol CI 发布。
- 验证（2026-08-29）：匿名请求按 S3 语义拒绝；SigV4 建桶/上传/列举/下载/
  删桶 roundtrip 全通过。

## cn-accel 出口节点（2026-08-29）

- host.nix 加 `cn-accel` 标签（启用 server-apps/v2ray.nix 的 xray），configuration.nix
  将默认 vhost 证书升级为 `lets-encrypt-zhyi.xin`（泛域名，SAN `*.zhyi.xin`）；
  域名需加入 `helpers/constants/public-sites.nix` 的有意公开白名单，否则求值断言失败。
- 订阅侧（greencloud 的 SublinkPro，面板 `sub.zhyi.xin`）：
  seed 脚本已加入节点循环；但 `subcription/update` API 存在「与自己重名」的
  校验 bug，存量订阅无法通过 API 追加节点，需直接改
  `/var/lib/sublinkpro/db/sublink.db` 的 `subcription_nodes` 关联表
  （本次已把节点 ID 91/92/93/94/248 挂到订阅 1）。
- 客户端实际使用的分享链接是「默认分享链接」（token 与
  SUBLINK_SHARE_TOKEN 派生值无关），验证时用 shares/get 查真实 token。
- greencloud 上 per-host 的 `zerossl-greencloud-jp.zhyi.xin-rsa` 证书订单
  因 ZeroSSL API 抖动失败中；nginx 的双证书布局要求四个文件齐全，已用
  lets-encrypt-greencloud-jp 同域名证书填充 zerossl-rsa 位（真实受信证书，
  非 self-signed），ZeroSSL 恢复后定时器会自动覆盖为原生 ZeroSSL 证书。

## Gitea 迁移（2026-08-29）

- 自 greencloud 迁入：MySQL 全量 dump（150K）+ `/var/lib/gitea`（686K，
  经 ml-builder 中转），恢复后 chown git:gitea。
- LFS/附件存储：原 router 家内 vaults3 已停摆（服务 inactive、数据盘缺失），
  改指向本机 `s3.zhyi.xin:443`（`MINIO_ENDPOINT` mkForce 覆盖模块默认）。
- 存储凭据：VaultS3 的 IAM 为「用户 + 服务端生成的 access key（可绑定桶）」，
  已建 `gitea` IAM 用户及其密钥（`POST /api/v1/keys`），写入 secrets
  `gitea.yaml`（注：`subcription/update` 类自比名校验 bug 的教训——先读实现
  再下结论，VaultS3 并非只认统一账户，initial 判断有误已纠正）。
- DNS：`git.zhyi.xin` CNAME 切至 `greencloud-jp`（dnscontrol CI 发布）。
- 未迁移：Gitea Actions runner（历史 0 次运行，未启用；需要时可在任意机器
  启用 gitea-actions 模块指向 git.zhyi.xin）。greencloud 旧数据
  （/var/lib/gitea、/var/lib/mysql）保留作回滚备份。
- 验证：Web explore 303/证书受信、SSH clone（git@git.zhyi.xin:zhyi/notes.git）
  返回 HEAD；私有仓库 HTTPS 提示凭据为预期行为。

## 待办

- [x] SFTP 登录端到端验证（2026-08-29，google 用 sops 解密的 sftp-privkey
      登录 `sftp@greencloud-jp.zhyi.xin:2222`：chroot 生效、`/backups` 可写、
      上传/读回/删除 roundtrip 通过）。
- [ ] S3 网关选型与部署（Garage / MinIO，数据盘 `/data`）。
- [ ] 决策是否把各服务器 `lantian.backup.sftpEndpoint` 从 `opi5p.zhyi.xin`
      切换到 `greencloud-jp.zhyi.xin`。
