# 域名与服务编排

最后整理：2026-07-19

本仓库保留三个自有域名。对应作者的三域结构，但使用当前实际入口与服务位置。

| 自有域名 | 对应作者职责 | 适用内容 | 公网入口 |
| --- | --- | --- | --- |
| `zhyi.cc` | `lantian.pub` | 基础设施、主机名、家庭内部服务 | jpvm 或家庭 DDNS |
| `zhyi.xin` | `xuyh0120.win` | 面向用户的应用与身份服务 | cnvm:443 |
| `moliy.site` | `ltn.pw` | 个人/附属站点 | 保持现有用途 |

## 入口路径

### `zhyi.xin`

所有已命名的应用记录统一 CNAME 到 `cnvm.zhyi.cc`。CNVM 只做 TLS 四层透传：

```text
客户端 -> cnvm:443 -> colocrossing LTNET:443 -> SNI 对应服务
```

colocrossing 本机承载 Attic、Dex、Gitea、Matrix、Pocket ID、RSS 等服务；SNI 为
`ai`、`bitwarden`、`filebox`、`index`、`index-helper`、`sso` 和 `n8n` 的请求继续
转发到 `ml-home-vm`。这样 DNS 不再把同一域名的一部分服务绕过 CNVM 直连家庭 DDNS。

### `zhyi.cc`

`zhyi.cc` 承载主机和基础设施名称。`hydra`、`netbox`、`sub` 与选择性家庭入口通过
`jp.zhyi.cc` 进入；其余 `*.ml-home-vm.zhyi.cc` 和未单独声明的家庭名称保留家庭
DDNS 回源。这样缓存、构建和家庭高流量服务无需经 CNVM。

### `moliy.site`

该域名的根站不参与基础设施迁移，避免覆盖个人用途。目前仓库仅声明
`autoconfig.moliy.site -> home-ddns.zhyi.cc`。

## 维护约束

- 新的公开用户应用优先使用 `<service>.zhyi.xin`，并在 colocrossing 的 SNI
  分发中声明其真实承载机。
- 新的基础设施、主机和仅私有服务优先使用 `<service>.<host>.zhyi.cc`。
- 不再新增 `lantian.pub`、`xuyh0120.win` 或 `ltn.pw` 入口；遗留引用按服务启用
  状态分批替换，涉及 OAuth、Matrix、邮件或应用回调 URL 时必须连同服务配置一起改。
- DNS 修改与入口机 SNI 修改必须同一批发布，避免 CNAME 已切换但后端未分发。
