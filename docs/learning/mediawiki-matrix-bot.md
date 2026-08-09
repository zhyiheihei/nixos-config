# mediawiki-matrix-bot 学习笔记

## 1. 是什么

`mediawiki-matrix-bot` 是 makefu 维护的 Matrix bot：把 MediaWiki
的 Recent Changes（来自 `api.php`）发布到 Matrix 房间，wiki.nixos.org
就用它对接 Matrix。MIT，4 star，Python，2025-11 仍在维护。

## 2. 工作方式

- 每 `timeout` 秒（默认 60）轮询
  `{baseurl}{api_path}?action=query&list=recentchanges&format=json&rcprop=...`；
- 记住最后一条 `rcid`，只转发更新的条目；**无状态处理**——bot
  离线期间的变化不会补发；
- 消息用 `m.notice` + HTML（`org.matrix.custom.html`），带纯文本
  fallback；格式参考 MediaWiki 的 IRCColourfulRCFeedFormatter：
  `[[标题]] N/M/B 标志、diff 链接、用户名、长度差（大删除加粗、
  新增加 `+`）、评论`；
- matrix-nio 登录后 `sync_forever` 维持连接。

## 3. 配置

`config.json`：

```json
{
  "mxid": "@botname:servername",
  "server": "https://servername",
  "password": "...",
  "room": "!roomid:servername.net",
  "baseurl": "https://wiki.nixos.org",
  "api_path": "/w/api.php",
  "timeout": 60
}
```

## 4. 工程与 CI

- `buildPythonApplication`：feedparser / matrix-nio / docopt /
  aiohttp / aiofiles；checkPhase 跑 `mypy --strict`；
- flake 提供 x86_64-linux 包；CI 在 ubuntu/macos 上 `nix-build`；
- dependabot 管 GitHub Actions（cargo 目录是历史残留）。

## 5. 对我们仓库的启发

- 我们不做 wiki→Matrix 桥，不引入；
- 它展示了“轮询上游 API + 记录游标 + 格式化通知”的最小 bot
  骨架，org 的 infra 类服务常用这个形态；
- 无状态 + 简单 HTML 格式，说明运维 bot 优先保持可读、可重跑，
  而不是堆状态机。

## 6. 参考

- [mediawiki-matrix-bot](https://github.com/nix-community/mediawiki-matrix-bot)
