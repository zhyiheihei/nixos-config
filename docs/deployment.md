# 构建与部署

`hosts/` 是可构建的自有 Colmena Hive，`hosts-exam/` 不参与构建和部署。`Makefile`
沿用作者的 Colmena 标签目标，不额外维护一份在线主机清单；同时保留 `help` 作为
安全的默认目标。

所有求值、构建和 Colmena 部署都在 `ml-builder` 执行，避免在本机或低配节点临时
运行 Nix：

```bash
ssh -A -p 2222 root@ml-builder.zhyi.cc
cd /nix/src/nixos-config
git pull --ff-only
```

## 常用命令

```bash
# 显示用法，不执行构建或部署。
make

# 构建 hosts/ 中的整个 Hive，但不上传、不切换。
make build

# 构建带 @default 标签的主机，但不切换。
make build-default

# 构建 x86_64-linux 主机，但不切换。
make build-x86
```

`make servers`、`make all` 及其他 `apply` 目标是有状态变更操作。裸 `make` 只显示
帮助；验证时明确使用 `make build`。

## 指定主机

只处理某一台或少量主机时，直接使用 Colmena：

```bash
# 只构建，不部署。
nix run .#colmena -- build --on ml-home-vm

# 构建并切换指定主机。
nix run .#colmena -- apply --on ml-home-vm

# 以逗号分隔多个主机。
nix run .#colmena -- apply --on ml-home-vm,colocrossing
```

先确认 SSH、DNS 和目标机当前地址可用。网络、入口或 SSH host key 变更后，不要把
受影响主机和无关主机混在同一次 `apply` 中。

## 保留主机

`pve-2700` 位于 `hosts/`，属于自有保留主机，但不应随日常在线主机一起部署。只有
在机器状态、网络与 SSH 身份均已确认后，才显式构建或部署：

```bash
nix run .#colmena -- build --on pve-2700
nix run .#colmena -- apply --on pve-2700
```

不要使用 `git reset --hard` 或 `git clean -fd` 来“同步”部署机；正常情况只需
`git pull --ff-only`。遇到并发提交冲突时先检查 `git status`，保留本地未提交改动。

## 验收

```bash
systemctl is-system-running
systemctl --failed
readlink -f /run/current-system
```

服务变更还应检查对应的 systemd 单元、Nginx 配置和正式 URL。缓存、网络与 Hydra
的专项验证分别以 [网络参照](./network-reference.md)、[Attic 手册](./attic-s3-cache.md)
和 [PVE 验收](./vm-replication-chain.md) 为准。
