# 域名与服务编排

最后整理：2026-07-19

本仓库保留三个自有域名。对应作者的三域结构，但使用当前实际入口与服务位置。

| 自有域名 | 对应作者职责 | 适用内容 | 公网入口 |
| --- | --- | --- | --- |
| `zhyi.xin` | `lantian.pub` | 主公开域：面向用户的应用、身份与协作服务 | cnvm:443 |
| `zhyi.cc` | 主机与互联命名职责 | 基础设施、主机名、家庭内部服务 | Web 经 jpvm:443；主机记录直连 |
| `moliy.site` | `ltn.pw` | 个人/附属站点 | 保持现有用途 |

## 入口路径

### `zhyi.xin`

`zhyi.xin` 是本部署的主公开域。所有已命名的应用记录统一 CNAME 到
`cnvm.zhyi.cc`。CNVM 只做 TLS 四层透传：

```text
客户端 -> cnvm:443 -> colocrossing LTNET:443 -> SNI 对应服务
```

CNVM 本机承载 Dex、Pocket ID 与 Vaultwarden；colocrossing 承载 Gitea、Matrix、RSS
等服务。SNI 为 `ai`、`filebox`、`index`、`index-helper` 和 `n8n` 的请求继续转发到
`ml-home-vm`。这样 DNS 不再把同一域名的一部分服务绕过 CNVM 直连家庭 DDNS。

`attic.zhyi.xin` 是例外：它直接 CNAME 到 `home-ddns.zhyi.cc`，不经 CNVM。
Attic 与其 `vaults3.zhyi.cc` 数据面流量较大，固定由 colocrossing 的家庭出口承载，
避免占用低配公网入口的带宽与连接资源。

### `zhyi.cc`

`zhyi.cc` 承载主机和基础设施名称。所有 Web 服务记录，包括通配符和
`*.ml-home-vm.zhyi.cc`，统一通过 `jp.zhyi.cc:443` 进入，再由 colocrossing 按 SNI
分发。主机管理记录仍指向各主机的公网、LTNET 或 DDNS 地址，不经过 JPVM；这是
作者将服务 CNAME 与主机地址记录分离的做法。`attic.zhyi.xin` 和
`vaults3.zhyi.cc` 指向家庭 DDNS，专用于缓存数据面；`colocrossing.zhyi.cc`
保持主机直连记录。

### `moliy.site`

该域名的根站不参与基础设施迁移，避免覆盖个人用途。目前仓库仅声明
`autoconfig.moliy.site -> home-ddns.zhyi.cc`。

## 维护约束

- 新的公开用户应用优先使用 `<service>.zhyi.xin`，并在 colocrossing 的 SNI
  分发中声明其真实承载机。
- 新的基础设施和私有 Web 服务优先使用 `<service>.<host>.zhyi.cc`，并经 JPVM 的
  标准 443 入口访问；不要在对外链接中暴露源站的 8443 端口。
- SSH、Colmena、LTNET 与 DDNS 使用的主机名必须保持直接地址记录，不能套用 Web
  服务通配符入口。
- 不再新增 `lantian.pub`、`xuyh0120.win` 或 `ltn.pw` 入口；遗留引用按服务启用
  状态分批替换，涉及 OAuth、Matrix、邮件或应用回调 URL 时必须连同服务配置一起改。
- DNS 修改与入口机 SNI 修改必须同一批发布，避免 CNAME 已切换但后端未分发。
