# Homepage 卡片与健康检查

Homepage 运行在 `ml-home-vm`。它的服务卡片属于私有配置，实际 YAML 由
`nixos-secrets` 提供；主仓库只负责导入模块、Nginx vhost 与服务本身。因此卡片
内容、认证方式和健康检查 URL 的最终来源不是本文，而是已生成的
`/etc/homepage-dashboard/services.yaml`。

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
   `https://homepage.ml-home-vm.zhyi.cc`，仅从家庭 LAN、LTNET 或 ZeroTier
   访问。卡片链接按服务实际公开边界分组：公开服务使用正式公开域，私有服务
   使用 `服务.承载主机.zhyi.cc`；Attic 仍是例外，固定走 colocrossing 的
   `:8443` 入口。
4. 由 `ml-builder` 构建并部署 `ml-home-vm`，然后在目标主机检查生成结果。

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
