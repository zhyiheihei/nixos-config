# FlClash 与家庭 / LTNET 拓扑兼容方案

> 日期：2026-08-12。对象：Mac 上的 FlClash TUN 与当前家庭/LTNET 网络。

## 背景

`bt.router.zhyi.cc` 在 FlClash 开启时出现 404。服务端排查结论：

- router 上 nginx vhost 与 qBittorrent WebUI 均正常，LAN、LTNET 路径都返回 200。
- DNSControl preview 为 0 corrections，公网权威 DNS 与仓库配置一致。
- 根因在 FlClash：TUN fake-ip 模式把 `*.zhyi.cc` 也 fake-ip 化，系统 DNS 返回
  `100.127.0.79`（fake-ip），部分应用/浏览器按该 IP 走了错误路径。

当前 FlClash 活跃配置的关键值：

```yaml
dns:
  respect-rules: false
  enhanced-mode: fake-ip
  fake-ip-range: 100.127.0.1/16
  fake-ip-filter:
    - "*.lan"
    - "localhost.ptlogin2.qq.com"
rules:
  - "DOMAIN-SUFFIX,zhyi.cc,DIRECT"
  - "IP-CIDR,198.18.0.0/15,DIRECT,no-resolve"
  - "IP-CIDR,192.168.0.0/16,DIRECT,no-resolve"
```

直连规则本身已存在，但 `fake-ip-filter` 没有覆盖家庭域名，且
`respect-rules: false` 让 DNS 解析不遵循规则，因此产生冲突。

## 推荐配置

在 FlClash 的全局 DNS/覆写配置中调整，或对当前 profile 增加以下 override：

可直接参考 [flclash-home-override.yaml](./flclash-home-override.yaml)。

```yaml
dns:
  respect-rules: true
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "*.zhyi.cc"
    - "*.zhyi.xin"
    - "*.zhyi.dn42"
    - "localhost.ptlogin2.qq.com"
  nameserver-policy:
    "*.zhyi.cc":
      - "https://dns.alidns.com/dns-query"
      - "https://doh.pub/dns-query"
    "*.zhyi.xin":
      - "https://dns.alidns.com/dns-query"
      - "https://doh.pub/dns-query"
```

规则保持放在 `MATCH` 之前：

```yaml
rules:
  - "DOMAIN-SUFFIX,zhyi.cc,DIRECT"
  - "DOMAIN-SUFFIX,zhyi.xin,DIRECT"
  - "DOMAIN-SUFFIX,zhyi.dn42,DIRECT"
  - "IP-CIDR,192.168.0.0/16,DIRECT,no-resolve"
  - "IP-CIDR,198.18.0.0/15,DIRECT,no-resolve"
  - "IP-CIDR,198.19.0.0/16,DIRECT,no-resolve"
  - "IP-CIDR6,fdd8:1938:4e88::/48,DIRECT,no-resolve"
  - "IP-CIDR6,fc00::/7,DIRECT,no-resolve"
  - "GEOIP,CN,DIRECT,no-resolve"
  - "MATCH,PROXY"
```

`198.19.0.0/16` 是 LTNET 内部递归/权威 DNS 使用的备用段，放行后
`dig @198.19.0.253` 等工具不会被 TUN 劫持。

## 验证

配置生效后应满足：

```bash
# 不再返回 100.127.x fake-ip
dig +short bt.router.zhyi.cc
# 期望：198.18.0.112

# 页面恢复 200
curl -k -sS -o /dev/null -w '%{http_code}\n' https://bt.router.zhyi.cc/
```

若 FlClash UI 每次重启都会覆盖全局 DNS 设置，优先把上述内容写进 profile
的 `dns`/`rules` 段或 FlClash 的“全局扩展配置”，而不是只改运行时
`config.yaml`。
