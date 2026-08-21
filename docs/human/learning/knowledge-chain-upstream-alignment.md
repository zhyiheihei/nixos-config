# 知识链完整链路（上游对齐与 Syncthing 实施）

目标：把作者（xddxdd）的私有 + 公开两条知识天线完整跑通，并逐项对照作者原版
确认链路一致。作者不用 Obsidian：知识链是两条 Git/Markdown 天线（公开 =
Astro 博客；私有 = Markdown/Documents + Gitea + Syncthing；Radicle 与
OpenWebUI-KB-Manager 是可选扩展）。

## 作者原版证据

- `home/common-apps/editorconfig.nix`：`*.md`/`*.mdx`/`*.astro` 统一 2 空格。
- `home/client-apps/packages.nix`：`markdown-apa7th-docx`（Markdown → APA7 DOCX）。
- `nixos/optional-apps/gitea/default.nix`：`git.lantian.pub`，`DEFAULT_PRIVATE =
  "private"`，禁用注册，push-create。
- `nixos/optional-apps/radicle.nix`：去中心化 Git 节点。
- `nixos/optional-apps/syncthing` + `hosts/lt-hp-omen`：Documents 由 Syncthing
  同步的持久化媒体目录 bind 挂载。
- `nixos/optional-apps/waline` / `pyison`：博客评论 / 内容索引。
- 博客源码 `xddxdd/blog`：Astro + MDX，workflow 把 `dist/` rsync 到服务器并推送
  `lantian1998.github.io`。

## 上游作者链路 vs 复刻

| 环节 | 作者原版 | 当前复刻 |
| --- | --- | --- |
| 私有笔记载体 | 本地 Markdown/Documents，客户端 `Documents` bind 到 Syncthing 持久目录 | `~/Documents` 整体 bindfs 到 `/nix/persistent/media/Documents`（四台 client 统一） |
| 私有 Git | Gitea `git.lantian.pub`，`DEFAULT_PRIVATE = "private"`，push-create | Gitea `git.zhyi.xin`，已推送 `zhyi/notes` |
| 去中心化 Git | Radicle `radicle.lantian.pub` + 客户端 radicle-node | 未启用（候选） |
| 私有同步 | Syncthing 客户端 + 服务器 | 已生效：ml-2700 / ml-laptop / opi5p / greencloud 四节点同步 `media` 文件夹 |
| 公开写作环境 | editorconfig（md/mdx/astro 2 空格）、markdown-apa7th-docx | 已随 home 模块生效 |
| 公开博客源码 | `xddxdd/blog`，Astro + Markdown/MDX | 已删除（2026-08-20）：`~/Documents/Blog` 为唯一副本且已永久删除，远端仓库不存在 |
| 公开发布 | GitHub Actions 构建并推送 `lantian1998.github.io` + rsync 服务器 | 公开路线暂停，无远端仓库 |
| 博客评论 | Waline `comments.lantian.pub` | 已退役（2026-08-15） |
| 内容索引 | pyison `posts.lantian.pub` | 已退役（2026-08-15） |

## 客户端布局（ml-2700 / ml-laptop / opi5p / greencloud 统一）

四台 `zhyi` 客户端统一复刻作者客户端 Documents 布局：`~/Documents` 整体 bind 到
`/nix/persistent/media/Documents`（媒体根 `media/` 下共 13 个目录：Backups/Books/
Calibre Library/CloudMusic/CloudMusicArchive/Documents/LegacyOS/ManosabaMod/
Pictures/Secrets/Software/VideoArchive/Yuzu）。`~/Documents` 即私有天线，含
原 Notes 内容：

- Notes 仓库在 `media/Documents` 内独立成子目录、独立 `.git`，不与本仓库共享
  仓库或绑定目录；Syncthing 的 `media` 文件夹把 `media/` 整体同步到四台。
- 公开天线 `Blog` 已于 2026-08-20 删除（远端 `zhyiheihei/blog` 不存在，本地
  3 commit 是唯一副本，删除即永久丢失）。
- Git 远端在运行时配置：私有 `ssh://git@git.zhyi.xin:2222/zhyi/notes.git`；
  Gitea 已开启 push-create。实机验证：Gitea 的 `SSH_PORT` 与上游一致为 2222。

## 实施方式（已建成）

- 各机启用 `nixos/optional-apps/syncthing`（模块 1:1 复刻作者，storage 走
  bind 视图 `/run/syncthing-files`，`overrideFolders=false`、
  `overrideDevices=false`、`autoAcceptFolders=true`）。
- 用 Syncthing 官方 REST API 在四台机器上完成 device 配对与 media folder 关联；
  不引入仓库内脚本；不手改 config.xml 内容结构。
- 作者同步整个 media storage 根（Documents/Books/CloudMusic/Pictures/Secrets/
  VideoArchive 全部 bind 到 media 根）；storage 默认 `/nix/persistent/media`
  （opi5p 为 `/mnt/storage/media`，NFS）。

## 权限关键点（排障结论）

- syncthing 以 uid 237 运行，需对 media 根目录有属主权限才能 chmod。
- **opi5p**：media 根落在 qnap NFS（`192.168.0.40:/nixos`），根下 Notes 属主原为
  `zhyi:zhyi`，syncthing 无法 chmod → errors=373。`chown syncthing:syncthing`
  media 根后重启 syncthing，errors 归零。
- 触发错误后需 `systemctl restart syncthing` 才能清掉历史缓存错误，
  仅 REST rescan 不刷新 status 的 errors 计数。

## 完成记录（2026-08-20）

- 四台 mesh 已建成：ml-2700 / opi5p / greencloud / ml-laptop 均为
  `media` folder（指向各自 `/run/syncthing-files`）、errors=0、inSync=343、
  needBytes=0；device 名已对齐；已清理测试残留 `.testdir`/`.testperm` 与
  opi5p 上多余的 `notes` folder。
- 四台 client 统一 `~/Documents` 布局，`media/` 根 13 目录逐字建齐；Notes 已
  并入 Documents（2026-08-20 rename，Syncthing 传播到四台），`zhyi/notes` Git
  远端 `ssh://git@git.zhyi.xin:2222/zhyi/notes.git` 经 `git ls-remote` 确认存在。
- pyison / Waline 已于 2026-08-15 退役：模块、DNS 记录、secrets 一并移除。
- `~/Documents/Blog` 已于 2026-08-20 删除（远端仓库不存在，本地 3 commit 是
  唯一副本，已获用户确认删除）。
- ml-2700 SSH 密钥权限、GitHub/Gitea SSH 登录、GPG 密钥导入均已验证。

## 验收标准

- 四台 `media` folder 状态 `idle`、`needBytes=0`、`errors=0`，devices 全连。
- 每台仅保留 `media` 一个 folder（无残留 `notes` / 脏 device）。

## 与上游的差异

允许差异与作者原版说明一致：域名（zhyi.xin）、用户（zhyi）、复刻主机。
公开站点从作者一级域改为 GitHub Pages 项目页，DNS/评论域名对应改为
`zhyiheihei.github.io` 与 `comments.zhyi.xin`。

## AI 链关联状态

- Gitea `zhyi/notes` 是 AI 只读知识源的官方入口，供 n8n 与 LibreChat 使用。
- Syncthing 四机同步状态可通过官方 REST 巡检，作为重索引触发信号。
- Memos 官方 API 承担 AI 写回/整理；AI Provider 保持 Metapi → UniAPI。
- Qdrant 未部署，向量 RAG 属 P2 候选；如恢复公开评论需重新评估部署方式与
  AI 审核指向（不得直连 OpenRouter）。
- AI 链模型统一选择 OpenCode Go 的 DeepSeek V4 Flash。

详细候选矩阵见
[`docs/human/infrastructure/ai-knowledge-chain-integration.md`](../infrastructure/ai-knowledge-chain-integration.md)。
