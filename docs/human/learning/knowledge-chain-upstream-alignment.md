# 知识链完整链路与上游对齐审计

目标：把作者（xddxdd / Lan Tian）的私有 + 公开两条知识天线完整跑通，并逐项
对照作者原版确认链路一致。

## 上游作者链路

| 环节 | 作者原版 | 当前复刻 |
| --- | --- | --- |
| 私有笔记载体 | 本地 Markdown/Documents，客户端 `Documents` bind 到 Syncthing 持久目录 | `~/Documents` 整体 bindfs 到 `/nix/persistent/media/Documents`（四台 client 统一） |
| 私有 Git | Gitea `git.lantian.pub`，`DEFAULT_PRIVATE = "private"`，push-create | Gitea `git.zhyi.xin`，已推送 `zhyi/notes` |
| 去中心化 Git | Radicle `radicle.lantian.pub` + 客户端 radicle-node | 未启用（候选） |
| 私有同步 | Syncthing 客户端 + 服务器 | 已生效：ml-2700 / ml-laptop / opi5p / greencloud 四节点同步 `media` 文件夹 |
| 公开写作环境 | editorconfig（md/mdx/astro 2 空格）、markdown-apa7th-docx | 已随 home 模块生效 |
| 公开博客源码 | `xddxdd/blog`，Astro + Markdown/MDX | 已删除（2026-08-20）：`~/Documents/Blog` 为唯一副本且已永久删除，远端仓库不存在 |
| 公开发布 | GitHub Actions 构建并推送 `lantian1998.github.io` + rsync 服务器 | 公开路线暂停，无远端仓库 |
| 博客评论 | Waline `comments.lantian.pub` | 已退役（2026-08-15）：未部署即随公开路线暂停一并下线 |
| 内容索引 | pyison `posts.lantian.pub` | 已退役（2026-08-15）：posts.zhyi.xin 下线，模块与 DNS 记录已移除 |

## 当前完成状态

已完成：

- 四台 client（ml-2700 / ml-laptop / opi5p / greencloud）统一复刻作者客户端
  Documents 布局：`~/Documents` 整体 bindfs 到 `/nix/persistent/media/Documents`，
  `media/` 根 13 目录逐字建齐（与作者 lt-hp-omen 一致）。
- Notes 已并入 Documents（2026-08-20 把 `media/Notes` 重命名为 `media/Documents`，
  Syncthing 把 rename 传播到四台），`zhyi/notes` Git 远端为
  `ssh://git@git.zhyi.xin:2222/zhyi/notes.git`，Gitea 侧经 `git ls-remote` 确认存在。
- 四台 Syncthing 单 `media` 文件夹，devices 四台全 mesh，已收敛一致。
- pyison（posts.zhyi.xin）与 Waline（comments.zhyi.xin）已于 2026-08-15 退役：
  模块、DNS 记录、secrets 与相关引用一并移除。
- `~/Documents/Blog` 已于 2026-08-20 删除：远端 `zhyiheihei/blog` 在 GitHub 上
  不存在（HTTPS/SSH 均 Repository not found），本地 3 commit 是唯一副本，删除即
  永久丢失，已获用户确认。
- ml-2700 SSH 密钥权限、GitHub/Gitea SSH 登录、GPG 密钥导入均已验证。

待外部动作：

- 公开路线暂停；GitHub 无博客远端仓库，公开写作天线下线。
- Radicle 是否启用需要身份密钥，列为可选。

## 与上游的差异

允许差异与作者原版说明一致：域名（zhyi.xin/zhyi.cc）、用户（zhyi）、复刻主机。
公开站点从作者的一级域 `lantian.pub` 改为 GitHub Pages 项目页，DNS/评论域名
对应改为 `zhyiheihei.github.io` 与 `comments.zhyi.xin`。

## AI 链关联状态

- Gitea `zhyi/notes` 是 AI 只读知识源的官方入口：`/api/v1` 读取仓库/文件，
  供 n8n 与 LibreChat 使用，不改数据库。
- Syncthing 三机同步状态可通过官方 REST 巡检，作为重索引触发信号。
- Memos 官方 API 承担 AI 写回/整理；AI Provider 保持 Metapi → UniAPI。
- Qdrant 未部署，向量 RAG 属 P2 候选；Waline 已退役（2026-08-15），如恢复公开
  评论需重新评估部署方式与 AI 审核指向（不得直连 OpenRouter）。
- AI 链模型统一选择 OpenCode Go 的 DeepSeek V4 Flash。

详细候选矩阵见
[`docs/infrastructure/ai-knowledge-chain-integration.md`](../infrastructure/ai-knowledge-chain-integration.md)。
