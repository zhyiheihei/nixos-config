# 上游对齐交接（2026-08-24，本轮聚焦四块）

上游 `upstream`（xddxdd/nixos-config）master=0df3a2a4，fork master=2031a2aa，
merge-base=0a9340d0。本轮只做 ai-coding / audio-cpp / mihomo / flake-flatten
四块，不做包 bumps。用户决策：mihomo 采纳上游移除（但有前提，见下）；
内置六 agent 分工（scout→researcher→oracle→worker×N→reviewer→delegate）；
我是决策者。

> 本会话 token 预算用尽，scout 因 ollama-cloud 并发错误失败，下列分类由
> 决策者直接用 git 侦察得出，未经 scout/researcher/oracle 复核。下一会话
> 起步时应先派 reviewer 核验此表，再派 worker 落地。

## A/B 分类表

A=采纳上游（fork 落后，纯作者更新）；B=保留私有（采纳结构、保留 fork 锚点）。
fork 锚点：域名 zhyi.xin、用户 zhyi、主机名/IP、fork 端口（DSH=3080、
qBit=13830）、nixpkgs pin 624af665、secrets input、n8n hash 覆盖、ncps 动态 IP。

### ai-coding（上游 24 提交，触点文件）

| 文件 | fork 现状 | 上游 delta | 判定 | 说明 |
| --- | --- | --- | --- | --- |
| `home/client-apps/ai-coding/rules/04-nixos.md` | 工作区未提交 +5/-5 | 592cd30c/2f01c5f6 加宽 root/nix-store 禁令 | A | 已在工作区逐字采纳，worker 只需 commit |
| `home/client-apps/ai-coding/rules/05-writing-style.md` | present | c916ebb1 新增 | A | 已采纳，确认与上游一致 |
| `home/client-apps/ai-coding/extensions/model-favorites.ts` | present | c026521b 新增 435 行 | A | 已采纳，确认与上游一致 |
| `home/client-apps/ai-coding/extensions/no-update-check.ts` | present | 8f2f52f8 新增 | A | 已采纳，确认与上游一致 |
| `home/client-apps/ai-coding/extensions/nixos-command-guard.ts` | **MISSING** | 2f01c5f6 新增 + 592cd30c 加宽 | A | fork 缺文件，直接采纳上游版 |
| `home/client-apps/ai-coding/default.nix` | 私有重度定制 | 24 提交反复改（langfuse/tokenrhythm/MCP 开关/model 默认/subagent 并发/pi-lens/auto-retry…） | **B** | 采纳上游结构改动，保留 fork 的 provider/模型偏好/端点；需逐 hunk 比对，**最高风险文件** |

ai-coding 的 default.nix 是本块唯一 B 类，需 oracle 裁定每个 hunk 采纳/保留。
其余 ai-coding 文件 fork 已领先采纳或只需补 nixos-command-guard.ts。

### audio-cpp（上游 2e3d1e26）

| 文件 | fork 现状 | 判定 | 说明 |
| --- | --- | --- | --- |
| `nixos/optional-apps/audio-cpp.nix` | MISSING | A | 直接采纳上游新文件 |
| `flake.nix` / `flake.lock` | 私有 inputs | B | 与 flake-flatten 合并处理（见下） |
| `hosts/lt-hp-omen/configuration.nix` | fork 无此 host | 跳过 | 作者私有 host，fork 不对应 |

### mihomo（上游 520b4445）⚠️ blocker

上游移除 `nixos/server-apps/mihomo.nix`，并改 `AGENTS.md`、
`helpers/constants/ports.nix`、`nixos/optional-apps/dae.nix`。

**前提未满足**：用户「采纳移除」的前提是「fork 无主机实际依赖」。实测 fork 有：
- 引用 host：`hosts/tencent` `hosts/hostdare` `hosts/greencloud` `hosts/google`（4 台）
- 引用模块：`nixos/optional-apps/sublinkpro/default.nix`、`nixos/optional-apps/mihomo.nix`、`nixos/optional-apps/metacubexd.nix`

→ **不能直接删 mihomo.nix**。需先回到用户确认：这 4 台 host 是否还在用 mihomo
（是 cn-accel 路径还是遗留？）。若仍用则 mihomo 转为 fork 私有偏移保留，
本轮跳过 mihomo 移除；若已废弃则先清 4 host 引用再删模块。
fork 的 `dae.nix` 已 present，需比对上游 520b4445 对 dae 的改动是否纯逻辑可采纳。

### flake flatten（上游 26f1b406）

| 文件 | fork 现状 | 判定 | 说明 |
| --- | --- | --- | --- |
| `flake.nix` | 私有 inputs（secrets、nixpkgs pin 624af665 等多 fork-only input） | B | 采纳 flatten 结构，把 fork 私有 inputs 安置进扁平化布局；不可整文件覆盖 |
| `flake.lock` | 大量 fork 私有 pin | B | flatten 后需重新 `nix flake lock`，逐 input 核对，保留 fork pin |

## 下一步建议顺序

1. reviewer 核验本表（尤其 default.nix hunk 划分）。
2. 用户拍板 mihomo：4 host 是否仍用 → 决定本轮跳过还是清理后删。
3. worker-1 落地 A 类纯采纳：commit 工作区 `04-nixos.md`、补
   `nixos-command-guard.ts`、新增 `audio-cpp.nix`、核对 3 个已存在扩展/规则文件与上游逐字一致。
4. worker-2 处理 B 类 `ai-coding/default.nix`：逐 hunk（oracle 裁定）合并，保留 fork provider/模型/端点。
5. worker-3 处理 flake flatten：合并 `flake.nix` 结构 + 重新 lock，保留 fork 私有 inputs 与 pin；跑 `nix flake check`/build 验证。
6. reviewer 终检：私有锚点未被误删（域名/用户/端口/pin/n8n hash/ncps IP）。

## 已完成的 trivial 项

工作区未提交的 `home/client-apps/ai-coding/rules/04-nixos.md` +5/-5 即上游
592cd30c 的逐字采纳，可直接 commit（message 参考上游 "ai-coding: wider block
on operations on root or nix store"）。