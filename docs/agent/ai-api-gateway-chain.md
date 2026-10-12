# AI API 网关链路

本文记录当前 AI 服务的职责、数据边界、初始化状态与维护规则。配置的最终来源仍是
`hosts/`、`nixos/` 和私有 `nixos-secrets`；本文不保存任何 API key、口令、会话
令牌或 Provider 凭据。

## 设计边界

`CLIProxyAPI` 是唯一的 Provider 汇聚点，也是公开入口 `ai-api.zhyi.xin` 的后端
（2026-10-12 起；上游 `f8be2aefe` 退役 uni-api/metapi，由 CLIProxyAPI 接管，
本仓跟随）。外部 Provider 的 URL、密钥与模型清单只由私有 secrets 仓库的
`llm-providers/` 定义，在主仓由 `hosts/google/cliproxyapi.nix` 生成网关的
`openai-compatibility` 段落（密钥用 sops 占位符注入，明文不进 store）。

```text
外部 Provider（zhipu-coding / opencode-go / opencode-go-2 / linuxdo-hub / ollama-cloud）
    ^
    |  base-url、密钥、模型清单（私有 secrets/llm-providers）
    |
CLIProxyAPI（google，容器，127.0.0.1:${LT.portStr.CLIProxyAPI}）
    ^                     ^                     ^
    |                     |                     |
ai-api.zhyi.xin      cliproxyapi.zhyi.xin   Codex 订阅（OAuth 登录，auth 目录）
（公开，key 鉴权）    （private，管理界面）
    ^
    |
LibreChat / n8n OpenAI Bridge / PicoClaw / Memos / pi 客户端
```

Codex 订阅部分不来自 `llm-providers`：它由容器 auth 目录里的 OAuth 登录
（设备码流程，登录后在 `cliproxyapi.zhyi.xin` 的管理界面完成）提供，模型形如
`gpt-5.6-luna`。两条来源在 `/v1/models` 上合并展示。

`AxonHub`、`Qdrant` 模块仍保留在仓库，但没有被任何 host 导入，不属于当前运行链路。

## 渠道与模型清单

- 渠道按 `llm-providers` 的 `_score` 升序排列，`openai-compatibility` 的顺序即
  生成顺序；额度耗尽的渠道由上游自身的冷却机制处理。
- CLIProxyAPI **不做模型自动发现**：每个渠道的模型清单必须显式给出，取自
  `llm-providers/apis/*.json`（`modelJsonFile`）或 provider 内的 `_models`。
  上游渠道新增模型时，重新抓取该渠道的 `/v1/models` 覆盖对应 JSON。
  当前清单：zhipu-coding 11、opencode-go 38、opencode-go-2 38、linuxdo-hub 19、
  ollama-cloud 18，合计 124 个模型（2026-10-12 实机核验）。
- 生成 `openai-compatibility` 时必须排除 `cliproxyapi` 自身渠道——它就是本端点，
  写进去会形成请求回环。`llm-providers/providers/cliproxyapi.nix` 的存在只是给
  LibreChat 的模型清单用。
- 各消费方的 key 统一是 `ai-api.yaml` 的 `ai-api-key`（`llm-providers` 里的
  渠道密钥是给网关出站用的，与消费方 key 不同）。

## 服务职责与位置

| 服务 | 主机 | 作用 | 上游或依赖 |
| --- | --- | --- | --- |
| CLIProxyAPI | `google`（唯一） | Provider 汇聚与 OpenAI 兼容 API；公开入口 `ai-api.zhyi.xin`，管理入口 `cliproxyapi.zhyi.xin`（private） | 私有 `llm-providers/` secrets；`common/cliproxyapi.yaml` 的网关密钥 |
| LibreChat | `greencloud` | 交互式 AI 前端，使用 Dex OIDC 登录 | `ai-api.zhyi.xin`（`services.librechat.settings.endpoints.custom` 主机级覆盖），key 取 `ai-api.yaml` |
| n8n | `greencloud` | 自动化工作流 | PostgreSQL；工作流可调用 Bridge |
| n8n OpenAI Bridge | `greencloud` | 把标记为 `n8n-openai-bridge` 的工作流作为模型暴露 | n8n API；`ai-api-key` |
| PicoClaw | `dragon-q8b` | 个人助理网关（本地 127.0.0.1:18790） | `ai-api.zhyi.xin`，key 取 `ai-api.yaml` |
| pi | `ml-laptop` | 本地 coding agent | 官方插件 `@router-for-me/pi-cliproxyapi-provider` 连 `ai-api.zhyi.xin` |
| AxonHub / Qdrant | 未部署 | 仓库保留可选模块，无 host import 或运行 unit | 部署前需重新确认上游契约 |
| uni-api / metapi | 已退役 | 2026-10-12 随上游移除，职责由 CLIProxyAPI 接管 | — |

核心实现位置：

- [`nixos/optional-apps/cliproxyapi.nix`](../../nixos/optional-apps/cliproxyapi.nix)（容器与 vhost）
- [`hosts/google/cliproxyapi.nix`](../../hosts/google/cliproxyapi.nix)（配置渲染与渠道生成）
- [`nixos/optional-apps/librechat.nix`](../../nixos/optional-apps/librechat.nix)
- [`nixos/optional-apps/n8n/n8n-openai-bridge.nix`](../../nixos/optional-apps/n8n/n8n-openai-bridge.nix)
- [`home/client-apps/pi/default.nix`](../../home/client-apps/pi/default.nix)
- [`hosts/greencloud/configuration.nix`](../../hosts/greencloud/configuration.nix)

## 与知识链的连接

AI 链与知识链通过各服务官方 API 连接，禁止用“共享数据库”或“直接改运行态 DB”
代替 API。完整关系模型与候选矩阵见
[`../human/infrastructure/ai-knowledge-chain-integration.md`](../human/infrastructure/ai-knowledge-chain-integration.md)。

当前已确认的合法连接：

- LibreChat 只读知识源：只能通过官方 REST/MCP 接 Gitea、Memos、Miniflux；
  新增 MCP 用主机级编排或独立模块注入，不修改公共 `mcp-servers.nix`。
- n8n 自动化：工作流的 AI 调用走公开入口 **`https://ai-api.zhyi.xin/v1`**
  （全消费者统一走 ai-api）。Gitea/Memos/Miniflux/Syncthing 均走官方 API。n8n OpenAI Bridge 的
  方向是“工作流作为模型被网关调用”；n8n 通过 ai-api 调用普通 Provider 模型
  没问题，但**禁止调用会绕回自己 Bridge 的模型**（网关 → Bridge → n8n 即成回环）。
- Memos AI：走 `ai-api.zhyi.xin`，key 取 `ai-api.yaml`；Memos 读写集成走
  `/api/v1/memos` 与 `/memos.api.v1.*`，PAT 进 SOPS。
- Syncthing：事件/状态查询走 `/rest/events`、`/rest/db/status`，API key 进
  SOPS；公网 vhost 前的 OAuth 是否放行 API key 需实机验证，必要时走
  `127.0.0.1` 通道。

## LibreChat 的 MCP 接入

`greencloud` 的 LibreChat 通过主机级/隐藏模块（`nixos-secrets` 的
`nixos-hidden-module/<hash>`）注入 MCP 服务器：`home-assistant`（stdio，脚本内
`cat` 出 sops secret 当环境变量）与 `moviepilot`（streamable-http）。

MoviePilot 侧走的是 **v3 自带的 MCP 服务** `https://moviepilot.rock5c.zhyi.xin/api/v1/mcp`
（`X-API-KEY` 或 `?apikey=` 认证，token 存在 `common/moviepilot.yaml`）。此前用的
PyPI 包 `moviepilot-mcp` 只实现 v1 接口（媒体详情用 `tmdb:123` 且不带 `media_source`），
对 v3 一律 422，工具每次调用都失败，模型会反复重试到
LangGraph `recursion limit of 50` 报错——遇到这个报错先查是不是某个 MCP 工具在持续失败。

两个容易踩的坑：

- `librechat.yaml` 的 `mcpServers.<name>.headers` 值**不会**在启动阶段展开 `${VAR}`
  （`processMCPEnv` 的展开只在连接期跑，启动期探测拿不到），于是本地 MCP 会 401、
  被误判成需要 OAuth（日志 `OAuth Required: true`）。`url` 字段在配置加载时就会展开，
  所以 token 放到 `?apikey=${VAR}` 上，并显式 `requiresOAuth = false`。
- `moviepilot.rock5c.zhyi.xin` 在舰队内解析到 LTNET ULA，LibreChat 的 MCP SSRF
  保护默认拒绝私网地址，需要在 `mcpSettings.allowedAddresses` 里按 `host:port` 放行。

同一个隐藏模块还给「影视助手」挂了 MoviePilot 自带的 skill：MoviePilot v3 仓库的
README 的 `## Agent` 一节说明其它智能体导入其 `skills/` 目录即可获得操作能力，
因此用 `fetchFromGitHub` 按 rev 固定后通过 `DEPLOYMENT_SKILLS_DIR` 挂成只读的
部署型 skill（文章本节所说的“部署型 skill”）。两个必须知道的约束：

- **Skills 只在 agents 端点上生效**：skill catalog 注入、`$` 手动调用、
  always-apply 与 skill 工具的解析全在 agents 链路（`packages/api/src/agents/skills.ts`、
  `api/server/controllers/agents/*`），自定义端点只把
  `manualSkills` 当界面元数据存一下。所以影视助手的 preset 端点从自定义端点改成了
  `agents`（模型仍是 ai-api 提供的 `deepseek-v4.1-flash`）。
- **frontmatter 严格校验**：部署型 skill 的 frontmatter 只允许白名单键
  （name/description/allowed-tools/version/…），出现 `authors`、`credentials`、
  `allowed-api-operations` 这类未识别键或数字型 `version` 会**直接让服务拒绝启动**。
  上游 skills/ 三者都有，因此在构建期用 `librechat-skills/normalize-skill-frontmatter.py`
  归一化（re-export secrets 时该目录一起进 store）。升级 MoviePilot skills 时
  只改 rev + hash。

## 官方 API 出处

| 服务 | 官方文档 |
| --- | --- |
| CLIProxyAPI | `https://github.com/router-for-me/CLIProxyAPI` |
| LibreChat | `https://www.librechat.ai/docs` |
| n8n | `https://docs.n8n.io/api/` |
| n8n OpenAI Bridge | `https://github.com/xddxdd/n8n-openai-bridge` |
| pi 的 CLIProxyAPI 插件 | `https://www.npmjs.com/package/@router-for-me/pi-cliproxyapi-provider` |
| AxonHub | `https://github.com/looplj/axonhub` |
| Qdrant | `https://api.qdrant.tech/api-reference/` |
| Gitea | `https://docs.gitea.com/development/api-usage` |
| Syncthing | `https://docs.syncthing.net/dev/rest.html` |
| Miniflux | `https://miniflux.app/docs/api.html` |
| ArchiveBox | `https://docs.archivebox.io/dev/` |
| Memos | `https://github.com/usememos/memos`（`proto/gen/openapi.yaml`） |

## Secrets 与密钥边界

| 位置 | 用途 | 规则 |
| --- | --- | --- |
| `ai-api.yaml` 的 `ai-api-key` | 消费方（LibreChat、n8n Bridge、PicoClaw、Memos、pi）访问 `ai-api.zhyi.xin` | 不输出、不提交明文；轮换时同步更新各消费方（Nix 侧只引用 sops 路径，无需改代码） |
| `common/cliproxyapi.yaml` | 网关自身的 `management-key` 与 4 个 `api-key-*`（`ai-api-key` 取的是 `api-key-1`） | 只在私有 secrets 仓库按 SOPS 规范维护 |
| `llm-providers/providers/` 与 `llm-providers/apis/` | 外部 Provider URL、API key 与模型清单 | 同上；密钥由主仓生成 `openai-compatibility` 时以 sops 占位符注入 |
| `librechat.yaml` 与 `common/dex.yaml` | LibreChat 会话、JWT、凭据加密与 OIDC client secret | 只通过 SOPS secret 文件注入 |
| `common/moviepilot.yaml` 的 `moviepilot-api-token` | LibreChat 接 MoviePilot v3 MCP | 只通过 SOPS 注入 LibreChat 进程环境，不写进 librechat.yaml |
| `n8n.yaml` | n8n runner/API 认证 | Bridge 只读取其所需的 token，不能输出或复制到普通配置 |

轮换 `ai-api-key`（消费方 key）的正确顺序：

1. 在私有 secrets 仓库按其 SOPS 文档加密更新 `ai-api.yaml`；如果同时换网关侧的
   `api-key-1`，两者保持一致。
2. 部署 `google`（网关）与各消费方主机（`greencloud`、`dragon-q8b`、`ml-laptop`）。
3. 用下面的健康检查确认模型列表可认证；任一消费方取到 401 说明该主机没部署到。

## 维护规则

- **不要改主调用路径。** 消费方统一走 `https://ai-api.zhyi.xin/v1`，后端即
  `google` 上的 CLIProxyAPI；不得改指 AxonHub 或其他网关，除非明确迁移整个调用契约
  并单独验证。
- **不要制造回环。** 禁止把 `cliproxyapi` 自身或 `ai-api.zhyi.xin` 配成
  `openai-compatibility` 的渠道（主仓生成时已显式排除）。
- **不重复保存外部 Provider 凭据。** 新增外部 Provider 时只更新
  `llm-providers/`，不要往别处塞。
- **保留私有访问边界。** `cliproxyapi.zhyi.xin` 是管理入口，保持 private；
  公开 API 入口只由 `ai-api.zhyi.xin` 承担。
- **模型清单要跟着上游走。** 清单是静态烘焙的，渠道换模型后必须重新抓取
  `apis/*.json` 并部署 `google`，否则新模型不会出现在 `/v1/models`。
- **不把运行态当 Nix 声明。** Nix 负责容器、配置渲染与 secret 文件挂载；Codex
  订阅的 OAuth 登录态在 `/var/lib/cliproxyapi/auth`，属运行态，不进 Nix。

## 健康检查

以下命令在 `google` 以 root 执行；只验证，不打印密钥：

```bash
systemctl is-active podman-cliproxyapi

# 网关自身：应列出全部渠道模型 + Codex 订阅模型
K=$(sed -n 's/^ *- "\(.*\)"$/\1/p' /var/lib/cliproxyapi/config.yaml | head -1)
curl -fsS -H "Authorization: Bearer $K" http://127.0.0.1:${LT.portStr.CLIProxyAPI}/v1/models \
  | jq '(.data // []) | length'

# 管理 API：确认 openai-compatibility 已渲染出各渠道
M=$(sed -n 's/.*secret-key: "\(.*\)"/\1/p' /var/lib/cliproxyapi/config.yaml)
curl -fsS -H "X-Management-Key: $M" \
  http://127.0.0.1:${LT.portStr.CLIProxyAPI}/v0/management/openai-compatibility \
  | jq '[. ["openai-compatibility"][] | {name, models: (.models | length)}]'
```

预期容器 `active`，`/v1/models` 数量 ≥ 124（渠道模型）并包含 Codex 订阅模型，
管理 API 列出 5 个渠道。数量变少时先看容器日志与 sops 渲染结果：

```bash
journalctl -u podman-cliproxyapi --since '30 minutes ago' --no-pager
cat /var/lib/cliproxyapi/config.yaml | head -5   # 只确认渲染成功，不要外传
test -s /run/secrets/cliproxyapi-management-key
```

消费方侧（任一台）验证：

```bash
curl -fsS -H "Authorization: Bearer $(cat /run/secrets/ai-api-key)" \
  https://ai-api.zhyi.xin/v1/models | jq '(.data // []) | length'
```

## 部署注意

- **auth 目录**：本仓旧的原生单元用 `/var/lib/cliproxyapi/auths`，上游容器模块挂载
  `/var/lib/cliproxyapi/auth`。首次部署容器版前必须在 `google` 上
  `mv /var/lib/cliproxyapi/auths /var/lib/cliproxyapi/auth`，否则 Codex 登录态丢失，
  订阅模型全部消失（表现为 `/v1/models` 只剩渠道模型）。
- **模型清单更新**：改 `llm-providers/apis/*.json` 后要 bump secrets 输入并部署
  `google`；`sops.templates` 的 `restartUnits` 会在配置变化时重启容器。
