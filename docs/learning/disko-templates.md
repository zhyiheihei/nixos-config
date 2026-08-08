# disko-templates 学习笔记

## 1. 是什么

`disko-templates` 是 lassulus 维护的“disko 最佳实践模板”集合：
只有三个 `nix flake init` 模板，没有 packages。54 star，MIT。

```bash
cd /etc/nixos/
nix flake init --template github:nix-community/disko-templates#single-disk-ext4
```

初始化后把 `disko-config.nix` import 进 `configuration.nix`，再按
注释覆盖磁盘设备路径即可。

## 2. 模板清单

flake 的 `outputs.templates` 提供三个：

### single-disk-ext4（单盘 ext4）

- GPT 分区：1M `EF02` BIOS boot 分区（给 grub MBR）、1G `EF00`
  ESP（vfat，挂 `/boot`，`umask=0077`）、剩余全部 ext4 挂 `/`；
- 最简安装模板，适合普通 x86_64 单盘。

### single-ext4-luks-and-double-zfs-mirror

- root 盘：ESP + LUKS（`crypted`，`allowDiscards`）加密 ext4 `/`，
  密码只交互提示；
- data1/data2 两块盘：各一个 `zfs` 分区进 `data` zpool，
  `mode = "mirror"`；
- zpool 开 `compression = "zstd"` 和
  `com.sun:auto-snapshot = "true"`，`postCreateHook` 建 `data@blank`
  快照；
- 数据集 `data/encrypted`：`aes-256-gcm` + passphrase 加密，创建时
  用临时 keyfile，再 `postCreateHook` 改成启动时 prompt 读 key。

### zfs-impermanence

- 单盘：ESP + `zroot` zpool，rootFsOptions 按 Arch ZFS 最佳实践：
  `posixacl`、`atime=off`、`compression=zstd`、`mountpoint=none`、
  `xattr=sa`，`ashift=12`；
- 数据集：`local/home`（/home，开 auto-snapshot）、`local/nix`
  （/nix）、`local/persist`（/persist）、`local/root`（/，建
  `blank` 快照，启动时 rollback）；
- 就是 Grahamc “Erase Your Darlings” 的 ZFS 版实现，配合
  `nixos/modules` 里的 impermanence 使用。

## 3. 对我们仓库的启发

- 我们的物理 client 走 tmpfs `/` + `/nix/persistent`（impermanence），
  zfs-impermanence 模板是同一思路的 ZFS 版本，新主机若用 ZFS 可直接
  参考数据集划分和 `blank` 快照；
- LUKS + ZFS mirror 模板演示了 disko 组合盘/加密/池的声明式写法，
  比手写 fdisk 更可复现；
- `nix flake init --template` 是发布“配置骨架”的标准姿势，
  zhyi-packages 或我们仓库以后做脚手架时也可以只导出 `templates`。

## 4. 参考

- [disko-templates](https://github.com/nix-community/disko-templates)
- [disko](https://github.com/nix-community/disko)
- [Erase Your Darlings](https://grahamc.com/blog/erase-your-darlings/)
