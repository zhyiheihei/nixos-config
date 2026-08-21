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
nix run .#colmena -- build --on rock5c

# 构建并切换指定主机。
nix run .#colmena -- apply --on rock5c

# 以逗号分隔多个主机。
nix run .#colmena -- apply --on rock5c,greencloud
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

## macOS / nix-darwin 主机

`macmini`（`aarch64-darwin`）不参与 Colmena，而是由 `flake-modules/
darwin-configurations.nix` 单独求值成 `darwinConfigurations`，在本机用
`darwin-rebuild` 部署。需 SSH 到 macmini（走 **22 端口**，非 2222）后在
macOS 本机执行：

```bash
# 在 macmini 本机
cd ~/nixos-config
sudo darwin-rebuild switch --flake /Users/molishanguang/nixos-config#macmini --impure
```

新版 `darwin-rebuild` 要求 system activation 以 root 运行，必须加 `sudo`。
接入、网络、stylix 边界与常见踩坑见 [Mac mini](../human/hardware/macmini.md)；
预拉闭包导入本机 store 的加速方案见
[darwin 闭包导入加速](../human/migrations/macmini-darwin-import.md)。

不要使用 `git reset --hard` 或 `git clean -fd` 来“同步”部署机；正常情况只需
`git pull --ff-only`。遇到并发提交冲突时先检查 `git status`，保留本地未提交改动。

## 验收

```bash
systemctl is-system-running
systemctl --failed
readlink -f /run/current-system
```

服务变更还应检查对应的 systemd 单元、Nginx 配置和正式 URL。缓存、网络与 Hydra
的专项验证分别以 [网络参照](reference.md)、[Attic 手册](attic-s3-cache.md)
和 [Hydra 构建链路](hydra-build-chain.md) 为准。
