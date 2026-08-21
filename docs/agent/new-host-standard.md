# 新主机接入规范

本文用于把新设备接入本仓库。目标是一次准备完整，避免安装后反复补
SOPS、WireGuard、ZeroTier、引导和同步服务。

## 1. 基本原则

- 本地 `nixos-config` 是配置基准；远端机器只拉取已提交配置或使用临时构建副本。
- 构建和求值优先在 `ml-builder` 完成，不在低性能设备或个人电脑上构建。
- 先核对磁盘、网卡和 SSH host key，再执行任何格式化或安装命令。
- secrets 必须先加密并验证，禁止把私钥或解密后的 YAML 提交到 Git。
- 物理 client、server VM 和 PVE host 的磁盘布局不同，不得互相套用。
- 每完成一层就验证一层，不用一次 `make all` 同时排查安装、网络和应用问题。

## 2. 创建主机配置

在 `hosts/<hostname>/` 至少准备：

- `host.nix`：唯一 `index`、标签、CPU 线程、真实城市、主机名和 SSH host 公钥。
- `configuration.nix`：配置类型、目标应用和实际网卡配置。
- `hardware-configuration.nix`：真实磁盘 UUID、平台、引导设备和硬件模块。

接入前确认以下值不与现有主机冲突：

- `index`
- 内网静态 IPv4
- DN42 IPv4 和 region
- ZeroTier node ID
- WireGuard 公钥映射名

家中静态地址统一写入 `interconnect`。显式使用 `ltnet.peers` 时，WireGuard
peer 必须在两端配置成对，否则一端会持续发送数据但永远没有握手。

## 3. 磁盘和引导

### Server VM

当前 QEMU server VM 使用作者体系的 tmpfs `/`，持久数据放在 `/nix`：

- 2 MiB BIOS boot 分区，GPT 类型为 `bios_grub`
- ext4 `/boot`
- 可选磁盘 swap
- Btrfs `/nix`，使用 `compress-force=zstd`、`autodefrag`、`nosuid`、`nodev`
- 独立 `/nix` 必须声明 `neededForBoot = true`

加密 swap 的 `device` 必须使用 `/dev/disk/by-partuuid/...`。不要把文件系统 UUID
误写成 PARTUUID。

BIOS GRUB 安装完成后必须检查：

```bash
test -f /boot/grub/i386-pc/normal.mod
test -f /boot/grub/i386-pc/btrfs.mod
```

如果使用独立 ext4 `/boot` 加 Btrfs `/nix`，缺少这些模块会停在
`grub rescue>`。修复时只从当前系统闭包对应的
`grub-*/lib/grub/i386-pc` 补到 `/boot/grub/`，不得重新分区。

### 物理 client

物理 client 继续遵循 `AGENTS.md`：EFI `/boot`、Btrfs `/nix`、tmpfs `/`，并在
安装环境中提前准备 `/mnt/nix/persistent/etc/ssh`。不要在线把普通 ext4 根系统
直接切换到该布局。这里的独立 `/nix` 同样必须设置 `neededForBoot = true`，确保
initrd 挂载它以后再寻找 system closure。

**子卷布局必须与作者物理 client 对齐**（基准：
`../nixos-config-exam/hosts/lt-hp-omen/hardware-configuration.nix`）。作者把
`/nix/persistent` 和 `/nix/persistent/home` 都做成独立 btrfs 子卷（`subvol=nix`、
`subvol=persistent`、`subvol=home`），这不是可选项：`lantian.backup` 的
`nix-persistent`/`home` 快照用 `btrfs subvolume snapshot -r`，源必须是子卷，否则
备份服务配置通过但运行必报 `Not a Btrfs subvolume`。新装机应直接从安装环境按该
子卷结构创建；存量机器若 `/nix/persistent` 只是顶层子卷里的普通目录，需要做
停机 btrfs 迁移，不能只在配置文件里逐字对齐。

## 4. SSH host key 和 SOPS

作者原版使用两类密钥，禁止混用：

1. **个人登录密钥**：公钥来自 secrets 的 `ssh/zhyi.nix`，用于 root 和
   `zhyi` 的 `authorizedKeys`；私钥由设备所有者在 Bitwarden 中统一管理。
2. **每主机 host key**：私钥保存在
   `/nix/persistent/etc/ssh/ssh_host_ed25519_key`，既用于 SSH 服务器身份，也由
   `sops.age.sshKeyPaths` 用作该主机的 SOPS age 解密身份；公钥写入
   `hosts/<hostname>/host.nix`，供 `knownHosts` 固定服务器身份。

因此，host key 是“服务器身份 + SOPS 解密”一把两用，但绝不能再拿它充当个人
登录私钥。安装过程中如需临时登录密钥，只能临时授权，正式系统切换后必须删除。

安装前生成正式 SSH host key，并直接存入持久目录：

```bash
install -d -m 700 /mnt/nix/persistent/etc/ssh
ssh-keygen -t ed25519 -N '' \
  -f /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key
```

随后完成全部步骤：

1. 将 `.pub` 内容写入 `hosts/<hostname>/host.nix` 的 `ssh.ed25519`。
2. 用 `ssh-to-age` 从公钥计算 age recipient。
3. 按 `nixos-secrets/docs/sops-manual.md` 把 recipient 加入 `.sops.yaml`。
4. 重新加密全部受管 YAML，并验证每个文件都包含新 recipient。
5. 如果主仓库引用该 host 的 hidden module，先在 secrets 中补对应模块。
6. 把 host 私钥和公钥安全交付给设备所有者，核对 SHA256 指纹后保存到
   Bitwarden；不要把该私钥加载进日常 SSH agent。
7. 用同一公钥配置管理端的 `known_hosts`，并验证首次连接显示的指纹一致。

手动解密时先把 SSH host 私钥转换成临时 native age identity。不要直接把 SSH
私钥路径交给 `SOPS_AGE_SSH_PRIVATE_KEY_FILE`。操作结束立即删除临时 identity。

## 5. WireGuard 和 ZeroTier

Server host 还必须完成：

1. 在 `per-host/wg-priv/<hostname>.yaml` 中加密保存 WireGuard 私钥。
2. 从该私钥派生公钥，并加入 secrets 的 `wg-pubkey.nix`。
3. 首次启动后运行 `zerotier-cli info`，把 node ID 写入 `host.nix`。
4. 重新构建并切换 ZeroTier controller 所在的 `greencloud`。
5. 显式 peer 拓扑要检查两端都生成对应 `wgmesh<index>`。

### 5.1 ZeroTier controller 授权是声明式自动完成的

ZeroTier controller 是 greencloud 上**独立实例**
`zerotierone-controller.service`（端口 `9994`，数据目录
`/var/lib/zerotier-one-controller/`，与普通成员实例的 `9993` 不同）。
网络 `466270de75000001` 的授权成员**完全来自声明式配置**，不需要手动
`curl` controller API：

- `helpers/fn/zerotier.nix` 从 `hosts/*/host.nix` 中 `zerotier != null` 的主机
  生成 `LT.zerotier.hosts`（每个成员分配 `198.18.0.<index>` 与
  `fdd8:1938:4e88::<index>`）。
- `nixos/optional-apps/zerotierone-controller.nix` 把 `members = LT.zerotier.hosts`
  交给 `zerotierone-controller-setup.service`，该 oneshot 服务在重构切换
  greencloud 时把每个成员 `authorized=true` 并分配 IP。

因此步骤 4 的「重构并切换 greencloud」会**自动完成授权**。物理 client（tmpfs
根）没有 WireGuard/BIRD，只需验证 ZeroTier：

```bash
zerotier-cli listnetworks   # 状态应为 OK，看到 ZT 分配的 198.18.0.<index>
```

### 5.2 新增证书的注意点

`<host>.zhyi.xin` 证书由 greencloud 上的 acme 服务签发。首次接入多台主机并发
签发时，ecc/rsa 两个 order 服务会竞争同一 `_acme-challenge.<host>.zhyi.xin`
TXT 记录，可能互相覆盖导致其中一个失败（报 `Incorrect TXT record`）。若某台
主机只有 ecc 进 sync-servers 而 rsa 缺失：

```bash
# 在 greencloud 上，等 dnscontrol 重新发布 DNS 后手动重签即可（无需改配置）
systemctl restart acme-order-renew-lets-encrypt-<host>.zhyi.xin-rsa.service
```

## 6. 构建和安装

完整安装命令按入口环境拆分在
[NixOS 完整重装指南](nixos-reinstallation-guide.md)：已经挂载 NixOS ISO 时
直接使用 ISO 安装；原系统不是 NixOS 且无法挂载 ISO 时，先进入 Alpine RAM
救援环境。不要把一键脚本生成的普通磁盘根布局当作本仓库最终布局。

构建源必须排除 `.git` 和 `.DS_Store`。未跟踪的 `.DS_Store` 进入 `path:` flake
会改变 NAR hash，并导致无意义的重新求值。

构建时 substituter 顺序为：

1. 自有 Attic
2. 上海交大 Nix mirror
3. `cache.nixos.org`

TUNA Nix store 曾在提交 `34938493` 中移除，因为所需 store path 返回 404，不能
作为完整二进制缓存恢复。上海交大镜像已经用实际缺失的大型 OpenJDK path 验证。

常规构建：

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel -L
```

低内存安装环境不要把完整闭包复制到 tmpfs。应使用目标 store：

```bash
nix copy --no-check-sigs \
  --to 'ssh-ng://root@<installer-ip>?remote-store=local%3Froot%3D%2Fmnt' \
  <system-closure>
nixos-install --root /mnt --system <system-closure> \
  --no-root-passwd --no-channel-copy
```

`nix copy` 成功不等于系统可启动。重启前必须按完整重装指南逐项证明：目标 store
拥有 closure 的全部递归引用、目标 system profile 指向该 closure、bootloader
引用同一 closure，而且 `/nix` 会在 initrd 阶段挂载。

## 7. PVE VM 设置

QEMU VM 至少启用：

- VirtIO SCSI 磁盘和 VirtIO 网卡
- `agent=enabled=1`
- 硬盘优先启动
- 需要排障时启用 serial socket，并在内核参数加入 `console=ttyS0,115200`

安装结束后先验证硬盘可以独立启动，再卸载 ISO。不要用重新格式化来修复单纯的
GRUB、网络或服务问题。

## 8. 首次启动验收

逐项检查：

```bash
hostname
findmnt / /nix /boot
swapon --show
systemctl --failed --no-pager
systemctl is-active sops-install-secrets qemu-guest-agent sshd
```

Server 还要手动触发一次共享数据同步：

```bash
systemctl start rsync-nix-sync-servers.service
```

确认 `/nix/sync-servers` 已包含 ACME 证书和 LTNET 脚本，再重启依赖它们的 Nginx
和 PowerDNS。新增证书第一次签发可能因 DNS TXT 传播失败；等待清理后重试 ACME，
不要用永久自签名证书绕过。

应用验收必须同时检查本地监听和实际反代入口。受认证保护的入口返回 `401` 表示
已命中服务，不等于反代故障。

## 9. 提交顺序

1. 先提交并推送 `nixos-secrets`。
2. 在主仓库更新 secrets flake input。
3. 提交主机配置、必要的对端 peer 和 `flake.lock`。
4. 在 `ml-builder` 重新构建。
5. 最后再使用 Colmena 或 Makefile 中对应的标签目标批量部署。

任何一步失败时，保留上一代 system profile 和 PVE 磁盘，不删除可启动代；先用
控制台、`systemctl status`、`journalctl` 和网络三层状态定位具体故障。
