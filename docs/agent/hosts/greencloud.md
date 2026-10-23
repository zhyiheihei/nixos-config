# greencloud（境外 VPS，公网应用入口）

多数 `zhyi.xin` 应用与 OAuth 入口的终止机，同时是 LTNET 到家庭的跳板。
`hosts/greencloud/*.nix` 不写注释，理由记录在本文件。

## 停用的可选模块

上游已停用、本仓跟随停用的：`bepasty`、`imapfilter`、`lemmy`、`librechat`、
`maddy`（DN42 的 TLS 证书还没恢复）、`radicle`、`tranquil-pds`、`tg-bot-cleaner-bot`
、`yggdrasil-alfis`、`radicale-calendar-sync`（迁往 tencent）、`n8n`（compromised，
不再启用）。`gitea-actions` 的 runner 留在本机（Gitea 本体在 greencloud-jp，性能弱
不跑 CI），但模块本身目前停用。

## 服务

- **Home Assistant**：公共应用，给手机 companion 用；greencloud 终止 TLS 后经 LTNET
  直连 opi5p 上的 HA 实例。
- **Miniflux / RSSHub**：User-Agent 与用户本机 Firefox 身份一致，否则反爬站点会把
  Miniflux 的抓取当成非浏览器客户端拒绝；RSSHub 用同一个 UA。
- **ltnet-scripts**：本机是 rsync 源站之一，`nix/sync-servers` 下有一批「通常由私有
  ltnet-scripts 管线生成」的 bootstrap 文件；主同步服务器拥有这些路径，生成的正确内容
  之后会替换它们。

## 硬件/平台

QEMU 虚机（BIOS），磁盘布局按 Alpine 安装环境核实。
