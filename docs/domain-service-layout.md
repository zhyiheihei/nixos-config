# 域名与服务编排

最后整理：2026-07-24

本仓库保留三个自有域名。对应作者的三域结构，但使用当前实际入口与服务位置。

| 自有域名 | 对应作者职责 | 适用内容 | 公网入口 |
| --- | --- | --- | --- |
| `zhyi.xin` | `lantian.pub` 与作者公开应用 | 主公开域：面向用户的应用、身份与协作服务 | colocrossing:443；身份服务由 cnvm 直接承载 |
| `zhyi.cc` | 主机与互联命名职责 | 基础设施、主机名、私有服务 | 按实际承载主机或基础设施入口解析 |
| `moliy.site` | `ltn.pw` | 个人/附属站点 | 保持现有用途 |

## 入口路径

### `zhyi.xin`

`zhyi.xin` 是本部署的主公开域。大多数应用记录 CNAME 到
`colocrossing.zhyi.cc`。服务在 colocrossing 本机运行时由本机 Nginx 直接提供；
服务在 `ml-home-vm` 运行时，由 colocrossing 保留原始 Host 和 SNI 反向代理：

```text
客户端 -> colocrossing:443 -> 本机服务
客户端 -> colocrossing:443 -> ml-home-vm LTNET:443 -> 家庭服务
```

CNVM 本机承载 Dex、Pocket ID、Vaultwarden 与 Attic，它们的 DNS 直接指向
`cnvm.zhyi.cc`。colocrossing 承载 Gitea、Matrix、RSS、AI 和监控等服务。
`asf`、`books`、`filebox`、`immich`、`index`、`index-helper`、`jellyfin` 与
`tachidesk` 保持作者的独立公开域名形态，但实际服务位于 `ml-home-vm`，因此由
colocrossing 转发。

`attic.zhyi.xin` 是例外：它 CNAME 到 `cnvm.zhyi.cc`，由 cnvm 本机 Nginx
直接服务。Attic 与其 `vaults3.zhyi.cc` S3 后端分离：VaultS3 位于家庭网络
（`home-ddns.zhyi.cc`），Attic 服务端通过公网访问它。客户端统一使用
`https://attic.zhyi.xin/lantian` 作为 substituter URL（标准 443 端口）。

### `zhyi.cc`

`zhyi.cc` 承载主机和基础设施名称。主机记录由 `host-recs.nix` 根据每台主机的
公网、LTNET、DN42 与互联地址生成；`*.主机.zhyi.cc` 跟随对应主机记录。作者采用
主机子域名的私有服务继续使用 `服务.主机.zhyi.cc`，例如
`homepage.ml-home-vm.zhyi.cc`、`metapi.colocrossing.zhyi.cc` 和
`uni-api.jpvm.zhyi.cc`。这些名字不应为了公网可达而另建同名的
`服务.zhyi.xin` 入口。

基础设施的独立正式域名保持作者原有形态，例如 `dashboard.zhyi.cc`、
`prometheus.zhyi.cc` 和 `ai-api.zhyi.cc`。`vaults3.zhyi.cc` 指向家庭 DDNS，
专用于 S3 存储后端；`colocrossing.zhyi.cc` 保持主机直连记录。

### `moliy.site`

该域名的根站不参与基础设施迁移，避免覆盖个人用途。目前仓库仅声明
`autoconfig.moliy.site -> home-ddns.zhyi.cc`。

## 维护约束

- 先在作者原版确认服务是独立公开域名还是主机子域名，再决定当前名称；不能只凭
  服务用途猜测公开性。
- 作者的独立公开用户应用使用 `<service>.zhyi.xin`，并在 colocrossing 声明实际
  承载机；作者的主机私有服务使用 `<service>.<host>.zhyi.cc`。
- `helpers/constants/public-sites.nix`、vhost 的 `accessibleBy`/认证设置与 DNS
  必须一起审计。Gitea 等带自身认证的服务仍然是公开服务，不能仅因需要登录就改成
  主机私有域名。
- SSH、Colmena、LTNET 与 DDNS 使用的主机名必须保持直接地址记录，不能套用 Web
  服务通配符入口。
- 不再新增 `lantian.pub`、`xuyh0120.win` 或 `ltn.pw` 入口；遗留引用按服务启用
  状态分批替换，涉及 OAuth、Matrix、邮件或应用回调 URL 时必须连同服务配置一起改。
- DNS 修改与入口机 SNI 修改必须同一批发布，避免 CNAME 已切换但后端未分发。
