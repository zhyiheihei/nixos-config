# AI API 网关链路

本文记录当前 AI 服务的职责、数据边界、初始化状态与维护规则。配置的最终来源仍是
`hosts/`、`nixos/` 和私有 `nixos-secrets`；本文不保存任何 API key、口令、会话
令牌或 Provider 凭据。

## 设计边界

`UniAPI` 是唯一的 Provider 汇聚点。外部 Provider 的 URL、密钥和模型映射只由私有
secrets 仓库的 `uni-api/` 导入。其他网关只能以本机 UniAPI 为上游，不能再反向作为
UniAPI 的 Provider，否则会形成请求循环、重复计费或无法诊断的失败。

```text
外部 Provider
    ^
    |  Provider key、模型映射（私有 secrets/uni-api）
    |
UniAPI
    ^                     ^
    |                     |
LibreChat / n8n          Metapi

AxonHub：模块保留，当前未部署
```

应用调用路径与管理网关是并列关系，不是需要逐层穿透的串联关系：

```text
LibreChat   ──────────────────────> hostdare UniAPI ─> Provider
Metapi      ──────────────────────> hostdare UniAPI ─> Provider
hostdare UniAPI ─> n8n OpenAI Bridge (greencloud) ─> n8n 工作流
```

自 2026-08-14 起，UniAPI 全项目收敛为**唯一一份**，运行在 `hostdare`（网络质量
较好）；公开入口为 `ai-api.zhyi.xin`（完全公开，key 鉴权，对应作者原版的
`ai-api.<domain>` 公开模式；原 `ai-api.zhyi.cc` 已移除）。LibreChat、n8n 和
n8n OpenAI Bridge 运行在 `greencloud`；Metapi 运行在 `tencent`（SQLite 状态从
greencloud 迁移）。LibreChat 与 Metapi 都使用 `https://ai-api.zhyi.xin/v1`。
UniAPI 通过 LTNET 回调 greencloud 上的 n8n Bridge
（`https://n8n-bridge.greencloud.zhyi.cc/v1`）。

`AxonHub` 模块仍保留在仓库，但当前没有被任何 host 导入，实机也没有
`axonhub.service`。它是未部署候选，不属于当前运行链路。

`Qdrant` 模块同样只保留在仓库（与作者原版一致），当前没有任何 host import；
它不是当前 AI 链的一部分，向量检索相关方案见
[`ai-knowledge-chain-integration.md`](./ai-knowledge-chain-integration.md)。

AI 链内统一使用 OpenCode Go 的 DeepSeek V4 Flash，UniAPI 上的精确模型别名为
`deepseek-v4-flash:opencode-go`（2026-08-12 实机 `/v1/models` 核验存在）。新增
工作流/脚本必须显式选择该模型或通过 `AI_MODEL` 注入，不能把其他厂商模型作为
默认值固化到新链路。

## 服务职责与位置

| 服务 | 主机 | 作用 | 上游或依赖 |
| --- | --- | --- | --- |
| UniAPI | `hostdare`（唯一） | Provider 注册表、模型别名与 OpenAI 兼容 API；公开入口 `ai-api.zhyi.xin` | 私有 `uni-api/` secrets |
| LibreChat | `greencloud` | 交互式 AI 前端，使用 Dex OIDC 登录 | `ai-api.zhyi.xin`（`services.librechat.settings.endpoints.custom` 主机级覆盖） |
| n8n | `greencloud` | 自动化工作流 | PostgreSQL；工作流可调用 Bridge |
| n8n OpenAI Bridge | `greencloud` | 把标记为 `n8n-openai-bridge` 的工作流作为模型暴露给 UniAPI | n8n API；UniAPI key |
| Metapi | `tencent` | 可选元聚合网关、站点/账户/模型路由管理；唯一站点指向 hostdare UniAPI | `ai-api.zhyi.xin`；SQLite 状态目录（自 greencloud 迁移） |
| AxonHub | 未部署 | 仓库保留可选模块，但当前没有 host import 或运行 unit | 部署前需重新确认 PostgreSQL、Redis 与上游契约 |
| Qdrant | 未部署 | 仓库保留模块，无 host import、无实机 unit | 若启用需先规范为独立 options 模块并核验 embeddings |

核心实现位置：

- [`nixos/optional-apps/uni-api.nix`](../../nixos/optional-apps/uni-api.nix)
- [`nixos/optional-apps/librechat.nix`](../../nixos/optional-apps/librechat.nix)
- [`nixos/optional-apps/n8n/n8n-openai-bridge.nix`](../../nixos/optional-apps/n8n/n8n-openai-bridge.nix)
- [`nixos/optional-apps/axonhub.nix`](../../nixos/optional-apps/axonhub.nix)
- [`nixos/optional-apps/metapi.nix`](../../nixos/optional-apps/metapi.nix)
- [`hosts/greencloud/configuration.nix`](../../hosts/greencloud/configuration.nix)
- [`hosts/rock5c/home-edge.nix`](../../hosts/rock5c/home-edge.nix)
- [`hosts/hostdare/configuration.nix`](../../hosts/hostdare/configuration.nix)

## 与知识链的连接

AI 链与知识链通过各服务官方 API 连接，禁止用“共享数据库”或“直接改运行态 DB”
代替 API。完整关系模型与候选矩阵见
[`ai-knowledge-chain-integration.md`](./ai-knowledge-chain-integration.md)。

当前已确认的合法连接：

- LibreChat 只读知识源：只能通过官方 REST/MCP 接 Gitea、Memos、Miniflux；
  新增 MCP 用主机级编排或独立模块注入，不修改公共 `mcp-servers.nix`。
- n8n 自动化：工作流只调 `ai-api.zhyi.xin`；Gitea/Memos/Miniflux/
  Syncthing 均走官方 API。n8n OpenAI Bridge 的方向是“工作流作为模型被 UniAPI
  调用”，不能反过来让 n8n 把 Metapi/AxonHub 当 Provider 上游。
- Memos AI：保持 Metapi → UniAPI 的既有路径；Memos 读写集成走
  `/api/v1/memos` 与 `/memos.api.v1.*`，PAT 进 SOPS。
- Syncthing：事件/状态查询走 `/rest/events`、`/rest/db/status`，API key 进
  SOPS；公网 vhost 前的 OAuth 是否放行 API key 需实机验证，必要时走
  `127.0.0.1` 通道。
- Waline（未启用）：若恢复公开路线，其 LLM 审核插件必须改指
  `ai-api.zhyi.xin`，不得直连 OpenRouter。

## 官方 API 出处

| 服务 | 官方文档 |
| --- | --- |
| UniAPI | `https://github.com/yym68686/uni-api` |
| LibreChat | `https://www.librechat.ai/docs` |
| n8n | `https://docs.n8n.io/api/` |
| n8n OpenAI Bridge | `https://github.com/xddxdd/n8n-openai-bridge` |
| Metapi | `https://github.com/cita-777/metapi` |
| AxonHub | `https://github.com/looplj/axonhub` |
| Qdrant | `https://api.qdrant.tech/api-reference/` |
| Gitea | `https://docs.gitea.com/development/api-usage` |
| Syncthing | `https://docs.syncthing.net/dev/rest.html` |
| Miniflux | `https://miniflux.app/docs/api.html` |
| ArchiveBox | `https://docs.archivebox.io/dev/` |
| Memos | `https://github.com/usememos/memos`（`proto/gen/openapi.yaml`） |

## 已完成的运行态初始化

作者公开的 Nix 模块只声明服务、数据库和反向代理；Metapi 的上游渠道、账户及路由
是应用数据库中的运行态数据，不能通过重新 `switch` 自动重建。AxonHub 若以后重新
部署，同样遵守这一边界。

当前已经完成以下初始化，记录日期为 2026-07-21：

- Metapi：有一个名为 `UniAPI` 的 `openai` 站点，指向
  `https://ai-api.zhyi.xin`；有一个对应的 API-key 账户；已执行官方的模型刷新与路由
  重建。
- 2026-07-21 的历史记录显示，当时 Metapi 与曾部署的 AxonHub 均识别到 `162` 个
  模型。该数字随 Provider 注册表改变，不是配置常量；AxonHub 当前已经不在运行链路。
- Metapi 的管理口令是 `default-pw`，其下游 `PROXY_TOKEN` 使用
  `uni-api-admin-api-key`。这是当前模块的作者式全局 secrets 约定。

不要删除可能保留的 AxonHub PostgreSQL/Redis 历史数据或 `/var/lib/metapi`（位于
greencloud，Metapi 迁移后作为备份保留；tencent 上的 `/var/lib/metapi` 是 2026-08-14
从 greencloud 拷贝的运行态），除非明确要废弃相应网关；否则会丢失运行态初始化和应用内管理数据。

## Secrets 与密钥边界

| 位置 | 用途 | 规则 |
| --- | --- | --- |
| `uni-api/keys.yaml` 的 `uni-api-admin-api-key` | UniAPI 管理 API；n8n Bridge 客户端；Metapi 下游代理；重新部署时的 AxonHub 上游访问 | 不输出、不提交明文；轮换时同步更新当前实际部署的应用内上游凭据 |
| `uni-api/providers/` 与 `uni-api/apis/` | 外部 Provider URL、API key 与模型映射 | 只在私有 secrets 仓库按 SOPS 规范维护 |
| `uni-api/` Provider 注册表 | LibreChat 模型列表与 UniAPI Provider 配置 | 与 UniAPI 配置一起维护 |
| `librechat.yaml` 与 `common/dex.yaml` | LibreChat 会话、JWT、凭据加密与 OIDC client secret | 只通过 SOPS secret 文件注入 |
| `n8n.yaml` | n8n runner/API 认证 | Bridge 只读取其所需的 token，不能输出或复制到普通配置 |

轮换 `uni-api-admin-api-key` 的正确顺序：

1. 在构建机的私有 secrets 仓库按其 SOPS 文档加密更新 key。
2. 部署 `rock5c` 与 `hostdare`，确认两台 UniAPI 的 `/v1/models` 均可认证；hostdare 不可达
   时不能假定轮换已经完成。
3. 在 Metapi 的 `UniAPI` API-key 账户中更新上游 key；只有重新部署 AxonHub 后才
   更新其 channel。
4. 重新刷新 Metapi 模型并重建路由，再做下面的健康检查。

不要为了轮换 key 直接编辑 AxonHub PostgreSQL 或 Metapi SQLite；使用各自的管理 UI 或
官方 API。

## 维护规则

- **不要改主调用路径。** LibreChat 的自定义 UniAPI endpoint 使用
  `https://ai-api.zhyi.xin/v1`，后端即 hostdare；n8n Bridge 作为 `lantian.llm-providers`
  的 `n8n` Provider 被 UniAPI 通过 `https://n8n-bridge.greencloud.zhyi.cc/v1` 调用。两者都
  不能改为 AxonHub 或 Metapi，除非明确迁移整个调用契约并单独验证。
- **不要制造回环。** 禁止将 `axonhub.*`、`metapi.*` 或 `ai-api.zhyi.xin` 配成 UniAPI
  的 Provider；禁止给 Metapi/AxonHub 再添加指向自身的上游。
- **不重复保存外部 Provider 凭据。** Metapi 当前只保存对 UniAPI 的凭据；
  AxonHub 若重新部署也只能这样配置。新增外部 Provider 时优先更新 `uni-api/`
  secrets，而不是分别塞入多个网关。
- **保留私有访问边界。** `metapi.tencent.zhyi.cc` 是 private vhost（迁移前为
  `metapi.greencloud.zhyi.cc`）；未来重新部署的 `axonhub.*` 也必须保持 private。
  公开 API 入口由 `ai-api.zhyi.xin` 的 hostdare UniAPI 承担。
- **不把运行态当 Nix 声明。** Nix 负责服务存在和 secret 文件挂载；应用内 channel、
  account、route、管理员、工作流等数据由各自数据库持久化和备份。

## 健康检查

以下命令在 `tencent` 以 root 执行；只验证，不打印密钥：

```bash
# metapi 在 tencent；librechat/n8n/n8n-openai-bridge 仍在 greencloud
systemctl is-active metapi

curl -fsS \
  -H "Authorization: Bearer $(cat /run/secrets/uni-api-admin-api-key)" \
  https://ai-api.zhyi.xin/v1/models | jq '(.data // []) | length'

curl -fsS \
  -H "Authorization: Bearer $(cat /run/secrets/uni-api-admin-api-key)" \
  http://127.0.0.1:13811/v1/models | jq '(.data // []) | length'
```

预期所有 service 为 `active`，两次模型数相同。模型数变化通常是 Provider 注册表变更
的结果；模型数为 `0`、服务反复重启或两个数不一致时，先检查：

```bash
journalctl -u metapi --since '30 minutes ago' --no-pager
# 在 hostdare 上检查 UniAPI：
# journalctl -u uni-api --since '30 minutes ago' --no-pager
```

再检查对应 SOPS secret 是否已加载，不要先重置数据库：

```bash
test -s /run/secrets/uni-api-admin-api-key
test -s /run/secrets/default-pw
```

## 初始化与恢复

只有在应用数据库被明确新建或清空后，才需要再次初始化：

1. 先部署并确认 UniAPI（rock5c）有模型，同时验证 `https://ai-api.zhyi.xin` 可达 ROCK 5C。
2. 在 Metapi 创建唯一 `UniAPI`、`openai` 站点，地址为
   `https://ai-api.zhyi.xin`；添加 API-key 账户并执行“刷新模型并重建路由”。
3. 用“健康检查”验证模型数一致，再恢复应用自身的备份数据。
4. 只有明确重新启用 AxonHub 时，才在其首次向导创建管理员和唯一的 `UniAPI`
   channel；不要把历史初始化记录当成当前服务已经部署。

若目标只是修复服务启动、证书或 Nix 配置，不要重新执行这套初始化，也不要重置运行态
数据库。
