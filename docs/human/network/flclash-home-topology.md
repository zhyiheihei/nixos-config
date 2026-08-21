# FlClash 与家庭 / LTNET 拓扑兼容方案

> 日期：2026-08-12。对象：Mac 上的 FlClash TUN 与当前家庭/LTNET 网络。

## 背景

`bt.router.zhyi.xin` 在 FlClash 开启时出现 404。服务端排查结论：

- router 上 nginx vhost 与 qBittorrent WebUI 均正常，LAN、LTNET 路径都返回 200。
- DNSControl preview 为 0 corrections，公网权威 DNS 与仓库配置一致。
- 根因在 FlClash：TUN fake-ip 模式把 `*.zhyi.xin` 也 fake-ip 化，系统 DNS 返回
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

## 官方依据

- Mihomo 官方 DNS 文档：<https://wiki.metacubex.one/config/dns/>
  - `fake-ip-filter`：命中列表的域名不会下发 fake-ip 映射，支持 `*.zhyi.xin`
    这类域名通配。
  - `nameserver-policy`：指定域名的解析服务器，优先于 nameserver/fallback。
  - `respect-rules`：DNS 连接遵守路由规则。
- FlClash 官方源码：`lib/views/config/dns.dart` 提供 fake-ip-filter、
  nameserver-policy、respect-rules、fake-ip-range 的官方 UI 编辑项；
  `lib/views/config/rules.dart` 提供“全局规则”页面。

## 推荐配置（FlClash UI）

不要在 FlClash 运行目录里直接改 `config.yaml` 或 `database.sqlite`，这些会在
应用重启时被 FlClash 重新生成。按官方 UI 配置：

1. FlClash → 设置 → DNS（必要时先打开 “Override DNS / 覆写 DNS”）。
2. `fake-ip-filter` 增加：
   - `*.zhyi.xin`
   - `*.zhyi.xin`
   - `*.zhyi.dn42`
   - `*.local`
3. `nameserver-policy` 增加：
   - `*.zhyi.xin` → `https://dns.alidns.com/dns-query`
   - `*.zhyi.xin` → `https://dns.alidns.com/dns-query`
4. 打开 `respect-rules`。
5. 把 `fake-ip-range` 从默认的 `198.18.0.1/16` 改为不与内网重叠的网段，例如
   `28.0.0.1/16`。默认段正好落在 LTNET `198.18.0.0/15` 内，会与真实内网地址
   冲突。
6. FlClash → 规则 → 添加全局直连规则（保持放在 MATCH 之前）。

也可参考 [flclash-home-override.yaml](flclash-home-override.yaml) 作为
profile/扩展配置的对照内容，但优先使用 FlClash UI。

```yaml
dns:
  respect-rules: true
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "*.zhyi.xin"
    - "*.zhyi.xin"
    - "*.zhyi.dn42"
    - "localhost.ptlogin2.qq.com"
  nameserver-policy:
    "*.zhyi.xin":
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
dig +short bt.router.zhyi.xin
# 期望：198.18.0.112

# 页面恢复 200
curl -k -sS -o /dev/null -w '%{http_code}\n' https://bt.router.zhyi.xin/
```

若 FlClash UI 每次重启都会覆盖全局 DNS 设置，优先把上述内容写进 profile
的 `dns`/`rules` 段或 FlClash 的“全局扩展配置”，而不是只改运行时
`config.yaml`。
