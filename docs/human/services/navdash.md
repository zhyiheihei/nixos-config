# Navdash 个人服务门户（nav.zhyi.xin）

个人导航门户，公开域名 `https://nav.zhyi.xin`，宿主 `tencent`。服务卡片**不由
人工维护**，由 Nix 在求值期从全集群 nginx vhost 定义自动收集生成；登录为
**应用原生 OIDC**（Dex，授权码 + PKCE），nginx 层不叠加 OAuth2 Proxy。

- 源码：github.com/zhyiheihei/navdash（MIT；Go 标准库单二进制 + 无构建
  前端；视觉复刻 DeepSeek Harness 官网设计 token，Host Grotesk/DM Sans 自托管）
- 端口：`LT.portStr.Navdash = 13833`，仅监听 127.0.0.1
- 二进制：`inputs.zhyi-packages.packages.x86_64-linux.navdash`

## OIDC 匹配关系

| 项 | 值 |
| --- | --- |
| Dex client id | `navdash` |
| Dex client secret | `common/dex.yaml` 的 `dex-navdash-secret` |
| session 签名密钥 | `common/personal-apps.yaml` 的 `navdash-session-key` |
| issuer | `https://login.zhyi.xin` |
| 回调 | `https://nav.zhyi.xin/auth/callback` |
| 流 | authorization code + PKCE S256（code_challenge 存签名 cookie） |
| 身份字段 | `preferred_username`（白名单 `NAVDASH_ALLOWED_USERS=zhyi`） |
| session | HMAC 签名无状态 cookie，7 天，HttpOnly+Secure+SameSite=Lax |

## 卡片数据流

```text
Nix 求值期：optional-apps/navdash.nix
  复用 homepage.nix 收集逻辑（全集群 vhost，cheap 字段）
  + accessibleBy → entries.json（pkgs.formats.json 生成，进 store）
        ↓ 挂载为 NAVDASH_ENTRIES
后端 /api/entries：匿名 → 仅 public；登录 → public + private
前端：卡片网格按 host 分组，搜索实时过滤，主题亮/暗切换
```

收集规则与 `optional-apps/homepage.nix` 完全同源（排除
`_` 开头/通配符/`www.`、`.localhost` 仅本机、去重、按 URL 排序），
差异仅在输出形态与附加 `accessibleBy` 字段。

## 卡片分组与监控卡片

- **语义分组**：卡片按「公开 = `zhyi.xin`（主公开域）/ 私有 = `zhyi.xin`
  内网与 `.localhost`」两层分组，前端在组内再按 `serviceCategories` 的
  功能域（内容与通讯 / 身份链路 / AI 链路 / 媒体链路 / 基础设施与运维 /
  存储与证书 / 家庭服务 / 媒体与下载 等）分子节；主机根域
  （`<host>.zhyi.xin` / `lab.<host>.zhyi.xin`）统一归「基础设施与运维」。
- **监控卡片**：每台受监控主机一张 prometheusmetric 卡片（node exporter
  CPU/内存），数据经 `/api/metrics` 从 tencent 本机 Prometheus 拉取，
  仅登录可见。排除带 `client` 标签的主机（不开 node exporter），以及
  bring-up 阶段（manualDeploy）无抓取数据的主机（h28k/opi03/taishanpi）——
  它们的查询返回空 result，卡片会显示误导性的 0%。

## 部署与维护

- 模块：`nixos/optional-apps/navdash.nix`，启用开关
  `lantian.navdash.enable`（tencent 已启用）。
- 更新版本：navdash 仓打新 tag → zhyi-packages `nix run .#update`
  （失败保留旧条目）→ nixos-config `nix flake update zhyi-packages`。
- 服务状态：`systemctl status navdash`、`journalctl -u navdash`、
  `curl -s http://127.0.0.1:13833/healthz`。
- publicSites 登记：`helpers/constants/public-sites.nix`
  *Has own authentication system* 区（nginx-security 断言要求）。

## 已知边界

- `.localhost` 条目不下发（门户公网，无意义）；浏览器主页仍为
  `homepage.localhost`（内网静态页），暂不切换。
- 匿名可浏览的仅 `public` vhost 清单；`private` 入口（内网服务）
  登录后可见。
