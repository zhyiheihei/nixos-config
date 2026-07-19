# 构建与部署当前主机

`Makefile` 是构建和部署命令的权威来源。当前在线部署集合定义为：

```text
ml-builder, ml-home-vm, pve-5700u, colocrossing, jpvm, logvm, cnvm
```

所有求值、构建和 Colmena 部署都在 `ml-builder` 执行，避免在本机或低配节点临时
运行 Nix：

```bash
ssh -A -p 2222 root@ml-builder.zhyi.cc
cd /nix/src/nixos-config
git pull --ff-only
```

## 常用命令

```bash
# 查看完整命令说明；不执行构建或部署。
make help

# 只求值当前在线主机。
make current-eval

# 构建当前在线主机，但不上传、不切换。
make current-build

# 构建、上传并切换当前在线主机。
make current
```

`make current` 是有状态变更的操作。先执行 `make current-eval`，再执行
`make current-build`；只有确认要把同一提交部署到全部当前在线主机时才执行
`make current`。

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

## 非当前集合的主机

`pve-2700`、作者保留的主机模板以及离线机器不属于 `make current`。只有在机器已经
安装对应系统、网络与 SSH 身份均已确认后，才显式构建或部署：

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
