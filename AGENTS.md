# Zhyi's NixOS Configuration

## AI 代理使用说明

- 这是一个个人 NixOS 配置仓库，主入口是 `flake.nix`，主机定义位于 `hosts/`，公共系统模块位于 `nixos/`。
- 本仓库是 [xddxdd/nixos-config](https://github.com/xddxdd/nixos-config)（Lan Tian）的复刻；作者原版
  独立 checkout 位于 `../nixos-config-exam`，仅用于 diff 对照，不参与本仓库的求值、构建或部署；
  **每次查看上游前必须先 `git pull`**。
- 主要构建和部署命令见 `Makefile`；首选命令包括 `make build`、`make all`、`make update`、
  `nix flake check`、`nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel`。
- `hosts/` 子目录包含每个主机的 `host.nix`、`configuration.nix` 和 `hardware-configuration.nix`。
  修改主机配置前，请确认是否为目标主机改动。
- `helpers/default.nix` 导出 `LT` 工具集，仓库中的许多模块和 host 配置都依赖它。
- 不要直接改动 secrets 相关输入或硬件配置，除非用户明确要求。
- 修改后请优先验证：`nix flake check` 或 `make build`，并保留 Nix 文件中的原有结构和命名习惯。
- 所有求值、构建、Colmena 部署都在 ml-builder 执行（`ssh ml-builder` → `cd /nix/src/nixos-config`
  → `git pull --ff-only`），本地不跑 nix、不解密 secrets。

## 文档体系（docs/ 按读者分三类）

`docs/README.md` 是总索引；所有文档先按类定位再读：

| 目录 | 读者 | 内容 |
| --- | --- | --- |
| `docs/agent` | agent（执行规范） | 本仓库 agent 必须遵守的规范、操作手册与参照；干活前必读 |
| `docs/human` | 人（指南与记录） | 入门、服务指南、硬件适配、调研、学习笔记、迁移记录；agent 需用时也读 |
| `docs/archive` | 无（历史归档） | 过时/已完成的历史记录，不作为当前操作依据，仅追溯时查阅 |

### agent 必读清单（按优先级）

1. [`docs/agent/work-norms.md`](docs/agent/work-norms.md) —— **工作规范十条**：改动必提交+对齐三方仓库、
   对照作者原版（`../nixos-config-exam`）不偏离、不动公共模块（`flake-modules/` 与公共 `nixos/` 模块）、
   查官方/实际不猜、巡检看报错/指标、聚焦当前任务、构建只用 ml-builder、大任务先出方案。
2. [`docs/agent/skills-recommendation.md`](docs/agent/skills-recommendation.md) —— 任务分级（S/M/L/Debug）
   与 skill 使用规范；skill 与工作规范冲突时以工作规范为准。
3. [`docs/agent/ai-api-gateway-chain.md`](docs/agent/ai-api-gateway-chain.md) —— AI 网关链路硬约束：
   UniAPI 是唯一 Provider 汇聚点；禁止把任一网关反向配置为 UniAPI Provider；禁止重置其运行态数据库。
4. [`docs/agent/module-placement-norms.md`](docs/agent/module-placement-norms.md) —— 模块分层与参数归属规范。
5. [`docs/agent/hosts-overview.md`](docs/agent/hosts-overview.md) —— 当前主机清单与拓扑。
6. [`docs/agent/new-host-standard.md`](docs/agent/new-host-standard.md) —— 新主机接入流程。
7. [`docs/agent/development-handbook.md`](docs/agent/development-handbook.md) —— 开发操作手册：
   快速放置决策、新增 flake 输入、添加模块/overlay、分配端口。
8. [`docs/human/reference/repository-structure.md`](docs/human/reference/repository-structure.md) ——
   仓库结构详解：目录树、模块分层、标签、helpers/dns/home、架构图与依赖图。

### 操作规范索引（按主题）

- 部署与验收：`docs/agent/deployment.md`、`docs/agent/test-ml-builder.md`、`docs/agent/nixos-reinstallation-guide.md`
- 巡检：`docs/agent/inspection-playbook.md`、`docs/agent/monitoring.md`
- 网络与域名：`docs/agent/service-domain-norms.md`（私有服务域名）、`docs/agent/domain-service-layout.md`（公开服务）、
  `docs/agent/reference.md`、`docs/agent/home-lan-ip-plan.md`
- 构建缓存：`docs/agent/attic-s3-cache.md`、`docs/agent/attic-owned-cache-priority.md`、
  `docs/agent/attic-full-store-push.md`、`docs/agent/hydra-build-chain.md`
- 身份与认证：`docs/agent/identity-auth-architecture.md`、`docs/agent/oidc-app-integration.md`
- DNS 发布：`docs/agent/gcore-dnscontrol-free-plan.md`
- 服务位置：`docs/agent/fleet-service-chain.md`

## 硬性规则摘要（全文见 docs/agent/work-norms.md）

1. 改动必须提交并保持仓库对齐（本地 → origin → ml-builder）；用户未提交改动绝不丢弃。
2. 对照作者原版（`../nixos-config-exam`，查看前先 git pull）不偏离；允许偏离只有硬性偏离：
   域名（zhyi.xin/zhyi.cc/moliy.site vs xuyh0120.win/lantian.pub/ltn.pw）、硬编码用户名（zhyi vs lantian）、
   复刻特有主机/服务；偏离必须说明原因。
3. 不动公共模块：`flake-modules/` 与公共 `nixos/optional-apps/*.nix` 不擅自修改；需要差异用主机级覆盖或
   新建独立模块，或先问。用户说「别动公共模块」立即停手。
4. 查官方/实际，不猜：服务配置/限流/行为先查官方文档、源码、实际运行值。
5. 巡检看报错/指标，不看服务是否 running（见 `docs/agent/inspection-playbook.md`）。
6. 聚焦当前任务，不擅自扩散；不无限重试同一失败操作（先分析根因换方案）。
7. 部署/构建谨慎，不压生产机：构建只在 ml-builder（greencloud 会 OOM、opi5p 负载敏感，不并发压）。
8. 大任务（新主机接入、服务迁移/停用、跨模块重构、数据迁移、上游对齐大改动）先出方案确认后实施，分批可回滚。
9. 主机级代理统一在 `hosts/<host>/configuration.nix` 的 proxyBypass/proxyEnvironment 维护，不复制 NO_PROXY 列表。
10. 模块分层与参数归属见 `docs/agent/module-placement-norms.md`；公共模块必须提供 `options.lantian.<name>`，
    只在 `config = lib.mkIf cfg.enable` 中启用，禁止导入即生效。

## 磁盘与持久化约束（物理 client）

- 作者体系中的物理 `client` 默认使用 tmpfs 作为 `/`，该行为由
  `nixos/minimal-components/impermanence.nix` 提供；不要为这类主机长期保留
  普通 ext4 `/` 覆盖。
- 物理 client 的磁盘至少应包含 FAT32 EFI `/boot` 和持久化 `/nix`。作者常用
  Btrfs 挂载 `/nix`，选项为 `compress-force=zstd`、`autodefrag`、`nosuid`、
  `nodev`；简单设备可让 `/nix/persistent` 直接位于该 Btrfs 文件系统内。
- `/nix` 是独立文件系统时必须设置 `fileSystems."/nix".neededForBoot = true`。
  system closure 和 profile 都位于该文件系统；缺少早期挂载声明时，即使闭包复制
  和安装命令成功，冷启动仍可能因找不到 closure 而失败。
- 不要把已经运行的普通 ext4-root NixOS 直接在线 `switch` 到 tmpfs-root /
  preservation 架构。首次适配应从安装环境按目标挂载结构重新安装，否则服务
  重载可能停在旧根目录与新持久化结构之间，导致 systemd 和 SSH 激活失败。
- 安装前必须准备 `/mnt/nix/persistent/etc/ssh`，保存或生成 SSH host keys。
  SOPS 默认读取 `/nix/persistent/etc/ssh/ssh_host_ed25519_key`，OpenSSH 也从
  `/nix/persistent/etc/ssh/` 读取 host keys。缺少这些文件会导致解密或 sshd
  启动失败。
- `hosts/ml-2700` 中曾使用的 ext4 `/` 和 `/etc/ssh` SOPS key 路径只属于
  普通安装阶段的临时兼容方案；重装复刻作者布局时应移除，而不是继续叠加覆盖。
- 判断磁盘结构时优先参考作者的物理 client，例如
  `nixos-config-exam/hosts/lt-dell-wyse/hardware-configuration.nix`；复杂的加密和
  Btrfs 子卷布局再参考 `lt-hp-omen`，不要无必要引入。

## 补丁引用链（patches/）

| 补丁类型 | 位置 | 接入方式 |
| --- | --- | --- |
| 通用包/服务补丁 | `patches/<pkg>-<desc>.patch` | 由 `overlays/*.nix` 或 `nixos/*` 模块显式 `patches/<file>.patch ]` |
| Nixpkgs 补丁 | `patches/nixpkgs/<PR 或描述>.patch` | `flake-modules/nixpkgs-options.nix` 对 `pkgs`/`pkgsWithCuda` 自动应用，不单独引用；Nixpkgs PR 用 `nix run .#add-pr <PR>` 拉取 |
| 板级/内核补丁 | `nixos/hardware/<board>` 或 `pkgs/<kernel>` | 由对应硬件模块/内核包局部引用，不放进 `patches/` 根目录 |

补丁必须保留引用链：`patches/` 根目录不留未被引用的 `.patch`，服务/包删除时
同步删除对应补丁。新增后运行 `rg '<文件名>' . --glob '*.nix'` 确认已被引用。

## 常用命令与验证

```bash
# 检查配置
nix flake check

# 构建主机配置
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel

# 部署到远程主机（Colmena，ml-builder 执行）
nix run .#colmena apply --on <host>

# 更新 DNS 配置
nix run .#dnscontrol

# 提交前审计命令（规范见 module-placement-norms.md）
rg -n 'HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy|NO_PROXY|no_proxy' nixos/ --glob '*.nix'
rg -n 'options\.' hosts/ --glob '*.nix'
rg -n 'environment = .*mkForce' nixos/ --glob '*.nix'
rg -n 'io.containers.autoupdate' nixos/optional-apps/ --glob '*.nix'
rg -n '\.\./\.\./hosts/' nixos/ --glob '*.nix'
```
