# Nix 复刻学习总纲

## 目标

以复刻作者 xddxdd 的两套仓库为路径，完整学会他这套 Nix 体系：

- 主仓库：`nixos-config`，fork 自
  [xddxdd/nixos-config](https://github.com/xddxdd/nixos-config)，管理所有
  NixOS 主机、Home Manager、overlay、NixOS modules、DNS 和部署；
- 包补充：`zhyi-packages`，fork 自
  [xddxdd/nur-packages](https://github.com/xddxdd/nur-packages)，只收录
  nixpkgs 里没有的自用包，通过 NUR 对外暴露；
- 私有资产：`nixos-secrets`，存放 SOPS 加密密钥、主机身份、WireGuard 私钥
  和隐藏模块，不进入主仓库。

## 仓库地图

### nixos-config（主仓库）

```text
flake.nix                    # 所有输入与输出
flake-modules/               # colmena、nixd、nixpkgs-options、commands
helpers/                     # LT 辅助库、常量、主机选项
hosts/                       # 每台主机的 host.nix / configuration.nix
nixos/                       # 公共 NixOS 模块，按角色分层
home/                        # Home Manager 配置
overlays/                    # nixpkgs overlay
patches/                     # nixpkgs 与自有补丁
pkgs/                        # 不在 nixpkgs 的自定义包
dns/                         # DNSControl 配置生成
Makefile                     # colmena 部署快捷命令
docs/                        # 运维与审计文档
```

部署模型沿用作者的 Colmena Hive：`hosts/` 是唯一主机来源，`make build` 构建，
`make servers` / `make all` 按标签批量切换。

### zhyi-packages（包补充）

```text
nvfetcher.toml               # 每个包的版本源与 fetch 规则
_sources/generated.nix       # nvfetcher 生成结果，不手改
pkgs/                        # python3Packages 与 uncategorized
helpers/                     # group、nvfetcher-loader、meta
flake-modules/               # commands、treefmt、pre-commit
.github/workflows/           # NUR 求值、meta 检查、自动更新
repos.json                   # nur-check 使用的自注册表
```

### nixos-secrets（私有资产）

- SOPS 加密的 YAML；
- 每台主机的 SSH host key、WireGuard 私钥；
- `nixos-hidden-module` 等不在主仓库公开的模块；
- Homepage、UniAPI、备份等私有配置。

## 与上游对照

### xddxdd/nixos-config

本仓库已经做过多次审计，结论是“公共模块默认行为跟作者，本地拓扑通过参数和
主机配置表达”。

必须跟随作者的部分：

- `nixos/minimal.nix`、`nixos/server.nix`、`nixos/pve.nix` 的角色组合；
- Nginx hosts 生成、Hydra post-build、impermanence、socket-activated iperf
  等公共实现；
- 模块接口、弃用项、`public-facing` 边界等安全语义；
- colmena Hive、标签体系和 `LT` 辅助库的框架。

必须保留的本地差异：

- `hosts/` 主机名称、IP、SSH host key、城市和标签；
- `dns/` 中的 `zhyi.xin` 域名；
- SOPS recipient 与私有 secrets；
- ARM 开发板、Rockchip 内核、设备树、reDroid 和存储适配；
- 私有 Attic、NCPS、VaultS3、家庭网络和跨主机服务拓扑；
- ml-builder / pve-5700u / opi5p 的定向构建图与资源权重。

### xddxdd/nur-packages

`zhyi-packages` 已经对齐了上游大部分骨架：

- `helpers/`、`tools/update_sources.py`、`tools/postprocess_nvfetcher.py`
  与上游一致；
- `.github/workflows/build.yml` 与 `auto-update.yml` 只差用户名/bot 名；
- `flake-modules/_internal/commands.nix` 的 `nur-check` 语义一致；
- `check_package_meta.py` 只是把 `xddxdd` 换成了 `zhyiheihei`。

仍存在的差距：

1. 注册 PR [nix-community/NUR#1197](https://github.com/nix-community/NUR/pull/1197)
   已开且两个检查通过，等待合并；合并前 `test-nur-eval` 仍在
   `bin/nur index nur-combined` 阶段失败；
2. 已添加 MIT `LICENSE` 并提交（2026-08-08）；
3. 9 个 python 包的 `meta.maintainers` 已补齐，`check-package-meta`
   已由 GitHub Actions 验证通过（2026-08-08）；
4. `flake.nix` 精简掉了上游的 colmena hive、NixOS modules、Cuda、pinned
   nixpkgs 和 python3Packages overlay；
5. `helpers/meta.nix` 只有 Attic，上游是 Attic + Cachix。

## 学习路线

### 阶段 0：读懂两个仓库的骨架

先不写代码，逐文件回答“为什么存在”：

- `flake.nix` 的输入如何被 `flake-parts` 组织；
- `hosts/<name>/host.nix` 如何决定标签、地址和模块导入；
- `nixos/` 按角色分层后，`server`、`client`、`minimal` 各导入了什么；
- `helpers/` 的 `LT` 如何被 `flake.nix` 注入；
- `pkgs/` 的自定义包如何被 overlay 和 NixOS 模块使用；
- `nvfetcher.toml` 如何变成 `_sources/generated.nix`，再变成包表达式。

### 阶段 1：跑通本机工作流

- `nixos-config`：在 `ml-builder` 上执行 `git pull --ff-only`、`make build`、
  单主机 `colmena build --on <host>`；
- `zhyi-packages`：执行 `nix run .#update`、`nix run .#nur-check`、
  `tools/check_package_meta.py`，理解每一步的产物。

### 阶段 2：补合规并注册 NUR

- 给 `zhyi-packages` 添加 MIT `LICENSE`；
- 补齐所有包的 `meta.maintainers`、`homepage`、`license`、`mainProgram`；
- 在 `nix-community/NUR` 的 `repos.json` 中登记 `zhyiheihei` 并开 PR；
- PR 合并后重跑 Build workflow，确认三个 job 全绿。

### 阶段 3：复刻上游进阶能力

- `nixos-config`：把 `codex/upstream-align` 分支上的对齐成果合并回 `master`；
- 恢复 `flake.nix` 中的 `python3Packages` overlay；
- 恢复 `pkgsWithCuda`、`legacyPackagesWithCuda`、pinned nixpkgs；
- 从上游 `nur-xddxdd` 的 flake-modules 中学习 colmena hive 的接入方式；
- 把本地差异改造成参数，避免散落 `hostname == ...` 判断。

### 阶段 4：学会 nix-community 生态工具

- `colmena`：多主机并行部署；
- `disko` / `nixos-anywhere`：磁盘与远程装机；
- `nixos-facter`：硬件报告；
- `home-manager` / `stylix` / `nixvim`：用户环境；
- `nix-init` / `nurl` / `nixpkgs-update`：打包与上游化；
- `nix-community/infra`：组织级基础设施样板。

### 阶段 5：反哺 nixpkgs

当某个包不再只属于个人自用：

1. 用 `nix-init` 生成包骨架；
2. 用 `nixpkgs-update` 验证更新；
3. 提交 PR 到 NixOS/nixpkgs；
4. 合并后从 `zhyi-packages` 删除，避免重复维护。

## 当前差距清单

### nixos-config

- 公共模块已有审计记录，后续每次同步先记录作者基准提交；
- `codex/upstream-align` 分支包含尚未合并的上游对齐成果，需要单独验收；
- 当前 worktree 有未提交修改，属于用户工作，不在本指南范围内；
- 全局 `nix flake check` 的 DNS SSHFP import-from-derivation 缺口仍未关闭。

### zhyi-packages

- 添加 MIT `LICENSE`（已完成并提交）；
- 补齐 9 个 python 包的 `meta.maintainers`（GitHub Actions 已验证）；
- `vaults3` 已补 `meta.sourceProvenance`（预编译二进制）；
- 注册 PR [nix-community/NUR#1197](https://github.com/nix-community/NUR/pull/1197)
  已开，等待合并；
- `check-package-meta` 已绿；`test-nur-eval` 等注册合并后重跑；
- 可选：恢复上游 colmena / Cuda / python overlay / Cachix。

## 验证清单

- [ ] `nixos-config` 在 `ml-builder` 上 `make build` 通过；
- [ ] 单主机 `colmena build --on <host>` 通过；
- [ ] `zhyi-packages` 的 `tools/check_package_meta.py` 通过；
- [ ] `nix run .#nur-check` 通过；
- [ ] `nix-community/NUR` 注册 PR 已合并；
- [ ] Build workflow 三个 job 全绿；
- [ ] `nur.nix-community.org` 能搜到包；
- [ ] Attic substituter 在目标主机可用；
- [ ] 能解释 `flake.nix`、`hosts/`、`helpers/`、`pkgs/`、
  `nvfetcher.toml`、workflows 的每一层。

## 相关文档

- [当前 hosts 概览](../../agent/hosts-overview.md)
- [构建与部署](../../agent/deployment.md)
- [新主机接入规范](../../agent/new-host-standard.md)
- [模块分层与参数归属规范](../../agent/module-placement-norms.md)
- [zhyi-packages 复刻指南](zhyi-packages-guide.md)
