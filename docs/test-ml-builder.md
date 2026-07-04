# 测试 ml-builder 强构建机

这篇文档记录把 `ml-builder` 作为强机器/虚拟机构建机进行首次测试的步骤。

当前目标不是做一套“适合我临时用”的简化 NixOS，而是尽量一比一复刻原作者项目。也就是说：

- 用户名使用 `lantian`
- SSH 服务端口使用 `2222`
- `/` 使用 tmpfs
- 持久数据使用 `/nix/persistent`
- 用户、SOPS、SSH host key 都走作者原生模块

## 0. 当前配置定位

关键文件：

```text
hosts/ml-builder/host.nix
hosts/ml-builder/configuration.nix
hosts/ml-builder/hardware-configuration.nix
local-secrets/
```

当前角色：

```nix
tags = with tags; [
  lan-access
  nix-builder
];
```

这意味着它会创建 `lantian` 和 `nix-builder` 用户。`lantian` 是交互登录用户，`nix-builder` 供其他机器远程构建使用。

## 1. 先给 VM 做快照

首次测试前一定先在虚拟机管理器里创建快照。

建议快照名：

```text
before-nixos-ml-builder-impermanence
```

原因：作者这套配置会把 `/` 变成 tmpfs，磁盘布局不对时可能直接进不了新系统。快照是这一步的安全绳。

## 2. 准备作者式磁盘布局

当前 `hosts/ml-builder/hardware-configuration.nix` 按 BIOS VM 写成：

```text
/dev/sda1 -> /boot, ext4
/dev/sda2 -> /nix, btrfs
```

项目里的 `nixos/minimal-components/impermanence.nix` 会自动把 `/` 配成 tmpfs，并把持久化目录放到：

```text
/nix/persistent
```

所以不要再配置普通 ext4 `/`。如果你是新 VM，推荐直接重装/重分区成上面的布局。

在目标机确认：

```bash
lsblk -f
findmnt /boot
findmnt /nix
```

预期：

- `/boot` 是真实磁盘分区
- `/nix` 是 btrfs
- `/` 在切换后会变成 tmpfs

如果分区不是 `/dev/sda1` 和 `/dev/sda2`，按 `lsblk -f` 的结果修改：

```text
hosts/ml-builder/hardware-configuration.nix
```

## 3. 确认启动模式

在 `ml-builder` 上执行：

```bash
test -d /sys/firmware/efi && echo UEFI || echo BIOS
```

当前配置按 BIOS 写：

```nix
boot.loader.grub.device = "/dev/sda";
```

如果输出是 `BIOS`，保持现状。

如果输出是 `UEFI`，按作者其他 UEFI 机器的形式改成：

```nix
boot.loader.grub = {
  efiSupport = true;
  device = "nodev";
};
```

同时 `/boot` 应该是 vfat EFI 分区。

## 4. 同步配置仓库

进入配置目录：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
```

确认当前 flake 能看到 `ml-builder`：

```bash
nix flake show | grep ml-builder
```

## 5. 更新 secrets 输入

`ml-builder` 需要读取你的私有 secrets 仓库。

先确认 GitHub SSH 能通：

```bash
ssh -T git@github.com
```

成功时会看到类似：

```text
Hi zhyiheihei! You've successfully authenticated, but GitHub does not provide shell access.
```

然后更新 secrets：

```bash
nix flake update secrets
```

## 6. 确认 secrets 里有 lantian 的登录公钥

主项目会从 secrets 仓库读取：

```text
ssh/lantian.nix
ssh/nix-builder.nix
glauth-users.nix
```

含义：

- `ssh/lantian.nix`：允许 `root` 和 `lantian` SSH 登录的公钥
- `ssh/nix-builder.nix`：允许 `nix-builder` 远程构建登录的公钥
- `glauth-users.nix`：`lantian` 的 bcrypt 密码 hash 和邮箱

如果 `passBcrypt = "*";`，密码登录是锁定的，只能用 SSH key。

## 7. 给 ml-builder 增加 SOPS 解密权限

作者式路径下，SOPS 解密使用持久化的 SSH host key：

```text
/nix/persistent/etc/ssh/ssh_host_ed25519_key
```

第一次 switch 前，如果这个文件还不存在，可以先用当前系统的 host key 生成 recipient：

```bash
nix shell nixpkgs#ssh-to-age -c ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
```

切换成功后再确认持久化路径：

```bash
ls -l /nix/persistent/etc/ssh/
nix shell nixpkgs#ssh-to-age -c ssh-to-age -i /nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
```

把输出写进 `local-secrets/.sops.yaml`，然后重新生成或 `updatekeys` 加密的 `common/*.yaml`。

如果旧 key 已经丢失，而 `common/*.yaml` 只是空占位符，可以重新生成：

```bash
cd ~/nixos-secrets
nix shell nixpkgs#sops -c ./regenerate-placeholder-yaml.sh
git add .sops.yaml common/*.yaml
git commit -m "Regenerate placeholder secrets for ml-builder"
git push
```

然后回到主配置：

```bash
cd /etc/nixos
nix flake update secrets
```

## 8. 先 build，不 switch

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"

nix build .#nixosConfigurations.ml-builder.config.system.build.toplevel -L \
  --option max-jobs 2 \
  --option cores 6
```

成功后会出现：

```text
./result
```

如果遇到 GeoLite 404，按作者方式先更新 `nur-xddxdd`：

```bash
nix flake update nur-xddxdd
```

## 9. 再 switch

确认有快照后执行：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"

nixos-rebuild switch --flake .#ml-builder -L \
  --option max-jobs 2 \
  --option cores 6
```

如果 switch 返回非 0，不算成功。先看：

```bash
systemctl --failed
journalctl -u sops-install-secrets.service -n 100 --no-pager
journalctl -u userborn.service -n 100 --no-pager
journalctl -u local-fs.target -n 100 --no-pager
```

## 10. 验证系统状态

```bash
hostname
findmnt /
findmnt /nix
findmnt /nix/persistent
systemctl status sshd --no-pager
ss -lntp | grep ssh
id lantian
id nix-builder
```

预期：

- hostname 是 `ml-builder`
- `/` 是 tmpfs
- `/nix` 是 btrfs
- `/nix/persistent` 存在
- sshd 监听 `2222`
- `lantian` 存在
- `nix-builder` 存在

## 11. 从 Mac 测试登录

```bash
ssh -p 2222 root@192.168.3.176
ssh -p 2222 lantian@192.168.3.176
ssh -p 2222 nix-builder@192.168.3.176 true
```

如果你要用 SSH agent 转发：

```bash
ssh -A -p 2222 root@192.168.3.176
```

进入后确认 agent：

```bash
echo "$SSH_AUTH_SOCK"
ssh-add -l
ssh -T git@github.com
```

## 12. 从弱机器手动测试远程构建

先不要急着接入作者的 `nix-distributed.nix`，可以从 `ml-2700u` 手动指定 builder 测试。

在 `ml-2700u` 上：

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
ssh -p 2222 nix-builder@192.168.3.176 true
```

然后找一个很小的包测试远程构建：

```bash
nix build nixpkgs#hello -L \
  --builders "ssh-ng://nix-builder@192.168.3.176 x86_64-linux 1 6 - - -" \
  --option builders-use-substitutes true
```

## 13. 自动远程构建

作者的 `nix-distributed.nix` 会自动扫描所有带 `nix-builder` 标签的 host：

```nix
lib.filterAttrs (n: v: v.hasTag LT.tags.nix-builder) LT.otherHosts
```

原作者域名体系默认会连接：

```text
ml-builder.lantian.pub
```

如果你要一比一复刻，就需要后续把自己的 DNS、host metadata、known_hosts 也整理成同一套体系。短期仍可以先用手动 `--builders` 验证构建链路。
