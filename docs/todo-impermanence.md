# TODO: 复刻作者的 impermanence 布局

当前先不在 `ml-builder` 上启用作者的 impermanence。原因是 `ml-builder` 现在是普通 ext4 根分区：

```nix
fileSystems."/" = {
  device = "/dev/disk/by-uuid/688546eb-5ea8-406f-b7d9-ec9140fb0ed1";
  fsType = "ext4";
};
```

而作者的 impermanence 模块会把 `/` 改成 tmpfs：

```nix
fileSystems."/" = {
  device = "tmpfs";
  fsType = "tmpfs";
};
```

如果直接启用，会出现 `/` 文件系统定义冲突，也容易导致 SSH host key、密码文件、sops 解密 key 丢失，把机器锁在外面。

## 作者这套布局是什么

核心模块在：

```text
nixos/minimal-components/impermanence.nix
```

它做三件事：

1. `/` 使用 tmpfs，重启后回到干净状态。
2. 真正需要保留的数据放到 `/nix/persistent`。
3. 用 `preservation` 模块把持久化目录/文件映射回原来的路径。

典型持久化内容：

```text
/etc/machine-id
/etc/ssh/ssh_host_ed25519_key
/etc/ssh/ssh_host_rsa_key
/var/lib
/var/log
/var/www
/home/lantian
```

所以作者的 SSH host key 默认路径是：

```text
/nix/persistent/etc/ssh/ssh_host_ed25519_key
/nix/persistent/etc/ssh/ssh_host_rsa_key
```

## 参考对象

作者主力客户端可以参考：

```text
hosts/lt-hp-omen/hardware-configuration.nix
hosts/lt-hp-omen/configuration.nix
```

关键布局：

```text
/                      tmpfs
/boot                  vfat
/nix                   btrfs subvol=nix
/nix/persistent        btrfs subvol=persistent, neededForBoot = true
/nix/persistent/home   btrfs subvol=home
```

## 以后要做的步骤

1. 在 VM 快照环境里测试，不要直接在唯一可用机器上做。
2. 重新规划磁盘，建议使用 btrfs。
3. 建立至少这些 subvolume：

   ```text
   nix
   persistent
   home
   ```

4. 修改 `hosts/ml-builder/hardware-configuration.nix`：

   ```nix
   fileSystems."/nix" = {
     device = "/dev/disk/by-uuid/...";
     fsType = "btrfs";
     options = [ "subvol=nix" "compress-force=zstd" ];
   };

   fileSystems."/nix/persistent" = {
     device = "/dev/disk/by-uuid/...";
     fsType = "btrfs";
     options = [ "subvol=persistent" "compress-force=zstd" ];
     neededForBoot = true;
   };

   fileSystems."/nix/persistent/home" = {
     device = "/dev/disk/by-uuid/...";
     fsType = "btrfs";
     options = [ "subvol=home" "compress-force=zstd" ];
   };
   ```

5. 删除 `hosts/ml-builder/configuration.nix` 里临时覆盖的 SSH host key 路径：

   ```nix
   sops.age.sshKeyPaths = lib.mkForce [ "/etc/ssh/ssh_host_ed25519_key" ];

   services.openssh.hostKeys = lib.mkForce [ ... ];
   ```

6. 回到作者默认：

   ```text
   /nix/persistent/etc/ssh/ssh_host_ed25519_key
   ```

7. 确认这些路径重启后仍然存在：

   ```bash
   ls -l /nix/persistent/etc/ssh/
   ls -l /etc/ssh/
   ls -l /nix/persistent/var/lib/nixos/
   ```

8. 确认 SSH、sops、用户密码都正常后，再考虑删除临时密码登录配置。

## 验收标准

启用成功后应该满足：

- `mount | grep ' / '` 显示 `/` 是 tmpfs。
- `/nix/persistent` 是真实磁盘挂载。
- 重启后 `/etc/ssh/ssh_host_ed25519_key` 指纹不变。
- `sops-nix` 能解密 secrets。
- `root` 和 `lantian` 能用 SSH key 登录。
- `nixos-rebuild switch --flake .#ml-builder -L` 能正常完成。

## 暂时不要做的事

- 不要在 ext4 根分区上直接启用 impermanence。
- 不要在没有快照/救援方式时启用。
- 不要同时保留普通 `/` ext4 和 tmpfs `/` 两套定义。
- 不要在 SSH key 登录没有确认前关闭密码登录。
