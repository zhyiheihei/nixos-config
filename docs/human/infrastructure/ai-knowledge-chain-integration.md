# AI 链 ↔ 知识链整合

> 状态：2026-08-12 规划确认后开始实施；**2026-10-12 更新**——AI 链的汇聚点从
> uni-api 换成 CLIProxyAPI（公开入口仍是 `ai-api.zhyi.xin`），metapi 与 uni-api 已
> 随上游退役。链路细节以 [`../../agent/ai-api-gateway-chain.md`](../../agent/ai-api-gateway-chain.md)
> 为准，本文保留关系模型与集成候选。本文记录 AI 链与知识链的关系模型、官方 API
> 接入点、集成候选、红线与验收方式；不保存任何 API key、口令或会话令牌。配置最终来源
> 仍是 `hosts/`、`nixos/` 与私有 `nixos-secrets`。

## 结论

- **AI 链是推理与编排面**：CLIProxyAPI（`ai-api.zhyi.xin`，跑在 `google`）是唯一
  Provider 汇聚点，LibreChat、n8n、Memos、PicoClaw、pi 都从它取模型。
- **知识链是记忆与输入面**：`Notes -> Gitea` 是私有权威，Syncthing 负责三机分发；
  Blog/pyison 公开索引已于 2026-08-15 退役；RSS、ArchiveBox、Memos 是持续输入源。
- **两条链通过官方 API 连接**：知识服务用 Gitea/Memos/Miniflux/Syncthing 官方 API
  暴露读写，AI 链用 `ai-api.zhyi.xin` 的 OpenAI 兼容 `/v1` 提供推理，n8n 充当自动化中枢，
  LibreChat 与本地 AI 客户端通过 MCP/官方 REST 消费知识。
- **模型选择**：AI 链内统一使用 OpenCode Go 的 DeepSeek V4 Flash，网关侧精确别名
  `deepseek-v4-flash:opencode-go`（2026-08-12 实机核验）；工具脚本默认该别名并
  允许通过 `AI_MODEL` 覆盖。

## 关系模型

```mermaid
flowchart LR
  User[用户] -->|Dex OIDC| LibreChat[LibreChat greencloud]
  User -->|Dex OAuth| N8N[n8n greencloud]
  User --> Memos[Memos opi5p]
  LibreChat -->|OpenAI v1| AIAPI[CLIProxyAPI google<br/>ai-api.zhyi.xin]
  Memos -->|OpenAI v1| AIAPI
  N8N -->|OpenAI v1| AIAPI
  AIAPI -->|公开 vhost| Bridge[n8n OpenAI Bridge]
  Bridge -->|n8n API| N8N
  AIAPI --> Providers[外部 Provider<br/>zhipu-coding / opencode-go / linuxdo-hub / ollama-cloud]
  AIAPI --> Codex[Codex 订阅 OAuth]
  Notes[Notes 写作] -->|git push| Gitea[Gitea git.zhyi.xin]
  Notes -->|Syncthing| Copies[三机副本]
  Gitea -->|官方 REST| N8N
  RSS[RSSHub / Miniflux] -->|官方 API| N8N
  Archive[ArchiveBox] -->|CLI/Web API| N8N
  N8N -->|OpenAI 兼容| UniRock
  N8N -->|官方 API 写回| Memos
  LibreChat -->|MCP / 官方 REST| Gitea
  LocalAI[本地 AI 客户端] -->|MCP / 官方 REST| Gitea
  LocalAI -->|MCP / 官方 REST| Memos
```

## 服务与官方 API 清单

| 服务 | 主机 | 状态 | 官方 API / 协议 | 认证 | 文档 |
| --- | --- | --- | --- | --- | --- |
| CLIProxyAPI | `google` | 运行（2026-10-12 起，取代 uni-api） | OpenAI 兼容 `/v1`（`/v1/models`、`/v1/chat/completions`）；公开入口 `ai-api.zhyi.xin` | Bearer `ai-api.yaml` 的 `ai-api-key` | `https://github.com/router-for-me/CLIProxyAPI` |
| LibreChat | `greencloud` | 运行 | Web/客户端 REST `/api/*`；自定义 endpoint 指向 `ai-api.zhyi.xin` | Dex OIDC + 会话/JWT | `https://www.librechat.ai/docs` |
| n8n | `greencloud` | 运行 | REST `/api/v1`（workflows/executions/credentials）、webhooks | API key / Dex OAuth | `https://docs.n8n.io/api/` |
| n8n OpenAI Bridge | `greencloud` | 运行 | OpenAI 兼容 `/v1/*`、`/health` | Bearer token | `https://github.com/xddxdd/n8n-openai-bridge` |
| Metapi | — | 已退役（2026-10-12 随上游移除） | — | — | `https://github.com/cita-777/metapi`（仅存档） |
| AxonHub | 未部署 | 未部署 | 未部署；模块保留 | 未部署 | `https://github.com/looplj/axonhub` |
| Qdrant | 未部署 | 未部署 | REST 6333 / gRPC 6334（`/collections`、`/points`、`/search`） | 可选 API Key | `https://api.qdrant.tech/api-reference/` |
| Gitea | `greencloud` | 运行 | REST `/api/v1`（`/repos/{owner}/{repo}/...`）、Git/SSH 2222、webhook | API Token / OAuth2 / Basic | `https://docs.gitea.com/development/api-usage` |
| Syncthing | 三机 | 运行 | REST `/rest/*`（`/rest/events`、`/rest/db/status` 等） | `X-API-Key` | `https://docs.syncthing.net/dev/rest.html` |
| Miniflux | `greencloud` | 运行 | REST `/v1`（`/v1/me`、`/v1/feeds`、`/v1/entries`） | `X-Auth-Token` | `https://miniflux.app/docs/api.html` |
| RSSHub | `greencloud` | 运行 | HTTP 路由 + `?format=json` | private vhost | `https://docs.rsshub.app/` |
| ArchiveBox | `opi5p` | 运行 | CLI（`archivebox add/list/export`）、Web UI；JSON API 端点待核验 | Dex OAuth / 容器 CLI | `https://docs.archivebox.io/dev/` |
| Memos | `opi5p` | 运行 | REST `/api/v1/memos`、Connect `/memos.api.v1.*` | Personal Access Token | `https://github.com/usememos/memos`（`proto/gen/openapi.yaml`） |
| Dex | `volcengine` | 运行 | OIDC：`/auth`、`/token`、`/userinfo`、`.well-known/openid-configuration` | OIDC client secret | `https://dexidp.io/docs/` |

## 集成候选矩阵

| # | 候选 | 官方 API 组合 | 动作 / 价值 | 风险 | 优先级 |
| --- | --- | --- | --- | --- | --- |
| C1 | n8n 知识检索工作流 | Gitea REST + `ai-api.zhyi.xin/v1` | 拉取 `zhyi/notes`，让 AI 客户端问答私有笔记 | 工作流超时；PAT 权限需最小化 | P1 |
| C2 | LibreChat 知识源 | Gitea REST / 官方 MCP | 聊天界面内搜索/读取笔记 | 社区 MCP 无官方保证；需独立模块注入，不改公共 `mcp-servers.nix` | P1 |
| C3 | Syncthing 事件驱动 | Syncthing `/rest/events`、`/rest/db/status` | Notes 变更触发重索引或 AI 摘要 | 事件轮询延迟；API key 管理 | P1 |
| C4 | Blog/docs 全文检索 | 重建方案待定（pyison 已退役，2026-08-15） | 轻量检索 Blog/docs | API 未文档化；索引新鲜度依赖重建 | P2 |
| C5 | Memos 读写集成 | Memos `/api/v1/memos` + Connect API | 检索/创建/归档 memo，知识闭环 | PAT 范围；greencloud→opi5p 走 LTNET | P2 |
| C6 | Qdrant 向量 RAG | Qdrant REST + embeddings 端点 | Notes/Memos 语义检索 | 未部署；端口未登记；需先核验 embeddings | P2 |
| C7 | Gitea Actions 索引 | Gitea webhook / Actions | push 即触发重索引 | runner 资源；凭据写入 Notes 仓库需谨慎 | P2 |
| C8 | 本地 AI 客户端 | filesystem / Gitea MCP | 编码代理读写 Notes | AI 写权限；ml-2700 不可达期间无法验证 | P2 |
| C9 | Memos AI（现状） | OpenAI 兼容 `/v1` | 直连 `ai-api.zhyi.xin`，不做回环 | 默认不动 | P0 排除项 |
| C10 | AxonHub 接知识链 | — | 不建议：管理网关只做模型路由 | 回环面扩大、凭据重复 | 排除 |

## 红线

- `ai-api.zhyi.xin`（CLIProxyAPI）是唯一 Provider 汇聚点；禁止把
  `ai-api.zhyi.xin` 自身或 `axonhub.*` 反向配成它的渠道；禁止 AxonHub 指向自身。
- 不修改公共模块：`flake-modules/`、公共 `nixos/` 模块（含 `nixos/optional-apps/*.nix`
  与 `nixos/client-apps/mcp-servers.nix`）不擅自修改；新能力用主机级编排或新建独立
  模块（`options.lantian.<name>` + `mkIf cfg.enable`）。
- 不直接改任何数据库：LibreChat MongoDB、n8n/AxonHub PostgreSQL、Gitea MySQL、
  Memos 的 SQLite 与 CLIProxyAPI 的 Codex 登录态均为运行态；配置走官方 API/UI/CLI，新服务用独立数据文件。
- 凭据只进 SOPS secrets，不写进仓库正文、Notes 或文档。
- Notes 与 nixos-config 是两个独立 git 仓库，不混用、不放符号链接或 `.git` 指向。
- Qdrant 未启用；若启用必须先规范为 options 门闩模块、核验 `hsnw_index` 疑点、
  登记端口 6333/6334，并确认有可用的 embedding 端点。

## 分阶段实施

### P0 文档基线（已确认）

- 本文件作为 AI 链 ↔ 知识链整合的权威入口。
- 同步更新 `../../agent/ai-api-gateway-chain.md`、`../../agent/fleet-service-chain.md`、知识链文档、
  `memos.md`、`rss-chain.md`、`inspection-playbook.md`。
- 明确 Qdrant/AxonHub 的“未部署/暂停”状态与 OpenRouter 红线。

### P1 最小闭环（优先）

1. `Gitea API 拉 Notes -> ai-api 摘要 -> Memos 官方 API 写回/整理`；工具脚本见
   [`tools/knowledge-chain/notes-digest.sh`](../../../tools/knowledge-chain/notes-digest.sh)。
2. n8n 定时工作流：Miniflux 未读摘要 + Memos 收件箱整理，全部走
   `ai-api.zhyi.xin`。
3. LibreChat 只读知识源：独立模块注入 Gitea/Memos 官方 REST，不改公共 MCP 模块。
4. Syncthing REST 事件驱动重索引：先验证 API key 通道，再接入 n8n。

P1 运行态前置：`/run/secrets/gitea-ai-token`、`/run/secrets/memos-ai-token`、
`/run/secrets/miniflux-api-key`、`/run/secrets/syncthing-api-key` 是目标挂载路径。
它们当前尚未在私有 `nixos-secrets` 与主机级 SOPS 配置中创建；为避免修改公共模块，
运行前需在 secrets 仓库新增对应密钥，并通过 `hosts/<host>/` 层声明挂载，不写入
`nixos/` 公共模块。

### P2 条件项

- Qdrant 向量 RAG：先核验 embedding 端点与端口登记，以独立规范模块试点。
- ArchiveBox 自动化、Gitea Actions 索引。
- 公开天线恢复时：需重新评估 pyison/Waline 部署方式（已于 2026-08-15 退役）。

## 验收命令

以下命令只验证，不打印密钥；在对应主机以 root/授权账号执行。

```bash
# Gitea 官方 API 读取 Notes 仓库（greencloud 或可访问主机）
curl -fsS \
  -H "Authorization: token $(cat /run/secrets/gitea-ai-token)" \
  https://git.zhyi.xin/api/v1/repos/zhyi/notes

# 模型列表（ai-api.zhyi.xin）
curl -fsS \
  -H "Authorization: Bearer $(cat /run/secrets/ai-api-key)" \
  https://ai-api.zhyi.xin/v1/models | jq '(.data // []) | length'

# n8n OpenAI Bridge 健康检查（greencloud）
curl -fsS http://127.0.0.1:13333/health

# Memos 官方 API 读取（opi5p）
curl -fsS \
  -H "Authorization: Bearer $(cat /run/secrets/memos-ai-token)" \
  http://127.0.0.1:13819/api/v1/memos | jq '.memos | length'

# Miniflux 官方 API（greencloud；需先验证 X-Auth-Token 是否可穿透 Dex OAuth vhost）
curl -fsS \
  -H "X-Auth-Token: $(cat /run/secrets/miniflux-api-key)" \
  https://rss.zhyi.xin/v1/me

# Syncthing 官方 REST（对应主机）
curl -fsS \
  -H "X-API-Key: $(cat /run/secrets/syncthing-api-key)" \
  http://127.0.0.1:13834/rest/db/status?folder=notes | jq '{state,needBytes,errors}'
```

## 未验证点

- 官方文档 URL 已在本文件核对；部分端点（ArchiveBox JSON API、pyison 搜索接口
  已随退役移除、Miniflux/Syncthing API key 穿透 OAuth vhost 的能力）需实施期实机验证。
- 各消费方主机上 `ai-api.zhyi.xin` 的可达性与本地 AI 客户端运行态需按主机核验。
- 网关侧的 `deepseek-v4-flash:opencode-go` 模型别名已于 2026-08-12 在
  `greencloud` 通过 `/v1/models` 实机核验存在。

## 实机核验记录（2026-08-12）

- `ai-api.zhyi.xin/v1/models` 可见 `deepseek-v4-flash:opencode-go` 与
  `deepseek-v4-flash` 等别名；OpenCode Go 供应商密钥已挂载为
  `opencode-go-api-key`（secrets `llm-providers/opencode-go-api-key.yaml`）。
- Gitea `https://git.zhyi.xin/api/v1/version` 返回 `1.27.1`。
- n8n OpenAI Bridge `http://127.0.0.1:13333/health` 返回
  `{"status":"ok",...}`。
- Syncthing `notes` 文件夹 `/rest/db/status?folder=notes` 为
  `state=idle`、`needBytes=0`、`errors=0`。
- Memos `GET /api/v1/memos`（公开可见 memo）可访问；写回仍需 PAT。
