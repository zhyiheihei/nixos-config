# ml-builder 当前运行日志

本文记录 2026-07-04 对测试机 `ml-builder`（`192.168.3.176`）做原作者配置复刻测试时的实际操作、结果和结论。

目标不是长期方案，而是把这次已经发生的状态写清楚，避免后续继续凭记忆排错。

## 1. 目标

最终目标：

- 尽量原汁原味复刻作者的 NixOS 配置。
- 先从测试机 `hosts/ml-builder` 跑通。
- 使用 `nixos/minimal.nix`，验证最小系统、secrets、impermanence、SSH、bootloader。
- 测试机怎么改都可以，但主项目公共模块尽量保持作者原样。

本轮临时目标：

- 在 `192.168.3.176` 上构建 `.#nixosConfigurations.ml-builder.config.system.build.toplevel`。
- 尝试 `nixos-rebuild switch --flake .#ml-builder`。

## 2. 初始远程状态

SSH 探测：

```bash
ssh -A -p 2222 lantian@192.168.3.176
```

结果：

```text
Connection refused
```

说明作者配置里的 hardened SSH 端口 `2222` 当时没有启用。

继续测试 22 端口：

```bash
ssh -A -p 22 root@192.168.3.176
ssh -A -p 22 zhyi@192.168.3.176
```

结果：

- `root` 可以登录。
- `zhyi` 可以登录。
- `lantian` 不能登录。

远端系统信息：

```text
hostname: nixos
current system: /nix/store/rqz7klxgm2x7yv6scbyjw0r22qifcsyl-nixos-system-nixos-26.05.3705.1f01958ffb5b
boot mode: not booted with EFI
```

真实磁盘布局：

```text
sda
└─sda1 ext4 LABEL=root UUID=688546eb-5ea8-406f-b7d9-ec9140fb0ed1 mounted on /
```

关键结论：

- 机器不是作者式布局。
- 机器只有一个 ext4 根分区。
- 没有独立 `/boot` 分区。
- 没有 `/dev/sda2`。
- 没有 `/nix/persistent`。

## 3. secrets 修复

第一次构建时，`secrets` 已经切到个人私有仓库：

```nix
secrets.url = "git+ssh://git@github.com/zhyiheihei/nixos-secrets.git";
```

构建失败断言：

```text
Neither the root account nor any wheel user has a password or SSH authorized key.
You must set one to prevent being locked out of your system.
```

原因：

- 主项目 `nixos/minimal-components/users.nix` 按作者原样引用 `ssh/lantian.nix`。
- 当时私有 secrets 仓库中：
  - `ssh/zhyi.nix` 有公钥。
  - `ssh/nix-builder.nix` 有公钥。
  - `ssh/lantian.nix` 是空列表。

已做修复：

- 在 secrets 仓库提交：

```text
a6cf395 Restore upstream lantian login user
```

- 推送到：

```text
git@github.com:zhyiheihei/nixos-secrets.git
```

- 主仓库 `flake.lock` 已更新到：

```text
secrets rev: a6cf3952faf4a9329854738f2d38da22fbba644c
```

修复后验证：

```text
users.users.lantian.openssh.authorizedKeys.keys
=> ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAXn2roZsbvURS+faytLLz2OE1gemC19RMNsPj3Ypnha 2386656187@qq.com"]
```

## 4. 作者内核构建失败

作者默认 x86_64 kernel 来自：

```nix
pkgs.nur-xddxdd.lantianLinuxCachyOS.lts-lto
```

实际选中：

```text
linux-cachyos-lts-lto-6.18.36
```

在测试机本地构建时失败：

```text
LD [M] drivers/gpu/drm/amd/amdgpu/amdgpu.o
double free or corruption (!prev)
PLEASE submit a bug report to https://github.com/llvm/llvm-project/issues/
...
ld.lld ... -o drivers/gpu/drm/amd/amdgpu/amdgpu.o
make[6]: *** [../scripts/Makefile.build:503: drivers/gpu/drm/amd/amdgpu/amdgpu.o] Error 142
```

判断：

- 这不是 NixOS 配置断言。
- 这是 CachyOS LTO kernel 本地编译阶段 `ld.lld` 崩溃。
- 如果坚持原汁原味使用作者内核，应该让它从可用 binary cache 下载，或者找另一台能成功构建该内核的 builder。

本轮为了继续验证系统其它部分，临时给 `ml-builder` 加过 host 级覆盖：

```nix
lantian.kernel = pkgs.linux;
```

这不是原汁原味，只是绕过本地 LTO kernel 构建问题。

## 5. 标准内核构建成功

使用临时覆盖后，选中：

```text
linux-6.18.37
```

构建成功：

```text
/nix/store/y9h9rrc3mhvpnp2j7i5vghxfva4af0sv-nixos-system-ml-builder-26.11pre-git
```

说明：

- secrets 问题已解决。
- `ml-builder` host 能被 flake 正确发现。
- `minimal.nix` 基本能进入完整系统构建。
- 失败点不在用户、home-manager、sops、systemd unit 生成这些早期环节。

## 6. 磁盘布局临时修正

原先 `hosts/ml-builder/hardware-configuration.nix` 按目标布局写成：

```nix
fileSystems."/boot" = {
  device = "/dev/sda1";
  fsType = "ext4";
};

fileSystems."/nix" = {
  device = "/dev/sda2";
  fsType = "btrfs";
};
```

但真实机器没有 `/dev/sda2`。

为了避免立即引用不存在分区，曾临时改成单分区：

```nix
fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/688546eb-5ea8-406f-b7d9-ec9140fb0ed1";
  fsType = "ext4";
  neededForBoot = true;
  options = [
    "nosuid"
    "nodev"
  ];
};
```

这也不是作者式布局。

作者式 impermanence 的核心是：

- `/` 是 tmpfs。
- 持久数据在 `/nix/persistent`。
- `sops.age.sshKeyPaths = [ "/nix/persistent/etc/ssh/ssh_host_ed25519_key" ];`
- `services.userborn.passwordFilesLocation = "/nix/persistent/var/lib/nixos";`

因此真正原汁原味应该准备正确持久卷，而不是在旧 ext4 根分区上硬切。

## 7. switch 前准备

在 switch 前，手动创建了：

```bash
install -d -m 0755 /nix/persistent/etc/ssh /nix/persistent/var/lib/nixos
cp -a /etc/ssh/ssh_host_ed25519_key /nix/persistent/etc/ssh/ssh_host_ed25519_key
cp -a /etc/ssh/ssh_host_ed25519_key.pub /nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
chmod 600 /nix/persistent/etc/ssh/ssh_host_ed25519_key
```

目的：

- 让 SOPS 在作者路径下能找到 age SSH key。
- 保留 host key，避免切换后 host key 变化。

## 8. nixos-rebuild switch 结果

执行：

```bash
cd /tmp/nixos-config-ml-builder-test
nixos-rebuild switch --flake .#ml-builder --show-trace
```

发生的事情：

- 系统构建成功。
- GRUB menu 更新成功。
- GRUB 安装到 `/dev/sda` 成功。
- 激活阶段部分失败。

成功输出：

```text
updating GRUB 2 menu...
installing the GRUB 2 boot loader on /dev/sda...
Installing for i386-pc platform.
Installation finished. No error reported.
```

随后失败：

```text
Failed to restart systemd-udevd.service
Failed to start systemd-sysctl.service
Failed to reload -.mount
Failed to restart nix-daemon.service
Failed to start local-fs.target
Failed to restart systemd-journald.service
Failed to restart sysinit-reactivation.target
Failed to restart sshd.service
Failed to start systemd-modules-load.service
```

失败 unit 包括：

```text
enable-ksm.service
home-manager-lantian.service
home-manager-root.service
irqbalance.service
root-.cache-pandemonium.mount
rsync-nix-sync-servers.service
run-nullfs.mount
sops-install-secrets.service
sshd-keygen.service
suid-sgid-wrappers.service
systemd-binfmt.service
systemd-journald.service
systemd-modules-load.service
systemd-networkd-resolve-hook.socket
systemd-networkd-varlink.socket
systemd-networkd.service
systemd-tmpfiles-resetup.service
systemd-udevd.service
systemd-zram-setup@zram0.service
var-cache.mount
var-lib.mount
var-log.mount
var-www.mount
```

`nixos-rebuild` 返回：

```text
exit status 4
```

随后 SSH 状态：

```text
192.168.3.176:22   Connection refused
192.168.3.176:2222 Connection refused
```

当前远程入口已丢失。

## 9. 失败判断

这次失败不是单一 SSH 配置问题。

更可能是：

- 在已有单 ext4 `/` 系统上直接 `switch` 到作者式 tmpfs `/` + preservation，触发 local-fs、bind/symlink、mount unit 和 systemd reactivation 连锁失败。
- 根文件系统、`/nix`、`/nix/persistent` 的关系不符合作者设计。
- `switch` 过程中 systemd 尝试重启 sshd、journald、udevd、nix-daemon 等核心服务，结果多个依赖失败，导致 SSH 同时断开。

这说明：

- 在当前旧系统上“直接切换”不是安全路径。
- 要原汁原味复刻作者配置，应该从磁盘布局开始复刻，而不是在已有单分区 NixOS 上强行切。

## 10. 当前仓库 dirty 状态

当前主仓库仍有修改：

```text
M flake.lock
M hosts/ml-builder/configuration.nix
M hosts/ml-builder/hardware-configuration.nix
```

含义：

- `flake.lock`：锁定到个人 secrets `a6cf395`，这是必须保留的方向。
- `configuration.nix`：包含临时 `lantian.kernel = pkgs.linux;`，不是原汁原味。
- `hardware-configuration.nix`：包含单 ext4 `/nix` 临时布局，不是作者式目标布局。

如果目标改回“百分百复刻作者”，建议：

- 保留 `flake.lock` 的 secrets 更新。
- 删除 `lantian.kernel = pkgs.linux;`，恢复作者默认 CachyOS LTO kernel。
- 把 `hardware-configuration.nix` 改回真正目标磁盘布局，而不是当前单分区临时布局。

## 11. 下一步建议：按作者方式重来

测试机怎么改都行，所以推荐直接重装/重分区，而不是救当前半切状态。

目标布局建议：

```text
/dev/sda1 -> /boot, ext4
/dev/sda2 -> /nix,  btrfs
/          -> tmpfs, 由 nixos/minimal-components/impermanence.nix 声明
```

需要提前准备：

```bash
mkdir -p /mnt/nix/persistent/etc/ssh
mkdir -p /mnt/nix/persistent/var/lib/nixos
cp /etc/ssh/ssh_host_ed25519_key /mnt/nix/persistent/etc/ssh/
cp /etc/ssh/ssh_host_ed25519_key.pub /mnt/nix/persistent/etc/ssh/
chmod 600 /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key
```

如果从 NixOS installer 启动，挂载应类似：

```bash
mount -t tmpfs tmpfs /mnt
mkdir -p /mnt/boot /mnt/nix
mount /dev/sda1 /mnt/boot
mount /dev/sda2 /mnt/nix
mkdir -p /mnt/nix/persistent
```

然后再安装或切换。

## 12. 原汁原味判断标准

当前应坚持的标准：

- 主用户名用 `lantian`。
- SSH 端口使用作者模块默认的 `2222`。
- `users.nix`、`home-manager.nix`、`impermanence.nix`、`ssh-harden.nix` 尽量不做个人化修改。
- secrets 仓库只提供替代原作者私有 secrets 的必要内容。
- `/` 使用 tmpfs。
- 持久数据在 `/nix/persistent`。
- 优先使用作者默认 kernel，即 `lantianLinuxCachyOS.lts-lto`。

允许的个人化位置：

- `hosts/ml-builder/*`
- 私有 `nixos-secrets`
- 文档
- 构建缓存/部署辅助配置

## 13. 当前结论

已经确认：

- secrets 替换方案可行。
- `lantian` 用户和 SSH key 已补齐。
- `ml-builder` minimal 配置可以完成构建。
- 标准内核可以完成构建。
- 作者 CachyOS LTO kernel 在本机本地编译失败，需要缓存或其它 builder。
- 直接在当前单 ext4 根分区系统上 `switch` 到作者式 impermanence 不可靠，已经导致 SSH 断开。

下一轮不要继续在半切系统上硬修。

更干净的路线是：

1. 通过控制台进入安装/救援环境。
2. 重分区成作者式布局。
3. 准备 `/nix/persistent`。
4. 用已经修好的 secrets。
5. 优先构建作者默认内核；如果耗时长，由人工负责等待或提前准备 binary cache。
6. 再执行安装/切换。
