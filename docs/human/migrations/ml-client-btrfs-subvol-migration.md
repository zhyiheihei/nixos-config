# 物理 client btrfs 子卷对齐迁移（ml-2700 / ml-laptop）

## 背景

作者 lt-hp-omen 的物理 client 磁盘结构（`hardware-configuration.nix`）把
`/nix/persistent` 和 `/nix/persistent/home` 都做成独立 btrfs 子卷
（`subvol=nix` / `subvol=persistent` / `subvol=home`）。`lantian.backup` 的
`nix-persistent` / `home` 两条路径用 `btrfs subvolume snapshot -r` 做快照，
源必须是子卷，否则备份服务配置能构建但运行必失败（`Not a Btrfs subvolume`）。

ml-2700 / ml-laptop 目前 `/nix` 挂的是 btrfs **顶层子卷**（`subvol=/`，
subvolid=5），`/nix/persistent` 只是顶层里的普通目录，不是独立子卷。因此需要
停机做 btrfs 迁移，把磁盘布局对齐作者。

## 目标布局（对齐作者 lt-hp-omen）

| 挂载点 | 子卷 | 说明 |
|---|---|---|
| `/nix` | `subvol=nix` | 系统与 nix store |
| `/nix/persistent` | `subvol=persistent` | 持久化数据根 |
| `/nix/persistent/home` | `subvol=home` | 用户 home 持久化 |

## 迁移前提

- 两机均为 btrfs 顶层 `/` + 独立 `/nix`（`neededForBoot = true`），`/` 是 tmpfs
- `/nix/persistent` 被大量 preservation bind mount 占用（home、media、var、
  etc…），**无法在运行系统中卸载**，必须从 initrd/救援环境操作
- 停机期间机器不可用；syncthing 需暂停（四机汇聚，media 在 client 侧仅占
  2.4M，真正数据在 opi5p/greencloud，数据无风险）
- ml-2700 数据约 40G（var 37G + home 3.2G），ml-laptop 约 53G（home 53G + var 123M）

## 迁移步骤（每机）

> 全程在目标机本地控制台/救援环境执行，不能通过 SSH 远程完成卸载。

### 1. 进入救援环境

用 NixOS 安装 U 盘或 live CD 启动，挂载 btrfs 顶层：

```bash
# 找到 btrfs 分区（ml-2700: /dev/sdb2, ml-laptop: /dev/nvme0n1p2）
mount /dev/<btrfs-dev> /mnt/root
```

### 2. 创建独立子卷

```bash
cd /mnt/root
# 先把现有 persistent 改名为暂存，保留数据
mv persistent persistent.old
btrfs subvolume create persistent
btrfs subvolume create persistent/home

# 数据迁移（reflink 复制，不占额外空间）
cp -a --reflink=always persistent.old/. persistent/
cp -a --reflink=always persistent.old/home/. persistent/home/
```

### 3. 修改 hardware-configuration.nix

照抄作者子卷结构，把 `/nix/persistent` 和 `/nix/persistent/home` 声明为独立
子卷挂载：

```nix
fileSystems."/nix/persistent" = {
  device = "<btrfs-dev>";
  fsType = "btrfs";
  options = [ "subvol=persistent" "compress-force=zstd" "autodefrag" "nosuid" "nodev" ];
  neededForBoot = true;
};
fileSystems."/nix/persistent/home" = {
  device = "<btrfs-dev>";
  fsType = "btrfs";
  options = [ "subvol=home" "compress-force=zstd" "autodefrag" "nosuid" "nodev" ];
};
```

`/nix` 的 `subvol=/` 顶层保持即可（或改 `subvol=nix` 但需先建 nix 子卷，非本
任务目标）。

### 4. 重建启动环境并重启

```bash
nixos-install --no-root-passwd  # 或重建 bootloader
reboot
```

### 5. 验证

```bash
findmnt /nix/persistent          # 应显示 subvol=persistent
btrfs subvolume show /nix/persistent
# 备份服务实际跑一次
systemctl start backup-home
systemctl status backup-home     # 不应再报 Not a Btrfs subvolume
```

### 6. 清理暂存子卷

```bash
btrfs subvolume delete /mnt/root/persistent.old
```

## 风险与回滚

- 迁移全程 reflink 复制不占额外空间，但删除 `persistent.old` 前确认新子卷
  挂载正常、数据完整
- 保留 `persistent.old` 到验证通过再删，作为天然回滚点
- 若 bootloader 重建失败，用 live 环境重新 `mount` + `nixos-enter` 修复

## 对齐规范

- 新装物理 client 应直接按此子卷结构创建，不做迁移
- 该规范已写入 `docs/agent/work-norms.md` 第 2 条和
  `docs/agent/new-host-standard.md` 物理 client 节
