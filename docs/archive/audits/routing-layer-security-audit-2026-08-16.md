# 路由层网络安全审计（2026-08-16）

> 审计范围：`nixos-config/` 中与"网络路由层"相关的全部配置，包括边缘路由、overlay 网络 / BGP、DNS、nginx 入口反代与认证策略层。
> 审计方法：静态配置审读（本次不涉及运行态验证，如 `ss -lntup`、nft 规则集实机比对）。
> 结论等级：整体 **良好（B+/A-）**，存在 1 项结构性弱点和若干中低风险项，详见下文。

## 1. 路由层架构概述

该仓库的"路由层"是五层结构，所有边界安全都落在这些层上：

| 层次 | 组成 | 关键文件 |
| --- | --- | --- |
| ① 边缘路由 | 家庭路由器（PPPoE + DNAT 80/443/2222→rock5c）；h28k 远程站点（drop-by-default） | `hosts/router/firewall.nix`、`hosts/h28k/firewall.nix` |
| ② Overlay 网络 | WireGuard mesh（wg-mesh / wstunnel 穿墙）+ ZeroTier + bird2（LTNET 内部 BGP + DN42 外部 BGP + anycast babel） | `nixos/server-apps/wg-mesh.nix`、`nixos/server-apps/bird/` |
| ③ DNS 层 | 权威 CoreDNS + Knot（netns 隔离、anycast、DNSSEC）；客户端递归 CoreDNS / PDNS | `nixos/server-apps/coredns.nix`、`nixos/common-apps/coredns.nix` |
| ④ 入口反代 | 统一 nginx（`lantian.nginxVhosts` DSL），0.0.0.0:80/443/QUIC + 43/70/1965 stream | `nixos/common-apps/nginx/` |
| ⑤ 认证与策略 | pocket-id / Dex → oauth2-proxy → nginx auth_request 认证链；构建期断言强制公网 vhost 认证 | `nixos/minimal-policies/nginx-security.nix`、`nixos/common-apps/nginx/oauth2-proxy.nix` |

安全模型的核心特征：**防火墙不是传统"逐端口放行"，而是"接口前缀分类（WAN/LAN/OVERLAY/DN42）+ IP set（保留网段/DN42/CN）+ 默认放行的黑名单"**。`networking.firewall` 全局关闭，全部由手写 nftables `lantian` 表实现。

## 2. 安全基线（已逐项核实的优点）

### 2.1 入口层（nginx / TLS）

- 仅启用 **TLS 1.2 / 1.3**，无任何弱协议（`nginx.nix:74`）。
- 密码套件全部为 AEAD：GCM + ChaCha20-Poly1305，无 CBC / RC4 / 静态 RSA 套件（`nginx.nix:13-23`）。
- 椭圆曲线含后量子混合曲线 `X25519MLKEM768` / `SecP256r1MLKEM768`（`nginx.nix:29-38`）。
- 常见 vhost 默认注入安全响应头：HSTS（含 `preload`）、`X-Content-Type-Options`、`X-Frame-Options`、`Referrer-Policy` 等，并清除 `X-Powered-By` 类信息泄露头（`vhost-options.nix:289-315`）。
- 默认 vhost：HTTP 301 跳转 HTTPS、HTTPS 兜底 `444`（`vhosts.nix`）。
- 点文件（`.well-known` 除外）默认 403；支持 noindex / robots.txt（`vhost-options.nix:106-110, 333-340`）。
- QUIC 启用 `quic_retry on`（防 UDP 放大）。
- 敏感入口带 `limit_req` 限速（whois、hydra 代理等）。

### 2.2 认证与策略层

- **构建期断言**（`nginx-security.nix:15-21`）：公网 vhost 必须位于 `publicSites` 白名单，或 `/` 位置带 OAuth / BasicAuth，否则 `nixos-rebuild` 直接失败。这是"策略即代码"的强制护栏。
- 抽查验证：白名单中标注"自有认证系统"的 `prometheus.zhyi.xin` 实际也叠加了 OAuth（`optional-apps/prometheus/default.nix:34`），比白名单注释更严格。
- 订阅文件 `/mihomo.yaml`、`/hostdare.yaml` 虽是固定公网路径，但由 sops 注入的 token 门禁保护，未持 token 返回 404（`optional-apps/sublinkpro/default.nix:189-197`）。
- pocket-id 仅监听 unix socket；Dex 仅监听 `127.0.0.1`（`optional-apps/dex.nix`）。
- oauth2-proxy 使用 `code-challenge-method = S256`（PKCE）。

### 2.3 SSH

- 端口 **2222**，`PasswordAuthentication=false`、`KbdInteractiveAuthentication=false`、`PermitRootLogin=prohibit-password`（`ssh-harden.nix:88-110`）。
- 后量子 KEX（`mlkem768x25519-sha256`、`sntrup761x25519` 系列），Ciphers / MACs 均为算法白名单。
- 全网预置 knownHosts（`ssh-harden.nix:47-70`）；22 端口跑 endlessh 诱饵 tarpit。
- 服务端带 XZ 后门 kill-switch 环境变量（`ssh-harden.nix:167-169`）。
- 因禁密码，fail2ban 的 sshd jail 显式关闭（合理）。

### 2.4 DNS

- 权威 CoreDNS 根区 ACL 仅允许保留网段，**防开放递归与 DNS 放大**；DNSSEC 签名密钥由 sops 管理（`server-apps/coredns.nix`）。
- 权威解析器隔离在独立 netns 内，经 bird anycast（198.19.0.254 / 172.20.46.227）宣告。
- 客户端递归按区域分流：CN 走 AliDNS(DoT)、其余走 Google DoT，并屏蔽 B 站 PCDN 域名。

### 2.5 BGP / DN42

- StayRTR 提供 RPKI 校验，BGP import/export 过滤器含 **ROA 校验与 ASN 黑名单**（`server-apps/bird/config/dn42.nix`）。
- BGP peer 的明文配置存放在 sops 加密的 hidden-module 中。

### 2.6 暴露面收敛

- 大量敏感服务绑定 `127.0.0.1` / unix socket / 仅 overlay 可达的 ltnet IP（如 v2ray→unix socket、mihomo→ltnet IP、prometheus exporters→ltnet IPv4）。
- netns 隔离框架（`minimal-components/netns.nix`）：coredns、nginx-proxy、pdns-recursor、yggdrasil 等均隔离在命名空间内。
- h28k 远程站点防火墙为 **input/forward 双 drop-by-default + 显式白名单放行**（`hosts/h28k/firewall.nix:36-79`），WAN 侧仅放行 DHCP 应答、ZeroTier 9993、来自 192.168.0.0/24 的 SSH——教科书级配置。
- 密钥全部由 sops 管理（0400 权限、最小属组）。

## 3. 风险清单（按严重程度排序）

### 3.1 高：服务器与家庭路由器 input 链 policy accept（结构性弱点）

- **位置**：`nixos/minimal-components/firewall.nix:125`（`FILTER_INPUT` policy accept）；`hosts/router/firewall.nix:44`；`networking.firewall` 全局关闭（`nixos/minimal-components/networking.nix:97`）。
- **问题**：`PUBLIC_INPUT` 仅拒绝 Samba(137-139,445)/NFS/CUPS/Rsync 等少量端口，以及 CN 源对 OpenVPN-GameAccel / DN42 端口的访问，**其余一律 accept**。边界安全完全依赖"每个服务都正确绑定到 loopback/socket/ltnet IP"这一约定，没有第二层防线；任何新服务误绑 `0.0.0.0` 即直接暴露公网。
- **对照**：h28k 已采用 drop-by-default，可作迁移样板。
- **建议**：服务器侧逐步迁移为"WAN 口显式放行 + 其余拒绝"；至少在迁移完成前，对 WAN 口增加 uRPF 严格模式。
- **实施（2026-08-16）**：家庭路由器 `hosts/router/firewall.nix` 已迁移为 drop-by-default（WAN 口 ppp0 仅显式放行 ICMP / IPv6 link-local 控制面 / qBittorrent peer 31220，其余丢弃；样板为 h28k）。服务器侧迁移仍为待办。

### 3.2 中高：保留源 IP 信任 + rp_filter=0 → 源伪造绕过面

- **位置**：`firewall.nix:310-313`（lan-access 主机上 `ip saddr @RESERVED_IPV4 return`）；`networking.nix:66-68`（`rp_filter = 0`）。
- **问题**：对带 `lan-access` 标签的主机，从 WAN 口到达、源地址伪造为保留网段（10/8、172.16/12、192.168/16…）的包会跳过黑名单并命中 accept；配合全局 `rp_filter=0`（`checkReversePath=false`），源伪造无内核层拦截。对 TCP 服务利用难度较高，但对依赖"保留源 IP"做 ACL 的 UDP 服务（如权威 DNS 的根区 ACL）影响更直接。
- **建议**：WAN 接口启用 strict uRPF；或在 `FILTER_INPUT` 中对 WAN 口先做源有效性校验（拒绝来自 WAN 的保留源地址）。
- **实施（2026-08-16）**：路由器在 `PUBLIC_INPUT` 与 `FILTER_FORWARD` 对 ppp0 拒绝保留源地址（含 DNAT 路径）；服务器侧未改（涉及公共模块，待单独立项）。

### 3.3 中高：`accessibleBy = "private"` 实际对整个 DN42 网络可达

- **位置**：`helpers/constants/networks.nix:48-60`（reserved 含 `172.16.0.0/12`）；`vhost-options.nix:347-356`（private → allow 保留网段 + deny all）。
- **问题**：DN42 全部地址空间（172.20.x.x 等）落在保留网段内，因此**所有 DN42 参与者**都能访问 `accessibleBy = "private"` 的站点（如 `lab.*`、homepage 等）。对 DN42 运营者这可能是半有意的（仓库本身也对外发布 zhyi.dn42 站点），但"内网级信任"被放大为"整个 DN42 生态级信任"。
- **建议**：若这些站点不需要对全体 DN42 开放，将 allow 列表收窄为自有网段（ltnet /48 + 自有 DN42 /48 + LAN），而非整个 `172.16.0.0/12`。

### 3.4 中：oauth2-proxy 的两个 insecure 开关

- **位置**：`nixos/common-apps/nginx/oauth2-proxy.nix:34-35`。
- **问题**：`insecure-oidc-skip-issuer-verification=true`（不校验 ID token 的 `iss` 声明）、`insecure-oidc-allow-unverified-email=true`。issuer 固定为自托管 `login.zhyi.xin`，JWKS 仍从该 issuer 的 discovery 文档获取，因此实际风险中低；但这两个开关意味着认证链"少验了一层"。
- **建议**：尝试移除 skip-issuer-verification（除非 Dex 的 discovery 文档确实与 issuer-url 不匹配）；如确需保留，在文档中记录原因。

### 3.5 中：`ssl_early_data on`（TLS 0-RTT）

- **位置**：`nginx.nix:52-54`。
- **问题**：0-RTT 允许首包携带应用数据，对反代的非幂等请求（POST 等）存在跨连接重放风险；影响程度取决于各后端语义。对纯静态站无害。
- **建议**：对包含写操作的 vhost/后端关闭 early data，或确认后端对重放有容忍。

### 3.6 中低：家庭路由器启用 miniupnpd

- **位置**：`hosts/router/configuration.nix:61-64`（externalInterface=ppp0）。
- **问题**：任意 LAN 设备（含被入侵的 IoT）可自行在 ppp0 上请求 WAN 端口映射，绕过集中式防火墙策略。
- **建议**：若无刚需（如游戏机联机）请关闭；否则配置 per-device 允许列表。
- **评估（2026-08-16）**：保持开启（对齐作者 lt-home-router 亦启用；本机无 VLAN，白名单化需逐设备 IP，暂不实施），风险接受。

### 3.7 中低：出站 SSH 不验证主机指纹

- **位置**：`ssh-harden.nix:158-162`（`Host *` → `StrictHostKeyChecking no`、`UserKnownHostsFile /dev/null`）。
- **问题**：服务器侧的 knownHosts 钉得很死，但这些主机**发起的出站 SSH**（含 sftp 私钥连接）不验证对端指纹，可被中间人。同一段还 `+ssh-rsa` 放宽了旧算法。
- **建议**：将 outbound 连接改为按主机钉指纹（或至少对含凭据的主机启用 verify-host-key）。

### 3.8 低：次要项

| 项 | 位置 | 说明 |
| --- | --- | --- |
| DN42 OpenVPN 隧道用 `aes-256-cbc` 静态密钥 | `nixos/server-components/dn42/default.nix:243` | CBC 无 AEAD 完整性；主力隧道为 WireGuard，影响有限 |
| 断言仅检查 `locations."/"` | `nginx-security.nix:18` | 子路径可无认证（如 sublinkpro `/c/` 为设计如此）；白名单即绕过点，属"知情信任"机制 |
| `ssl_session_tickets on` | `nginx.nix:48` | 轻微削弱前向保密；nginx 默认每小时轮换票据密钥，影响小 |
| nginx resolver 明文 8.8.8.8 | `nginx.nix:70` | 反代做上游解析时 DNS 元数据明文；影响小 |

## 4. 优先行动建议（如果只做三件事）

1. **服务器侧防火墙迁移到 drop-by-default**：以 h28k 为样板，把 WAN 口改为显式放行 + 其余拒绝，收益最大。
2. **堵住源伪造面**：WAN 接口启用 strict uRPF（或对 WAN 口拒绝保留源地址），配合 rp_filter=0 的现状。
3. **收窄 private 信任域**：将 private vhost 的 allow 列表从整个 `172.16.0.0/12` 改为自有网段。

## 5. 附录：本次审读的关键文件

| 类别 | 文件 |
| --- | --- |
| 全局防火墙 / 网络 | `nixos/minimal-components/firewall.nix`、`networking.nix`、`hosts/router/firewall.nix`、`hosts/h28k/firewall.nix`、`nixos/optional-apps/miniupnpd.nix` |
| nginx 入口 | `nixos/common-apps/nginx/nginx.nix`、`vhosts.nix`、`vhost-options/vhost-options.nix`、`location-options.nix`、`oauth2-proxy.nix`、`whois-server.nix`、`vhost-hydra-proxy.nix`、`nixos/minimal-apps/nginx-proxy.nix` |
| 认证与策略 | `nixos/minimal-policies/nginx-security.nix`、`helpers/constants/public-sites.nix`、`nixos/optional-apps/pocket-id.nix`、`dex.nix`、`glauth.nix`、`sublinkpro/default.nix` |
| SSH | `nixos/minimal-components/ssh-harden.nix`、`endlessh.nix`、`nixos/optional-apps/fail2ban/` |
| Overlay / BGP | `nixos/server-apps/wg-mesh.nix`、`wg-mesh-wstunnel.nix`、`bird/`（default、dn42、sys、common、ltnet、anycast、bgp-flowspec、stayrtr）、`nixos/server-components/dn42/default.nix`、`route-chain.nix`、`nixos/minimal-components/zerotier/` |
| DNS | `nixos/server-apps/coredns.nix`、`nixos/common-apps/coredns.nix`、`powerdns-recursor.nix` |
| 常量与辅助 | `helpers/constants/networks.nix`、`ports.nix`、`interface-prefixes.nix`、`public-sites.nix` |
