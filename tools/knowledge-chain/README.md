# knowledge-chain 工具

本目录只包含走官方 API 的知识链集成工具，不直接操作任何数据库。

## notes-digest.sh

闭环：`Gitea API 拉 Notes -> UniAPI 摘要 -> Memos 官方 API 写回`。

所需凭据（全部通过环境变量或只读 secret 文件传入，不写进仓库）：

| 变量 | 默认文件 | 说明 |
| --- | --- | --- |
| `GITEA_TOKEN` / `GITEA_TOKEN_FILE` | `/run/secrets/gitea-ai-token` | Gitea API token，最小权限应含 `read:repository` |
| `UNIAPI_KEY` / `UNIAPI_KEY_FILE` | `/run/secrets/uni-api-admin-api-key` | UniAPI Bearer token |
| `MEMOS_TOKEN` / `MEMOS_TOKEN_FILE` | `/run/secrets/memos-ai-token` | Memos Personal Access Token |

常用配置：

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `GITEA_BASE_URL` | `https://git.zhyi.xin` | Gitea 根地址 |
| `GITEA_REPO` | `zhyi/notes` | Notes 仓库 |
| `UNIAPI_BASE_URL` | `https://uni-api.rock5c.zhyi.cc` | UniAPI 根地址 |
| `MEMOS_BASE_URL` | `http://127.0.0.1:13819` | Memos 本机入口 |
| `AI_MODEL` | `deepseek-v4-flash` | AI 链默认模型：OpenCode Go DeepSeek V4 Flash |
| `MEMOS_VISIBILITY` | `PRIVATE` | 写入 Memos 的可见性 |
| `MAX_INPUT_BYTES` | `120000` | 喂给模型的输入上限 |
| `NOTES_PREFIX` | 空 | 只处理该子目录下的笔记 |
| `DRY_RUN` | 空 | 非空时只打印摘要，不写 Memos |
| `OUTPUT_FILE` | 空 | 非空时先把摘要写到该文件 |

示例（在 colocrossing/opi5p 上执行）：

```bash
DRY_RUN=1 bash tools/knowledge-chain/notes-digest.sh
bash tools/knowledge-chain/notes-digest.sh
```

官方 API 出处见
[`docs/infrastructure/ai-knowledge-chain-integration.md`](../../docs/infrastructure/ai-knowledge-chain-integration.md)。
