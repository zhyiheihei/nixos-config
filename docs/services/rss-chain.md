# RSS 链路（RSSHub / Miniflux / ArchiveBox）

> 状态：2026-08-05 执行中。退役配置已改（待部署）；用户澄清：**Miniflux 旧订阅
> 不补**，ArchiveBox 归档保留不删。本文是“迁移完整无遗留”的核对清单。

## 服务分工

| 服务 | 运行主机 | 职责 |
| --- | --- | --- |
| RSSHub | `colocrossing` | 为没有原生 RSS 的站点生成订阅源 |
| Miniflux | `colocrossing` | 原生 RSS 与 RSSHub 订阅的统一阅读入口 |
| ArchiveBox | `opi5p` | 无法订阅的站点/页面归档 |

退役对象：FreshRSS、Linkwarden。用户 2026-08-05 指示：**Miniflux 旧订阅不要补**；
ArchiveBox 保留“实在不行”的源归档。退役服务的数据是否删除待用户确认，默认保留。

## 实机盘点与处置（2026-08-05）

### Miniflux（colocrossing，2.3.3）

- 处置后共 41 个订阅，全部启用；用户 `zhyi` 一个。
- 已修正 URL：
  - `linmohan.fun/atom.xml` 404 → `https://linmohan.fun/rss.xml`。
  - `blog.ysicing.net/feed` 返回 HTML → `https://blog.ysicing.net/feed/rss`。
- 已删除不可订阅源（站点死亡或超过 15 MB 上限）：
  - `haohanxinghe.com/atom.xml`：443 连接拒绝。
  - `blog.crneko.top/rss.xml`：DNS 无记录。
  - `blog.meimolihan.eu.org/index.xml`：唯一源 25 MB。
- 曾补入的 9 条旧 RSSHub 订阅（FreshRSS 遗留）已按用户指示全部删除，不迁移。
- 3 个不可订阅源也已删除（站点死亡或超限），保留的是修正 URL 后的现有有效订阅。

### FreshRSS 遗留（opi5p，已停止）

- 旧路由曾实测：9 条在当前 `rsshub.zhyi.xin` 可用、7 条暂不可用；按新指示不再
  回填 Miniflux，也不写入 ArchiveBox。
- 数据目录 `/var/lib/freshrss` 默认保留，退役后是否删除待用户确认。

### Linkwarden（opi5p，仍运行）

- 退役部署后停止服务；`/var/lib/linkwarden` 与 PostgreSQL `linkwarden` 数据库
  默认保留，是否删除待用户确认；181 条书签等旧数据不迁移。

### ArchiveBox（opi5p）

- 服务 active；已归档 7 个“实在不行”的旧源主页快照（用户确认 ArchiveBox 保留）。
- UI 用户 `zhyi` 可登录；后续新页面继续用同一流程归档。

### 其他核对

- DNS：无 `freshrss.*` / `linkwarden.*` 残留记录。
- Dex（cnvm）：`freshrss`、`linkwarden` 两个 OAuth client 已从配置移除，待部署生效。
- `freshrss.nix`、`linkwarden.nix` 与对应端口常量保留为公共模块文件，只是不再
  import；Dex 两个 client 已移除。

## 执行记录

- [x] 退役配置：移除 `opi5p` 的 Linkwarden 导入与门禁服务；移除 Dex 两个 client；
      公共模块文件与端口常量保留，不 import。
- [x] Miniflux：修正 2 个 URL；不补旧订阅；删除 3 个不可订阅源与误补的 9 条旧订阅。
- [x] ArchiveBox：保留并还原 7 个旧源快照（重新归档完成）。
- [x] 部署 `cnvm`、`opi5p`、`rock5c` 并实机验证；Linkwarden/FreshRSS 单元与容器
      已无残留，ArchiveBox 保留 7 个快照，homepage 已更新。
- [ ] 确认是否删除 FreshRSS/Linkwarden 数据目录与数据库（默认保留）。
- [ ] 更新 `fleet-service-chain.md`；提交并对齐 mac / origin / ml-builder。

## 浏览器订阅指南

### 一键订阅当前页面（Miniflux 原生 bookmarklet）

在浏览器书签栏新建书签，URL 填：

```javascript
javascript:location.href='https://rss.zhyi.xin/bookmarklet?uri='+encodeURIComponent(location.href)
```

看到好博客时点击该书签，Miniflux 会打开预填当前 URL 的添加订阅页；站点有原生
RSS/Atom 时会直接列出候选源，选择后完成订阅。首次使用前先登录
`https://rss.zhyi.xin`。

### 无原生 RSS 的站点（RSSHub Radar）

Firefox 已装 RSSHub Radar。在目标站点打开扩展，选中可用路由后会得到
`https://rsshub.zhyi.xin/...` 的 feed URL；复制后使用上面的 bookmarklet 或
Miniflux 的添加订阅页即可。

### 站点反爬 / “禁止访问该网站”

Miniflux 与 RSSHub 已统一使用本机 Firefox 153.0.1 的真实 UA，减少被反爬拦截。
若个别站点仍返回 403：

1. 先用 RSSHub Radar 看是否有该站点路由，有则订阅 `rsshub.zhyi.xin/...` 源；
2. 添加订阅页里可为该 feed 单独填浏览器 UA 或 cookie；
3. 仍不行就归档到 ArchiveBox，用其浏览器内核保存页面。

### ArchiveBox 手动归档

无法订阅的页面可归档：

```bash
podman exec --user=archivebox archivebox archivebox add <url>
```

或直接使用 https://archivebox.opi5p.zhyi.cc/ 的 Add 页面。

## 验证命令

```bash
# Miniflux 订阅与解析错误（colocrossing）
sudo -u postgres psql -d miniflux -c "select id, feed_url, disabled, parsing_error_msg from feeds order by id;"

# RSSHub 路由抽查（colocrossing）
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:13248/zhihu/hot

# 退役确认（opi5p）
systemctl is-active podman-linkwarden podman-archivebox
podman ps -a --format '{{.Names}} {{.Status}}' | rg -i 'archive|linkwarden|fresh'

# Dex 客户端确认（cnvm）
curl -sS https://login.zhyi.xin/.well-known/openid-configuration | jq -r '.issuer'
```
