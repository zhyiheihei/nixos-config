# Memos 服务接入（SSO / 存储 / 通知 / AI）

Memos 运行在 `opi5p`，入口为 `https://memos.opi5p.zhyi.cc`，容器固定
`neosmemo/memos:0.29.1`，数据目录挂载宿主机的 `/var/lib/memos`（NVMe 持久盘）。
应用内的 SSO、AI Provider、通知和附件存储都通过 Memos 官方 HTTP API 配置，
不直接修改 Memos 数据库。

## OIDC 匹配关系

之前 Memos 只挂在 nginx 的 OAuth2 Proxy 后面，Memos 自身没有身份体系接入。
本次改为 Memos 原生 OAuth2 登录，登录按钮直连 Dex：

| 项 | 值 |
| --- | --- |
| Dex client id | `memos` |
| Dex client secret | `common/dex.yaml` 的 `dex-memos-secret` |
| 回调 | `https://memos.opi5p.zhyi.cc/auth/callback` |
| authorization endpoint | `https://login.zhyi.xin/auth` |
| token endpoint | `https://login.zhyi.xin/token` |
| userinfo endpoint | `https://login.zhyi.xin/userinfo` |
| scopes | `openid profile email groups` |
| identifier 字段 | `preferred_username`（限定 `^zhyi$`） |

Dex 已确认支持 PKCE `S256`，Memos 登录页会正常发起授权码 + PKCE 流程。
Memos 公网 vhost 不再叠加 OAuth2 Proxy，避免“先过一层 Dex、再登录 Memos”
的双重登录。

Memos 的 SSO 首次登录默认会创建 UUID 用户，不会自动绑定既有 `zhyi` 账号。
要让 `zhyi` 直接复用，先在 Memos 内用密码登录一次，在
Settings → Linked Identities 里完成绑定，之后即可用 Dex 登录。

## 存储

- 容器数据：`/var/lib/memos:/var/opt/memos`，数据库仍在本机 NVMe 持久盘。
- 应用内附件：走私有 VaultS3，`storage_type=S3`，bucket `memos`，
  模板 `assets/{timestamp}_{filename}`，单文件上限 64 MiB。
- S3 endpoint：`https://vaults3.zhyi.cc`（opi5p 本机 TLS 前端），
  `usePathStyle=true`。
- 凭据：VaultS3 IAM 用户 `memos` 的专用 access key/secret，策略只允许
  `arn:aws:s3:::memos` 与 `arn:aws:s3:::memos/*`，明文只存在于 secrets 仓库的
  `common/memos.yaml`（SOPS 加密），部署后由 `memos-s3-access-key` /
  `memos-s3-secret-key` 注入 opi5p。
- bucket 通过 VaultS3 官方 CLI 创建（`vaults3-cli bucket create memos`），
  独立凭据通过 VaultS3 官方 API `POST /api/v1/keys` 创建（自动生成 IAM 用户与
  bucket 范围策略），不要直接修改 VaultS3 数据库。bucket 只接受认证访问，
  匿名请求返回 403。

## 通知

复用系统已有的 SMTP 链路（`nixos/minimal-components/smtp.nix`）：

| 项 | 值 |
| --- | --- |
| SMTP host | `send.ahasend.com` |
| SMTP port | `587` |
| 用户名 | `EjG9ROGAei` |
| 密码 | `common/smtp.yaml` 的 `smtp-pass` |
| 发件人 | `postmaster@zhyi.cc` |
| 加密 | STARTTLS |

Memos 0.29.1 的实例通知只提供 SMTP；用户级 Webhook 可用于其他通道，
需要时通过官方 `UserWebhook` API 创建。

## AI（Metapi）

Memos 的 AI Provider 指向 Metapi，而不是直接指向 UniAPI：

| 项 | 值 |
| --- | --- |
| Provider type | `OPENAI` |
| endpoint | `https://metapi.colocrossing.zhyi.cc/v1` |
| API key | `uni-api/keys.yaml` 的 `uni-api-admin-api-key` |

`metapi.colocrossing.zhyi.cc` 是 private vhost，只从 LTNET 访问。opi5p 已声明
hosts 映射 `198.18.0.120`，容器同时使用 `--add-host` 指向同一地址，保证 Memos
和运维脚本都能走 LTNET 直连。不要把这个 endpoint 改成公网入口或 UniAPI
之外的网关，也不要让 Metapi 反向成为 UniAPI Provider。

AI 功能中选择的模型统一使用 OpenCode Go 的 DeepSeek V4 Flash；Memos 页面里的
模型列表来自 Metapi，实际别名以 UniAPI Provider 注册表为准。

## AI 读取与整理（官方 API）

Memos 既可作为 AI 写回目标，也可作为 AI 收件箱：

- 读取：`GET /api/v1/memos`（支持过滤/分页），返回当前用户可见的 memo。
- 创建：`POST /api/v1/memos`，请求体是 Memo，`content` 为 Markdown，
  `visibility` 取 `PRIVATE | PROTECTED | PUBLIC`（默认 PRIVATE）。
- 更新：`PATCH /api/v1/{memo.name=memos/*}`，配合官方字段掩码。
- 删除：`DELETE /api/v1/{name=memos/*}`。

以上均使用 Personal Access Token（`Authorization: Bearer <PAT>`），由 n8n 或
`tools/knowledge-chain/notes-digest.sh` 调用，不直接修改 SQLite。

## 官方 API 配置脚本

部署 Nix 变更后，在 opi5p 上创建一个 Memos Personal Access Token
（Settings → Access Tokens），然后运行：

```bash
printf '%s' '<你的 PAT>' > /tmp/memos-admin-token
chmod 600 /tmp/memos-admin-token
export MEMOS_ADMIN_TOKEN_FILE=/tmp/memos-admin-token
bash tools/memos/configure-memos.sh
```

脚本会幂等配置：

1. 创建/更新 Dex OAuth2 Identity Provider。
2. 更新 `instance/settings/AI`（Metapi Provider）。
3. 更新 `instance/settings/NOTIFICATION`（现有 SMTP）。
4. 更新 `instance/settings/STORAGE`（LOCAL 附件存储）。
5. 打印最终配置用于核对。

脚本只调用 Memos 官方 `/api/v1` 与 `/memos.api.v1.*` API，不写数据库。

## 验证

```bash
curl -fsS http://127.0.0.1:13819/api/v1/identity-providers/dex-memos | jq
curl -fsS http://127.0.0.1:13819/api/v1/instance/settings/AI | jq
curl -fsS http://127.0.0.1:13819/api/v1/instance/settings/NOTIFICATION | jq
curl -fsS http://127.0.0.1:13819/api/v1/instance/settings/STORAGE | jq
```

浏览器中应看到 Memos 登录页出现 “Sign in with Dex” 按钮；点击后按
`login.zhyi.xin` → `id.zhyi.xin` 完成免密登录。Memos 页面内的 AI 功能应能列出
Metapi 上的模型，邮件通知配置保存后可通过官方 `testEmail` 端点发送测试邮件。
