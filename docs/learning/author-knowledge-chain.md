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

本仓库在 `hosts/ml-2700/configuration.nix` 中为 `zhyi` 配置：

- `~/Documents/Notes`：私有天线，含 `inbox/`、`private/`、`archive/`、
  `shared/` 子目录。
- `~/Documents/Blog`：公开天线，含 `content/` 目录。
- `~/Documents/Notes` 是 `/nix/persistent/media/Notes` 的 bindfs 视图，
  与作者客户端 Documents 同款；Syncthing 同步该持久目录到 `opi5p` /
  `colocrossing`。
- Notes 仓库与本仓库相互独立，不共享 `.git` 或绑定目录。
- Git 远端在运行时配置，不额外提供脚本：
  - 私有：`ssh://git@git.zhyi.xin:2222/zhyi/notes.git`
  - 公开：`git@github.com:zhyiheihei/blog.git`

Gitea 已开启 push-create，私有仓库可以在首次 `push` 时自动创建；GitHub 公开
博客仓库需要先在 `zhyiheihei/blog` 创建后再 push。

实机验证：`git.zhyi.xin` 的 OpenSSH 监听在 2222，Gitea 的 `SSH_PORT` 与上游
一致为 2222，网页克隆地址与实际连接端口相同。
