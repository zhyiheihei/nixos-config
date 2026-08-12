# Skill 使用规范与推荐

> 依据 `AGENTS.md`、[`work-norms.md`](./work-norms.md)、
> [`module-placement-norms.md`](./module-placement-norms.md)、
> [`deployment.md`](./deployment.md) 与 [`inspection-playbook.md`](./inspection-playbook.md)
> 整理。本文是 Codex 在本仓库内选择和使用 skill 的强制路由规则；与 skill 自带默认流程冲突时，
> 以仓库规范为准。

## 1. 当前可用 skill

| 来源 | skill | 在本仓库的作用 |
| --- | --- | --- |
| Superpowers 插件（已装） | `using-superpowers` | 开场做 skill 路由，不替代本文件 |
| Superpowers 插件 | `brainstorming` | 复杂任务先澄清需求并出设计 |
| Superpowers 插件 | `writing-plans` | 复杂任务拆解为可执行计划 |
| Superpowers 插件 | `systematic-debugging` | 故障/异常先找根因再修 |
| Superpowers 插件 | `verification-before-completion` | 完成/构建/修复必须有实证 |
| Superpowers 插件 | `test-driven-development` | 只用于 `pkgs/`、`tools/` 等可测代码 |
| Superpowers 插件 | `requesting-code-review` / `receiving-code-review` | 大改动或上游对齐审计后使用 |
| Superpowers 插件 | `using-git-worktrees` | 仅本地多特性并行时使用 |
| Superpowers 插件 | `dispatching-parallel-agents` | 仅独立链路排障 |
| Superpowers 插件 | `subagent-driven-development` / `executing-plans` | 已确认计划后的执行阶段 |
| Superpowers 插件 | `finishing-a-development-branch` | 收尾时按仓库流程提交并同步 |
| Superpowers 插件 | `writing-skills` | 只有反复踩坑且无法脚本化时才建新 skill |
| GitHub 插件（已装） | `github` / `gh-fix-ci` / `gh-address-comments` / `yeet` | GitHub/CI/PR 场景 |
| 系统 | `skill-installer` / `openai-docs` / `plugin-creator` / `skill-creator` / `imagegen` | 装 skill、查 OpenAI 文档等特定场景 |

## 2. 任务分级（强制入口）

开始任何任务前先分级。分级决定启用哪些 skill，避免把简单问题流程化，也避免复杂问题
被直接跳过方案和验证。

| 级别 | 例子 | 必做 | 默认不做 |
| --- | --- | --- | --- |
| S | 改端口常量、修 typo、补文档链接、单主机单选项 | 按仓库规范验证、提交、对齐 | `brainstorming`、`writing-plans`、TDD、worktree、并行 agent |
| M | 新增 `optional-apps` 模块、调整单个服务、做一次巡检/审计 | 先读规范/官方文档；有取舍先给方案；验证；按需 review | 未确认就对生产机 apply |
| L | 新主机接入、服务迁移/停用、跨模块重构、数据迁移、上游对齐大改动 | `brainstorming` + `writing-plans` + 用户确认 + 分批可回滚 | 未确认直接实施 |
| Debug/Inspection | 构建失败、服务报错、链路异常、巡检 | `systematic-debugging` + `verification-before-completion` + inspection-playbook | 只看 `is-active`、凭感觉修 |
| CI/GitHub | dnscontrol/Actions 失败、PR review、issue 梳理 | `gh-fix-ci` / `gh-address-comments` / `github` | 不查日志/上下文就改 workflow |
| Skill 治理 | 安装/编写新 skill | `skill-installer` / `writing-skills` + 冲突检查 | 不读 SKILL.md 就安装 |

## 3. 推荐启用与边界

| skill | 何时强制 | 何时可选 | 何时不用 |
| --- | --- | --- | --- |
| `brainstorming` | L 必用；M 涉及取舍时 | M 简单增强 | S；Debug |
| `writing-plans` | L 必用；M 多步 | M 单步 | S；Debug |
| `systematic-debugging` | Debug 必用 | M/L 中遇到失败 | 正常新增功能 |
| `verification-before-completion` | 所有声称“完成/构建通过/修复”前 | - | 无 |
| `test-driven-development` | `pkgs/`、`tools/` 可测改动 | 增加 Nix 测试时 | 纯 NixOS 配置/模块（配置例外） |
| `using-git-worktrees` | 本地多特性并行 | 单特性 | ml-builder/部署机 |
| `dispatching-parallel-agents` | 多个独立链路同时异常 | 独立审计 | 共享状态/同一链路 |
| `subagent-driven-development` / `executing-plans` | 用户已确认 plan 后 | - | 未确认；apply 前无确认 |
| `requesting-code-review` / `receiving-code-review` | L、上游对齐审计 | M 收尾 | S 文档/机械改动 |
| `finishing-a-development-branch` | 大任务收尾 | M | 未完成/未验证 |
| `writing-skills` | 需要项目专属 skill | - | 能用审计命令/文档解决时 |

## 4. 冲突裁决

| 冲突 | 风险 | 裁决 |
| --- | --- | --- |
| `using-superpowers` 要求任何响应前启用 skill | 简单任务被流程化 | 先按第 2 节分级再路由；S 类直接做并说明 |
| `brainstorming` HARD-GATE 覆盖所有项目 | 简单改动被迫写 spec | 只用于 M（有取舍）和 L |
| TDD 铁律 | NixOS 配置无测试位 | 配置/模块改动用 `nix flake check` / `make build` 验证；TDD 限可测代码 |
| `using-git-worktrees` vs 部署机 `git pull --ff-only` | 部署机状态混乱 | worktree 只在本机；ml-builder 保持普通 checkout |
| `subagent-driven-development` 连续执行 | 未确认就部署 | 用户确认计划后才执行；`apply` 前再次确认，构建只 ml-builder |
| `finishing-a-development-branch` / `yeet` 默认 merge/PR | 偏离仓库 push master 流程 | 默认 commit + push origin + ml-builder；PR 仅当用户明确要求 |
| `dispatching-parallel-agents` | 并行改共享状态 | 只用于跨主机/跨链路独立排障；否则串行 |
| GitHub/`yeet` 分支规范 | 与仓库 master 流程不同 | 正常流程不建分支；用户要求 PR 时才用 |
| 多个 skill 同时匹配 | 流程叠加 | 优先级：用户指令 > AGENTS.md/work-norms > 本文件 > skill 默认行为；Debug 优先于 brainstorming |

## 5. 强制要求

1. 开始任务前读本文件和对应规范章节，先分级。
2. L 类任务必须出方案并得到用户确认；M 类涉及取舍先给影响面。
3. 故障修复必须 `systematic-debugging`，以日志/指标/数据流转为证据。
4. 声称完成前必须跑验证（`make build`、`nix flake check`、审计命令、实际链路验证等），并引用输出。
5. 构建只在 ml-builder；不并发压 opi5p；部署前先 build，apply 前确认主机范围。
6. 每次改动完成立即提交，提交后按 `work-norms.md` 对齐三方。
7. 新增/安装 skill 前用 `skill-installer` 阅读 SKILL.md，并用本文第 4 节做冲突检查；新建项目级 skill 用 `writing-skills`，且先证明无法用审计命令/文档覆盖。

## 6. 暂不推荐安装

| 类别 | 原因 |
| --- | --- |
| `figma/*`、`notion/*`、`linear`、`sentry`、`playwright`、`screenshot`、`pdf`、`speech`、`transcribe`、`jupyter-notebook`、`winui-app`、`aspnet-core`、`chatgpt-apps`、`render-deploy`、`vercel-deploy`、`netlify-deploy`、`cloudflare-deploy`、`migrate-to-codex`、`cli-creator` 等应用类 skill | 与 NixOS 基础设施运维无关，装进来只会增加误触发和流程噪音 |
| `security-best-practices` / `security-ownership-map` / `security-threat-model` | 仓库已有 `minimal-policies`、`service-harden` 等约束；只在专门安全审计时按需安装/启用 |
| `define-goal` | 当前 `/goal` 与目标工具已覆盖，不需要额外 skill |

## 7. 开始任务前检查清单

```text
[ ] 读 AGENTS.md、work-norms 和本文档对应章节
[ ] 分级 S / M / L / Debug / CI-GitHub / Skill 治理
[ ] 命中 L：先出方案并等用户确认
[ ] 命中 Debug：先做根因调查，再提修复
[ ] 完成前跑验证并引用输出
[ ] 提交并完成三方对齐
```
