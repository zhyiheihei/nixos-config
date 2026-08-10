# 知识链完整链路与上游对齐审计

目标：把作者（xddxdd / Lan Tian）的私有 + 公开两条知识天线完整跑通，并逐项
对照作者原版确认链路一致。

## 上游作者链路

| 环节 | 作者原版 | 当前复刻 |
| --- | --- | --- |
| 私有笔记载体 | 本地 Markdown/Documents，客户端 `Documents` bind 到 Syncthing 持久目录 | `~/Documents/Notes`，子目录 `inbox/private/archive/shared` |
| 私有 Git | Gitea `git.lantian.pub`，`DEFAULT_PRIVATE = "private"`，push-create | Gitea `git.zhyi.xin`，已推送 `zhyi/notes` |
| 去中心化 Git | Radicle `radicle.lantian.pub` + 客户端 radicle-node | 未启用（候选） |
| 私有同步 | Syncthing 客户端 + 服务器 | 已回滚；等待按官方文档重新规划后再配置 |
| 公开写作环境 | editorconfig（md/mdx/astro 2 空格）、markdown-apa7th-docx | 已随 home 模块生效 |
| 公开博客源码 | `xddxdd/blog`，Astro + Markdown/MDX | `~/Documents/Blog` Astro 骨架，GitHub Pages workflow 已准备 |
| 公开发布 | GitHub Actions 构建并推送 `lantian1998.github.io` + rsync 服务器 | `zhyiheihei/blog` 仓库待创建后推送 |
| 博客评论 | Waline `comments.lantian.pub` | 已回滚；公开路线暂停，待重新规划 |
| 内容索引 | pyison `posts.lantian.pub` | `posts.zhyi.xin` 已在 colocrossing 部署 |

## 当前完成状态

已完成：

- `~/Documents/Notes` 初始化 Git 并推送到 `ssh://git@git.zhyi.xin:2222/zhyi/notes.git`，
  Gitea 侧经 `git ls-remote` 确认存在。
- Notes 已恢复为普通目录，bindfs 与 `.git` 符号链接已移除。
- ml-2700 / opi5p 的 Syncthing 配对与 notes 文件夹已回滚到改动前状态。
- colocrossing 的 Waline 与 `comments.zhyi.xin` 相关改动已回滚。
- `~/Documents/Blog` 已初始化 Git，加入 Astro 骨架（文章集合、MDX、sitemap、
  Waline 客户端、GitHub Pages workflow），本地提交完成。
- ml-2700 SSH 密钥权限、GitHub/Gitea SSH 登录、GPG 密钥导入均已验证。

待外部动作：

- 在 GitHub 创建 `zhyiheihei/blog`（当前账号 token 无效，无法用 API 代建），
  然后推送并启用 Pages。
- 公开路线暂停；GitHub `zhyiheihei/blog` 仍待创建后推送。
- Radicle 是否启用需要身份密钥，列为可选。

## 与上游的差异

允许差异与作者原版说明一致：域名（zhyi.xin/zhyi.cc）、用户（zhyi）、复刻主机。
公开站点从作者的一级域 `lantian.pub` 改为 GitHub Pages 项目页，DNS/评论域名
对应改为 `zhyiheihei.github.io` 与 `comments.zhyi.xin`。
