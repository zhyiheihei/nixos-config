# 2026-08-16 上游对齐增量登记：navdash 个人门户

## 变更概述

新增个人服务门户 **navdash**（`nav.zhyi.xin`，宿主 `tencent`）。上游
（xddxdd/nixos-config）无此服务，属**复刻特有新增**，不是对上游模块的偏离。

- 源码仓：`github.com/zhyiheihei/navdash`（MIT，Go 标准库单二进制 +
  无构建前端，DSH 官网风格设计 token 复刻）
- 包：`zhyi-packages` 的 `pkgs/uncategorized/navdash`（nvfetcher 拉
  `v0.1.0`，`vendorHash = null`）
- 模块：`nixos/optional-apps/navdash.nix`（`options.lantian.navdash`，
  默认不启用）
- 认证：**应用原生 OIDC**（Dex `login.zhyi.xin`，authorization code +
  PKCE），不走 nginx oauth2-proxy；Dex staticClient `id=navdash`
- 卡片数据：求值期复用 `optional-apps/homepage.nix` 的全集群 vhost
  收集逻辑，每条附 `accessibleBy`；匿名仅下发 `public` 条目，登录后全量
- 端口：`Navdash = 13833`（13830 已被 qBitTorrentSeedbox.WebUI 占用）
- DNS：`nav.zhyi.xin` CNAME → `tencent.zhyi.cc.`
- secrets：`common/dex.yaml` 新增 `dex-navdash-secret`，
  `common/personal-apps.yaml` 新增 `navdash-session-key`（均随机 64 hex）

## 与上游关系的判断依据

1. 上游 `nixos/optional-apps/` 无同名/同功能模块（homepage 为静态页，
   本仓已对齐为同款静态页 `homepage.localhost`，保持不动）。
2. 作者体系的公开服务导航页就是 `homepage.localhost`（浏览器主页，内网）；
   本仓额外要一个**公网可达、登录后看全量**的门户，是复刻特有需求。
3. `nixos/minimal-policies/nginx-security.nix` 的「公开 vhost 必须有认证」
   断言通过 `helpers/constants/public-sites.nix` 的
   *Has own authentication system* 区登记（`nav.zhyi.xin`），与
   `dashboard.zhyi.xin`（Grafana）、`login.zhyi.xin`（Dex）同类：
   认证在应用层，nginx 不叠加 OAuth。
4. `homepage.localhost`（浏览器主页）按用户决策**暂不切换**到新门户，
   保留现状。

## 复用的公共逻辑（保持单一来源）

卡片收集逻辑与 `optional-apps/homepage.nix` 同源（同一过滤规则、同一
POSIX 正则拆分说明）。刻意未把 homepage.nix 的收集部分抽成公共函数：
两个模块的输出形态（HTML 内联 vs JSON 独立产物）与附加字段
（`accessibleBy`）不同，抽象收益低且增加公共模块耦合；若将来第三处
需要同一数据，再抽取到 `helpers/`。
