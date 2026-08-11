# Homepage 卡片与健康检查

Homepage 运行在 `rock5c`，正式入口为
`https://homepage.rock5c.zhyi.cc`。它的服务卡片属于私有配置，实际 YAML 由
`nixos-secrets` 提供；主仓库只负责导入模块、Nginx vhost 与服务本身。因此卡片
内容、认证方式和健康检查 URL 的最终来源不是本文，而是已生成的
`/etc/homepage-dashboard/services.yaml`。

## 个人导航功能

Homepage 同时作为个人导航页使用。Bing 搜索栏、Quick Launch、常用站点书签与
服务卡片一起配置在 `nixos-secrets` 的 `homepage-dashboard-config.nix`；主仓库
只负责导入模块、Nginx vhost 与服务本身。

## 监控资源卡片

`17 · 私有 · 监控 · 主机资源` 分组为每台非 `client` 主机生成一张卡片，通过
Homepage 的 `prometheusmetric` widget 展示 node exporter 的 CPU、内存与磁盘
占用。数据源是 colocrossing 上仅供私网访问的只读 Prometheus API
`https://prometheus.colocrossing.zhyi.cc`，vhost 在
`hosts/colocrossing/configuration.nix` 中声明为 `accessibleBy = "private"`，
不叠加 OAuth，不暴露到公网。rock5c 在
`hosts/rock5c/home-lan-edge.nix` 中把该域名固定解析到 colocrossing 的 LTNET
地址，避免 Homepage 走公网入口被私网 ACL 拒绝。

`18 · 私有 · 监控 · NAS 存储` 分组将 opi5p 挂载的 QNAP NFS
（`192.168.0.40:/nixos`）作为 NAS 主机展示，指标来自 node exporter 的
`node_filesystem_*` 系列。

## 2026-08-11 卡片核对

对照 `nixos-secrets` 的 `homepage-dashboard-config.nix` 与
[`fleet-service-chain.md`](../infrastructure/fleet-service-chain.md)
复核了全部 12 个服务分组。完整服务清单、入口和账号/口令线索统一记录在
[`fleet-service-chain.md`](../infrastructure/fleet-service-chain.md)
的“服务登录速查”，本页只保留协议型服务的核对结论：

| 服务 | Homepage 卡片 | 账号与口令线索 |
| --- | --- | --- |
| WebDAV（webdev） | `08 · 私有 · 家庭服务` 分组有 `WebDAV` 卡片，链接 `https://dav.opi5p.zhyi.cc`，描述为 Basic Auth；协议端点无 `siteMonitor` | Basic Auth 账号 `zhyi`，口令 `default-pw` |
| SMTP | 无卡片（出站邮件服务，无 Web UI） | 用户名 `EjG9ROGAei`，口令 `common/smtp.yaml` 的 `smtp-pass` |
| SFTP | 无卡片（无 Web UI，只允许公钥登录） | 用户 `sftp`，无密码，私钥 `common/sftp.yaml` 的 `sftp-privkey` |

SMTP、SFTP、Samba、NFS 等协议服务按“没有 Web UI 的协议、后端和自动化服务
不添加虚假卡片”的规则不生成卡片；WebDAV 卡片保持可访问。

实机复核（2026-08-11）：`https://homepage.rock5c.zhyi.cc/` 返回 HTTP 200；
`https://dav.opi5p.zhyi.cc/` 未带凭据返回 401，符合卡片描述的 Basic Auth。

## 保持与作者一致的结构

- 用户卡片链接使用服务的正式访问域名，不使用 `localhost`、内网 IP 或容器端口。
- 每项可监测 Web 服务都有独立的本机 `*.localhost` vhost 或私有健康端点，避免
  健康检查经过公网 DNS、NAT 回环、TLS 和 OAuth 后产生误报。
- 正式入口仍按照 `public`、`private` 与应用自身认证划分访问边界；监测地址不应
  成为对外访问入口。
- 没有 Web UI 的协议、后端和自动化服务不添加虚假卡片。对外 API 可只显示状态
  卡片，不暗示存在完整 Web 界面。

## 修改卡片

1. 先确认服务模块确实导出了正式 vhost 与适合的内部检查地址。
2. 在 `nixos-secrets` 的 Homepage 配置中添加或修改卡片。不要把 token、Basic
   Auth 密码或私有管理地址写入本仓库。
3. Homepage 按作者结构使用承载主机域名，正式入口为
   `https://homepage.rock5c.zhyi.cc`，仅从家庭 LAN、LTNET 或 ZeroTier
   访问。卡片链接按服务实际公开边界分组：公开服务使用正式公开域，私有服务
   使用 `服务.承载主机.zhyi.cc`；Attic 仍是例外，固定使用
   `https://attic.zhyi.xin/lantian`，实际入口位于 cnvm。
4. 由 `ml-builder` 构建并部署 `rock5c`，然后在 ROCK 5C 检查生成结果。只修改
   Homepage 卡片时仍需确认对应后端主机没有迁移。

## 检查生成的监测项

```bash
awk '
  /^  - [^:]+:$/ {
    name = $0
    sub(/^  - /, "", name)
    sub(/:$/, "", name)
  }
  /siteMonitor:/ {
    url = $0
    sub(/^.*siteMonitor: /, "", url)
    print name "\t" url
  }
' /etc/homepage-dashboard/services.yaml
```

对单项健康检查使用其承载机执行 `curl -k -fsS <siteMonitor-url>`。认证入口的
`401` 或 `302` 需要结合服务设计判断，不应仅因不是 `200` 就改成绕过认证。

## 公开入口复核

从符合该服务访问边界的网络测试正式链接：公开服务从公网，私有服务从家庭 LAN
或 ZeroTier。重点确认链接指向正确的入口主机，而不是将暂时可达的内网地址固化
到 Homepage。
