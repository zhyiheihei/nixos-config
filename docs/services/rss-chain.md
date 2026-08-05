# RSS 链路（RSSHub / Miniflux / ArchiveBox）

> 状态：2026-08-05 实机盘点完成；退役动作待用户确认后执行。本文同时承担
> “迁移完整无遗留”的核对清单，动作完成后按结果回填并去掉待办标记。

## 服务分工

| 服务 | 运行主机 | 职责 |
| --- | --- | --- |
| RSSHub | `colocrossing` | 为没有原生 RSS 的站点生成订阅源 |
| Miniflux | `colocrossing` | 原生 RSS 与 RSSHub 订阅的统一阅读入口 |
| ArchiveBox | `opi5p` | 无法订阅的站点/页面归档 |

退役对象：FreshRSS、Linkwarden。原则：**不迁移历史数据**，只补订阅 URL 或新建
归档；旧数据目录与数据库保留，不删除。

## 实机盘点（2026-08-05）

### Miniflux（colocrossing，2.3.3）

- 共 44 个订阅，全部唯一；用户 `zhyi` 一个。
- 需要修正 URL：
  - `linmohan.fun/atom.xml` 404 → 真实源为 `https://linmohan.fun/rss.xml`。
  - `blog.ysicing.net/feed` 返回 HTML → 真实源为 `https://blog.ysicing.net/feed/rss`。
- 不可订阅（计划禁用，不删除）：
  - `haohanxinghe.com/atom.xml`：443 连接拒绝，站点不可达。
  - `blog.crneko.top/rss.xml`：DNS 无记录。
  - `blog.meimolihan.eu.org/index.xml`：唯一源 25 MB，超过 Miniflux 15 MB 上限。
- `blog.lifebus.top` 曾 504，现 curl 返回 200，保留并复查。

### FreshRSS 遗留（opi5p，已停止）

- 数据目录 `/var/lib/freshrss` 保留；`zhyi` 与 `Saffron` 两个用户各 44 个订阅。
- 其中 17 条为旧 RSSHub 路由（`rsshub.app` / `rsshub.zhyi.cc:3000`），Miniflux
  目前缺失。
- 旧路由在当前 `rsshub.zhyi.xin` 实测：
  - 可用（10 条）：四六级 CET、NCRE、CCF 大数据专家委、CCF 计算机视觉专委、
    36kr 快讯、少数派、时刻新闻、澎湃热榜、知乎热榜。
  - 暂不可用（7 条）：中国智库（上游 404）、阮一峰周刊（超时）、软考（超时）、
    什么值得买榜×2（缺 `SMZDM_COOKIE`）、bilibili 热榜（缺 Playwright 浏览器）、
    Odaily 快讯（上游 API 404）。

### Linkwarden（opi5p，仍运行）

- 181 条书签、13 个收藏集、1 个 RSS 订阅（`blog.niany.cn`，已在 Miniflux 中）。
- 数据保留：`/var/lib/linkwarden/pre-migration.dump` + PostgreSQL `linkwarden` 库。

### ArchiveBox（opi5p）

- 服务 active，索引为空（0 快照）；UI 用户 `zhyi` 可登录。
- 数据目录 `/mnt/storage/archivebox`，待写入“实在不行”的归档 URL。

### 其他核对

- DNS：无 `freshrss.*` / `linkwarden.*` 残留记录。
- Dex（cnvm）：仍注册 `freshrss`、`linkwarden` 两个 OAuth client，待移除。
- `freshrss.nix`、`linkwarden.nix` 与对应端口常量是复刻新增，作者原版没有。

## 待执行清单

- [ ] 退役配置：移除 `opi5p` 的 Linkwarden 导入与门禁服务；移除 Dex 两个 client；
      删除复刻新增模块文件与端口常量（数据目录不动）。
- [ ] Miniflux：修正 2 个 URL；补入 10 条可用旧 RSSHub 订阅；禁用 3 个不可订阅源。
- [ ] ArchiveBox：把 7 条暂不可用 RSSHub 源主页 + `blog.meimolihan.eu.org`
      加入归档（全新归档，不迁移 Linkwarden 数据）。
- [ ] 部署 `cnvm`、`opi5p` 并实机验证；更新 `fleet-service-chain.md`。
- [ ] 提交并对齐 mac / origin / ml-builder 三方仓库。

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
