# 作者知识链：私有 + 公开两天线

## 结论

作者（xddxdd / Lan Tian）不用 Obsidian。作者原版配置里的知识链是两条
Git/Markdown 天线：

- 公开天线：`xddxdd/blog`（Astro.js + Markdown/MDX），发布到 `lantian.pub`，
  评论由 Waline 承载。
- 私有天线：本地 Markdown/Documents + 自托管 Gitea（默认私有仓库）+
  Syncthing 同步；Radicle 与 OpenWebUI-KB-Manager 是可选去中心化/AI 扩展。

## 作者原版证据

- `home/common-apps/editorconfig.nix`：`*.md`、`*.mdx`、`*.astro` 统一 2 空格
  缩进，说明 Markdown 写作是统一环境。
- `home/client-apps/packages.nix`：安装 `markdown-apa7th-docx`，提供
  Markdown -> APA7 DOCX 的写作链。
- `nixos/optional-apps/gitea/default.nix`：`git.lantian.pub`，
  `DEFAULT_PRIVATE = "private"`，禁用注册，支持 push-create；自托管私有 Git。
- `nixos/optional-apps/radicle.nix`：`radicle.lantian.pub` 去中心化 Git 节点。
- `nixos/optional-apps/syncthing` 与 `hosts/lt-hp-omen`：客户端 Documents 由
  Syncthing 同步的持久化媒体目录 bind 挂载，跨设备同步私有资料。
- `nixos/optional-apps/waline`：博客评论 `comments.lantian.pub`。
- `nixos/optional-apps/pyison`：`posts.lantian.pub` 内容索引。
- 博客源码 `xddxdd/blog`：Astro + MDX；`.github/workflows/deploy.yml` 把
  `dist/` rsync 到服务器并推送到 `lantian1998.github.io`。
- 作者另有公开仓库 `OpenWebUI-KB-Manager`，是 OpenWebUI 文件/知识库管理 CLI，
  可作后续 AI/RAG 知识链扩展。

## ml-2700 复刻

四台 `zhyi` 客户端（`ml-2700`、`ml-laptop`、`opi5p`、`greencloud`）统一复刻作者
客户端 Documents 布局：`~/Documents` 整体 bind 到 `/nix/persistent/media/Documents`
（媒体根 `media/` 下共 13 个目录：Backups/Books/Calibre Library/CloudMusic/
CloudMusicArchive/Documents/LegacyOS/ManosabaMod/Pictures/Secrets/Software/
VideoArchive/Yuzu）。`~/Documents` 即私有天线，含原来的 Notes 仓库（已并入
Documents，不再有独立 Notes 目录）：

- 私有天线：`~/Documents`（含 `getting-started/`、`hardware/`、
  `infrastructure/`、`learning/`、`migrations/`、`network/`、`operations/`、
  `reference/`、`services/` 及原 Notes 内容）。
- Notes 仓库在 `media/Documents` 内独立成子目录、独立 `.git`，不与本仓库共享
  仓库或绑定目录；Syncthing 的 `media` 文件夹把 `media/` 整体同步到四台。
- 公开天线 `Blog` 已于 2026-08-20 删除（远端 `zhyiheihei/blog` 在 GitHub 上
  不存在，本地 3 commit 是唯一副本，删除即永久丢失）。
- Git 远端在运行时配置，不额外提供脚本：私有
  `ssh://git@git.zhyi.xin:2222/zhyi/notes.git`。

Gitea 已开启 push-create，私有仓库可以在首次 `push` 时自动创建。

实机验证：`git.zhyi.xin` 的 OpenSSH 监听在 2222，Gitea 的 `SSH_PORT` 与上游
一致为 2222，网页克隆地址与实际连接端口相同。

## AI 链关联（复刻新增）

私有天线已具备接入 AI 链的官方 API 基础：

- Gitea REST `/api/v1`：n8n/LibreChat 可只读拉取 `zhyi/notes` 内容做摘要或问答；
  PAT 按最小权限创建并进 SOPS。
- Syncthing REST：`/rest/events` 与 `/rest/db/status` 可做变更事件与同步巡检，
  作为重索引触发器。
- Memos 官方 API：可把 AI 生成的摘要/整理结果写回 Memos，形成知识闭环。
- AI 链模型统一选择 OpenCode Go 的 DeepSeek V4 Flash（UniAPI 别名按 secrets
  注册表核验）。

候选方案与红线见
[`docs/infrastructure/ai-knowledge-chain-integration.md`](../infrastructure/ai-knowledge-chain-integration.md)。
