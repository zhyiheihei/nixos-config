# NixOS 系统层仓库

## 五件套分工

- `nixos-facter`：生成硬件报告 JSON，替代 `nixos-generate-config` /
  `nixos-hardware`；对应 NixOS modules 已在 nixpkgs。
- `disko`：声明式磁盘分区。支持 GPT/LVM/LUKS/btrfs/ZFS 等。
- `nixos-anywhere`：通过 SSH 远程装 NixOS，内部使用 disko + kexec。
- `colmena`：本地定义 `colmenaHive`，并行构建、拷贝、切换多台机器。
- `srvos`：服务器“口味”模块集合，提供 `server`、Hetzner 硬件、
  GitHub Actions runner 等基线。

## 生命周期

```text
新机器：facter 出硬件报告
      → disko 定义磁盘布局
      → nixos-anywhere 远程装机
      → colmena 日常 apply
      → srvos 提供服务器基线
```

## 与本地基础设施的关系

当前 `ml-builder`、`pve-5700u`、`opi5p` 等机器使用 colmena 部署模型。
新机器接入先走 SSH host key + SOPS，再进 `hosts/`，最后 `colmena apply`。
