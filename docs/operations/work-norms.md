# 工作规范（Work Norms）

> 这些是长期反复被纠正的教训，固化成本规范。任何改动/巡检/部署前先过一遍。

## 1. 改动必须提交并保持仓库对齐

- **每次改动完成后立即提交**（不要攒着、不要等被提醒）
- 提交后**对齐三方**：mac 本地 → push origin → ml-builder（fetch/pull/处理工作区）
- 对齐时**用户的工作区改动（未提交 M/未跟踪目录）绝不丢弃**——stash/checkout 只处理与 origin 一致或自己的改动
- 提交信息写清楚"为什么"（不止"改了什么"）

## 2. 对照作者原版，不偏离

- 改动任何 `nixos/` 模块前，先 `diff` 上级目录 `../nixos-config-exam/` 的对应文件
- **作者原版是基准**；复刻允许的必要偏离只有：域名（zhyi.xin/zhyi.cc vs xuyh0120.win）、用户（zhyi vs lantian）、复刻特有主机/服务
- 偏离作者的地方必须在提交信息/注释里说明原因
- 复刻新增的能力（如 rss 链路自动化、immich-rockchip）要独立成模块，不污染作者原版文件

## 3. 不动公共模块

- `flake-modules/`（命令封装、配置生成）和公共 `nixos/optional-apps/*.nix` **不擅自修改**
- 需要行为差异时：用主机级配置（`hosts/<host>/`）覆盖，或新建独立模块，或先问
- 用户说"别动我公共模块"时立即停手

## 4. 查官方/实际，不猜

- 服务配置/限流/行为：先查**官方文档**（wiki/servarr/厂商文档）、**源码**、**实际运行值**
- 不臆断"应该是这样"——用户会问"你确定？""你不会查官方吗？""自己去看实际规则"
- 外部服务被 DNS 劫持时（如 api.m-team.cc 返回 Google），换真实可达域名/从能访问的主机查证

## 5. 巡检看报错/指标，不看服务是否 running

- 见 `docs/operations/inspection-playbook.md`（三层方法 + 各链路清单）
- `systemctl is-active` 只是入口；结论必须以 journalctl 报错、Prometheus 失败指标、数据流转为据

## 6. 聚焦当前任务，不擅自扩散

- 用户说"你只管现在这个问题"——只处理当前问题，不顺手改别的
- 不反复重试同一失败操作（部署/构建失败先分析根因，换方案，不无限重试）

## 7. 部署/构建谨慎，不压生产机

- 构建只发生在 **ml-builder**（colocrossing 会 OOM，opi5p 内存压力大）
- opi5p 负载敏感：不连续重试部署、不并发压它
- 远程构建缺输入（no substituter）时：`nix copy --derivation` 到 builder，或 qemu 本机构建，或调整 buildMachines（excludeHosts）
- ml-builder 的 OOM 可能来自单个链接器（如 Firefox 的 `ld.lld` 峰值 25-30G），
  `max-jobs` 管不住单进程内存；不要为提速调大并发，先看 kernel OOM 日志

## 8. 大任务先出方案，确认后实施

- 涉及取舍（如留哪个服务）、停用服务、数据迁移：先给方案+影响面，用户确认后动手
- 数据迁移是长任务时：分批、持久化中间结果、可恢复、不中断用户在用服务

## 9. 主机级代理环境统一维护

- 主机级代理统一在 `hosts/<host>/configuration.nix` 的 `proxyBypass` /
  `proxyEnvironment` 中维护
- 服务需要额外直连某个域名时，复用已有 bypass 字符串并追加域名，不要在其他文件
  复制一份 `NO_PROXY` 列表
- 涉及公共模块（如 `ncps.nix`）的代理默认值有差异时，用主机级覆盖，并在提交信息
  或注释里说明原因

## 10. 模块分层与参数归属

- 新模块放在 `nixos/optional-apps/`，不在 `hosts/` 层写通用服务模块。
- 代理等主机专属参数放 `hosts/<host>/configuration.nix`，公共模块不写代理。
- 细则与审计命令见 [`module-placement-norms.md`](./module-placement-norms.md)。
