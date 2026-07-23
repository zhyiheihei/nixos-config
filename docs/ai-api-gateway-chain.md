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
Open WebUI / n8n      AxonHub / Metapi
```

应用调用路径与管理网关是并列关系，不是需要逐层穿透的串联关系：

```text
Open WebUI  ──────────────────────> ml-home-vm UniAPI ─> Provider
AxonHub     ──────────────────────> ml-home-vm UniAPI ─> Provider
Metapi      ──────────────────────> ml-home-vm UniAPI ─> Provider
ml-home-vm UniAPI ─> n8n OpenAI Bridge (colocrossing) ─> n8n 工作流

ai-api.zhyi.cc ───────────────────> jpvm UniAPI ─────────> Provider
```

`ai-api.zhyi.cc` 是 JPVM 上的独立公开 UniAPI 入口；它也从同一份 secrets Provider
注册表导入配置，但不依赖 colocrossing 的 AxonHub 或 Metapi。

Open WebUI、AxonHub、Metapi、n8n 运行在 `colocrossing`，通过 LTNET 访问
ml-home-vm 上的 UniAPI（`https://uni-api.ml-home-vm.zhyi.cc/v1`）。UniAPI
通过 LTNET 回调 colocrossing 上的 n8n Bridge
（`https://n8n-bridge.colocrossing.zhyi.cc/v1`）。

## 服务职责与位置

| 服务 | 主机 | 作用 | 上游或依赖 |
| --- | --- | --- | --- |
| UniAPI | `ml-home-vm`、`jpvm` | Provider 注册表、模型别名与 OpenAI 兼容 API | 私有 `uni-api/` secrets |
| Open WebUI | `colocrossing` | 交互式 AI 前端，使用 Dex OIDC 登录 | LTNET `uni-api.ml-home-vm.zhyi.cc` |
| n8n | `colocrossing` | 自动化工作流 | PostgreSQL；工作流可调用 Bridge |
| n8n OpenAI Bridge | `colocrossing` | 把标记为 `n8n-openai-bridge` 的工作流作为模型暴露给 UniAPI | n8n API；UniAPI key |
| AxonHub | `colocrossing` | 可选 AI 网关、渠道管理、观测与独立下游 API 管理 | PostgreSQL、Redis、LTNET UniAPI |
| Metapi | `colocrossing` | 可选元聚合网关、站点/账户/模型路由管理 | LTNET UniAPI；SQLite 状态目录 |

核心实现位置：

- [`nixos/optional-apps/uni-api.nix`](../nixos/optional-apps/uni-api.nix)
- [`nixos/optional-apps/open-webui/default.nix`](../nixos/optional-apps/open-webui/default.nix)
- [`nixos/optional-apps/n8n/n8n-openai-bridge.nix`](../nixos/optional-apps/n8n/n8n-openai-bridge.nix)
- [`nixos/optional-apps/axonhub.nix`](../nixos/optional-apps/axonhub.nix)
- [`nixos/optional-apps/metapi.nix`](../nixos/optional-apps/metapi.nix)
- [`hosts/colocrossing/configuration.nix`](../hosts/colocrossing/configuration.nix)
- [`hosts/ml-home-vm/configuration.nix`](../hosts/ml-home-vm/configuration.nix)
- [`hosts/jpvm/configuration.nix`](../hosts/jpvm/configuration.nix)

## 已完成的运行态初始化

作者公开的 Nix 模块只声明服务、数据库和反向代理；AxonHub 与 Metapi 的上游渠道、
账户及路由是应用数据库中的运行态数据，不能通过重新 `switch` 自动重建。

当前已经完成以下初始化，记录日期为 2026-07-21：

- AxonHub：默认项目中有一个名为 `UniAPI` 的 `openai` channel，指向
  `https://uni-api.ml-home-vm.zhyi.cc/v1`，并导入 UniAPI 当前模型目录。
- Metapi：有一个名为 `UniAPI` 的 `openai` 站点，指向
  `https://uni-api.ml-home-vm.zhyi.cc`；有一个对应的 API-key 账户；已执行官方的模型刷新与路由
  重建。
- 初始化时两个网关均识别到 `162` 个模型；这个数字随 Provider 注册表改变，不是
  配置常量。
- AxonHub 首个管理员已创建在其自身数据库中；初始口令沿用
  `common/default-pw.yaml` 的 `default-pw`。登录后应按正常应用流程改为独立口令并在
  Bitwarden 保存，不能把口令写回 Nix 仓库。
- Metapi 的管理口令是 `default-pw`，其下游 `PROXY_TOKEN` 使用
  `uni-api-admin-api-key`。这是当前模块的作者式全局 secrets 约定。

不要删除 AxonHub PostgreSQL 数据库、Redis 数据或 `/var/lib/metapi`（位于 colocrossing），
除非明确要废弃相应网关；否则会丢失上述运行态初始化和应用内管理数据。

## Secrets 与密钥边界

| 位置 | 用途 | 规则 |
| --- | --- | --- |
| `uni-api/keys.yaml` 的 `uni-api-admin-api-key` | UniAPI 管理 API；n8n Bridge 客户端；Metapi 下游代理；AxonHub/Metapi 对本机 UniAPI 的上游访问 | 不输出、不提交明文；轮换时必须同步更新两套应用内上游凭据 |
| `uni-api/providers/` 与 `uni-api/apis/` | 外部 Provider URL、API key 与模型映射 | 只在私有 secrets 仓库按 SOPS 规范维护 |
| `uni-api/model-config.nix` | Open WebUI 模型显示与配置 | 与 Provider 注册表一起维护 |
| `open-webui.yaml` 的 `open-webui-env` | Open WebUI 的 OIDC client secret 与 UniAPI key 环境变量 | 保持单个环境文件 secret，不拆成未受管的明文文件 |
| `n8n.yaml` | n8n runner/API 认证 | Bridge 只读取其所需的 token，不能输出或复制到普通配置 |

轮换 `uni-api-admin-api-key` 的正确顺序：

1. 在构建机的私有 secrets 仓库按其 SOPS 文档加密更新 key。
2. 部署 `ml-home-vm` 与 `jpvm`，确认两台 UniAPI 的 `/v1/models` 均可认证。
3. 在 AxonHub 的 `UniAPI` channel 与 Metapi 的 `UniAPI` API-key 账户中更新上游 key。
4. 重新刷新 Metapi 模型并重建路由，再做下面的健康检查。

不要为了轮换 key 直接编辑 AxonHub PostgreSQL 或 Metapi SQLite；使用各自的管理 UI 或
官方 API。

## 维护规则

- **不要改主调用路径。** Open WebUI 的 `OPENAI_API_BASE_URL` 直接指向 LTNET 上的
  UniAPI（`https://uni-api.ml-home-vm.zhyi.cc/v1`）；n8n Bridge 作为 `lantian.llm-providers`
  的 `n8n` Provider 被 UniAPI 通过 `https://n8n-bridge.colocrossing.zhyi.cc/v1` 调用。两者都
  不能改为 AxonHub 或 Metapi，除非明确迁移整个调用契约并单独验证。
- **不要制造回环。** 禁止将 `axonhub.*`、`metapi.*` 或 `ai-api.zhyi.cc` 配成 UniAPI
  的 Provider；禁止给 Metapi/AxonHub 再添加指向自身的上游。
- **不重复保存外部 Provider 凭据。** AxonHub 与 Metapi 当前只保存对本机 UniAPI 的
  凭据。新增外部 Provider 时优先更新 `uni-api/` secrets，而不是分别塞入三个网关。
- **保留私有访问边界。** `axonhub.colocrossing.zhyi.cc` 与
  `metapi.colocrossing.zhyi.cc` 是 private vhost，不应为了方便就直接公开；公开 API 入口
  由 `ai-api.zhyi.cc` 的 JPVM UniAPI 承担。
- **不把运行态当 Nix 声明。** Nix 负责服务存在和 secret 文件挂载；应用内 channel、
  account、route、管理员、工作流等数据由各自数据库持久化和备份。

## 健康检查

以下命令在 `colocrossing` 以 root 执行；只验证，不打印密钥：

```bash
systemctl is-active axonhub metapi n8n n8n-openai-bridge open-webui

curl -fsS \
  -H "Authorization: Bearer $(cat /run/secrets/uni-api-admin-api-key)" \
  https://uni-api.ml-home-vm.zhyi.cc/v1/models | jq '(.data // []) | length'

curl -fsS \
  -H "Authorization: Bearer $(cat /run/secrets/uni-api-admin-api-key)" \
  http://127.0.0.1:13811/v1/models | jq '(.data // []) | length'
```

预期所有 service 为 `active`，两次模型数相同。模型数变化通常是 Provider 注册表变更
的结果；模型数为 `0`、服务反复重启或两个数不一致时，先检查：

```bash
journalctl -u metapi -u axonhub --since '30 minutes ago' --no-pager
# 在 ml-home-vm 上检查 UniAPI：
# journalctl -u uni-api --since '30 minutes ago' --no-pager
```

再检查对应 SOPS secret 是否已加载，不要先重置数据库：

```bash
test -s /run/secrets/uni-api-admin-api-key
test -s /run/secrets/default-pw
```

## 初始化与恢复

只有在应用数据库被明确新建或清空后，才需要再次初始化：

1. 先部署并确认 UniAPI（ml-home-vm）有模型。
2. 在 AxonHub 的首次向导创建管理员；在默认项目创建唯一的 `UniAPI`、`openai` 类型
   channel，地址为 `https://uni-api.ml-home-vm.zhyi.cc/v1`，导入 UniAPI 模型列表。
3. 在 Metapi 创建唯一 `UniAPI`、`openai` 站点，地址为
   `https://uni-api.ml-home-vm.zhyi.cc`；添加 API-key 账户并执行“刷新模型并重建路由”。
4. 用“健康检查”验证模型数一致，再恢复应用自身的备份数据。

若目标只是修复服务启动、证书或 Nix 配置，不要重新执行这套初始化，也不要重置运行态
数据库。
