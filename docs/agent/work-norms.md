# 工作规范（Work Norms）

> 这些是长期反复被纠正的教训，固化成本规范。任何改动/巡检/部署前先过一遍。

## 1. 改动必须提交并保持仓库对齐

- **每次改动完成后立即提交**（不要攒着、不要等被提醒）
- 提交后**对齐三方**：mac 本地 → push origin → ml-builder（fetch/pull/处理工作区）
- 对齐时**用户的工作区改动（未提交 M/未跟踪目录）绝不丢弃**——stash/checkout 只处理与 origin 一致或自己的改动
- 提交信息写清楚"为什么"（不止"改了什么"）

## 2. 文档与配置对账（防文档漂移）

文档不是装饰品：`docs/agent/` 与 `docs/human/` 是当前配置的**参照**，
改动配置或新增服务时，涉及的值必须同步更新到对应文档，否则下一轮维护
会被过时文档带偏（2026-08 曾因文档滞后积累 98 处 `zhyi.cc` 残留）。

对账触发点（改动涉及以下任一 → 必须同步文档）：

- **域名**：改 vhost / DNS / 证书 → `docs/agent/domain-service-layout.md`、
  `docs/agent/reference.md`、`docs/agent/gcore-dnscontrol-free-plan.md`
- **主机**：新增/退役主机、改 index/IP/ZeroTier 节点 ID →
  `docs/agent/hosts-overview.md`、`docs/agent/reference.md`（主机表与 LAN 表）
- **服务/端口**：新增或改服务入口、端口 →
  `docs/agent/fleet-service-chain.md`、`docs/agent/identity-auth-architecture.md`
- **构建/部署**：改构建流程、缓存链、部署命令 →
  `docs/agent/deployment.md`、`docs/agent/attic-s3-cache.md`
- **巡检**：改监控目标、链路 → `docs/agent/inspection-playbook.md`、
  `docs/agent/monitoring.md`
- **其他**：改 secrets、硬件适配、服务配置 → 对应 `docs/human/` 文档

对账方式：改动提交前先 `rg` 相关文档确认无过时引用；发现过时即一并修，
不要留给下一轮。

## 3. 对照作者原版，不偏离

- 改动任何 `nixos/` 模块前，先 `diff` 上级目录 `../nixos-config-exam/` 的对应文件
- **作者原版是基准**；复刻允许的必要偏离只有：
  - **域名**：单一 `zhyi.xin`（zhyi.cc / moliy.site 已于 2026-08-20 并入，不再使用双域）
  - **用户**：`zhyi`（显示名 Magic Flash）vs 作者 `lantian`（显示名 Lan Tian）；GitHub `zhyiheihei` vs `lantian1998`
  - **硬性值**：时区 `Asia/Shanghai`（作者 America/Los_Angeles）、DN42 ASN `4242423712` / ULA `fdd8:1938:4e88`（作者 2547 / fdbc:f9dc:67ad）、自建主机与私有网络拓扑
  - **模块命名空间** `lantian.*`（xddxdd 模块系统约定）是前缀不是用户名，绝不能替换
- 公共模块里 `LT.hosts.<作者主机>` 引用**直接替换为对应真实主机**（无别名），映射见 `hosts-overview.md`；作者主机引用删除前确认是否影响 eval
- 偏离作者的地方必须在提交信息/注释里说明原因
- 复刻新增的能力（如 rss 链路自动化、immich-rockchip）要独立成模块，不污染作者原版文件
- **磁盘/子卷布局同样要与作者对齐**，不止配置文件。主机级配置逐字对齐但底层磁盘结构不对齐，会导致依赖该结构的服务（如 `lantian.backup` 的 btrfs `subvolume snapshot`）配置通过、运行必失败。物理 client 的子卷布局基准见 `new-host-standard.md`；新主机接入或迁移前先核对子卷，再谈配置对齐

## 4. 不动公共模块

- `flake-modules/`（命令封装、配置生成）和公共 `nixos/optional-apps/*.nix` **不擅自修改**
- 需要行为差异时：用主机级配置（`hosts/<host>/`）覆盖，或新建独立模块，或先问
- 用户说"别动我公共模块"时立即停手

## 5. 查官方/实际，不猜

- 服务配置/限流/行为：先查**官方文档**（wiki/servarr/厂商文档）、**源码**、**实际运行值**
- 不臆断"应该是这样"——用户会问"你确定？""你不会查官方吗？""自己去看实际规则"
- 外部服务被 DNS 劫持时（如 api.m-team.cc 返回 Google），换真实可达域名/从能访问的主机查证

## 6. 巡检看报错/指标，不看服务是否 running

- 见 [`inspection-playbook.md`](inspection-playbook.md)（三层方法 + 各链路清单）
- `systemctl is-active` 只是入口；结论必须以 journalctl 报错、Prometheus 失败指标、数据流转为据

## 7. 聚焦当前任务，不擅自扩散

- 用户说"你只管现在这个问题"——只处理当前问题，不顺手改别的
- 不反复重试同一失败操作（部署/构建失败先分析根因，换方案，不无限重试）

## 8. 部署/构建谨慎，不压生产机

- 构建只发生在 **ml-builder**（greencloud 会 OOM，opi5p 内存压力大）
- opi5p 负载敏感：不连续重试部署、不并发压它
- 远程构建缺输入（no substituter）时：`nix copy --derivation` 到 builder，或 qemu 本机构建，或调整 buildMachines（excludeHosts）
- ml-builder 的 OOM 可能来自单个链接器（如 Firefox 的 `ld.lld` 峰值 25-30G），
  `max-jobs` 管不住单进程内存；不要为提速调大并发，先看 kernel OOM 日志

## 9. 大任务先出方案，确认后实施

- 涉及取舍（如留哪个服务）、停用服务、数据迁移：先给方案+影响面，用户确认后动手
- 数据迁移是长任务时：分批、持久化中间结果、可恢复、不中断用户在用服务

## 10. 主机级代理环境统一维护

- 集群出站代理常量统一在 `helpers/proxy.nix`，规则与特例见
  [`outbound-proxy.md`](outbound-proxy.md)；服务需要代理时引用
  `LT.proxyEnvironment`，禁止内联拼 `socks5://`
- 服务需要额外直连某个域名时，复用已有 bypass 字符串并追加域名，不要在其他文件
  复制一份 `NO_PROXY` 列表
- 涉及公共模块（如 `ncps.nix`）的代理默认值有差异时，用主机级覆盖，并在提交信息
  或注释里说明原因

## 11. 模块分层与参数归属

- 新模块放在 `nixos/optional-apps/`，不在 `hosts/` 层写通用服务模块。
- 代理等主机专属参数放 `hosts/<host>/configuration.nix`，公共模块不写代理。
- 细则与审计命令见 [`module-placement-norms.md`](module-placement-norms.md)。
