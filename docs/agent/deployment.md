# 构建与部署

`hosts/` 是可构建的自有 Colmena Hive，`hosts-exam/` 不参与构建和部署。`Makefile`
与上游逐字对齐，仅保留两个登记偏移：CN 归属主机由控制机并行推闭包、求值
分批串行（均见下）。

所有求值、构建和 Colmena 部署都在本机 `ml-laptop`（主控机）执行，仓库位于
`~/Documents/nixos/nixos-config`；编译重活由 nix-distributed 派给 ml-builder /
opi5p，控制机上不需要其他主机存在仓库克隆：

```bash
cd ~/Documents/nixos/nixos-config
git pull --ff-only   # 有远端改动时
```

## 部署前确认

任何 make/colmena 构建部署发起前，先运行 `tools/pre-deploy-check` 完成两项
确认，未通过不发起（2026-10-13 用户确立，工具不进 Makefile——与上游逐字
对齐，由发起部署的会话/人工执行）：

1. **ncps 可用**。本机唯一 substituter 是 ncps（dragon-q8b，
   `http://192.168.0.66:13851`，`ncps-client` mkForce 无兜底）。服务断开或
   网络异常时 nix 无任何二进制缓存可用，全部转本机源码编译。
2. **ml-builder 在线且派发在位**。`/etc/nix/machines` 必须指向 ml-builder
   （跑过 `nix-remote-build-off` 会整个删掉它），且
   `ssh -p 2222 nix-builder@ml-builder.zhyi.xin true` 可通。该机空闲时人工
   关机，大更新（flake.lock / nvfetcher.toml 有改动，或新增大体积包）前先
   物理开机。`big-parallel` 与交叉内核（requiredSystemFeature
   `aarch64-cross`）仅 ml-builder 承接；aarch64 原生构建依赖 opi5p，涉及
   ARM 包时可顺带确认。

两项任一不成立时发起构建，编译会全部落在本机：本机 32G 内存会被大包并发
编译打满，整机死机，部署整体失败。这是硬门槛，脚本默认拒绝通过；确属小
改动才用 `tools/pre-deploy-check --allow-local-build` 显式豁免。

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

`make servers`、`make all` 及其他 `apply` 目标是有状态变更操作；验证时明确使用
`make build`。

`make servers` / `make all` / `make all-all` 走 `_deploy-tag` 通道（两个偏移的
实现）：先按 `EVAL_CHUNK`（默认 2）台一批串行 `colmena build`（并发求值会打满
32G 内存 OOM），随后 CN 归属主机按 `PUSH_JOBS`（默认 4）并行 `nix copy
ssh-ng` push + switch，非 CN 主机合并为一次 `colmena apply`（其 Succeeded
为真实部署完成）。任一主机失败时整体退出码非零；push 失败的主机在末尾
汇总并打印各自日志（`.gcroots/deploy-<host>.log`）。

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
