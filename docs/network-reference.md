# 网络参照

本文件记录当前仓库声明的网络关系。它是排障和新增节点的参照，不存放私钥、令牌或动态公网地址。配置的最终来源仍是各主机的 `host.nix`、`dns/` 与 `nixos/` 模块。

## 地址层次

| 层次 | 作用 | 地址/接口来源 |
| --- | --- | --- |
| 家庭局域网 | 同一 `home-lan` 的直接管理与服务访问 | `hosts/*/host.nix` 中的 `interconnect.IPv4`，网段 `192.168.2.0/24` |
| ZeroTier | 设备可达性与无公网节点之间的 WireGuard 建链 | 网络 `466270de75000001`，接口 `zttalxbxtu` |
| LTNET | 内部服务地址与路由前缀 | `198.18.0.<index>`、`198.18.<index>.0/24`、`fdd8:1938:4e88::<index>` |
| WireGuard mesh | LTNET 的加密点对点传输 | `wgmesh<peer-index>`，UDP `10000 + 本机 index` |
| DN42 | 仅 DN42 节点对外发布的路由 | `172.20.46.224/27`、`fdd8:1938:4e88::/48` |

`interconnect` 优先用于同一局域网的直连。LTNET 的路由由 BIRD 在 WireGuard 链路上交换；ZeroTier 不是 LTNET 的替代品，而是在两个端点都没有可用公网地址时，为 WireGuard 提供可达的底层端点。

## 主机表

| 主机 | index | 家庭局域网 IPv4 | ZeroTier 节点 ID | LTNET IPv4 | WireGuard/LTNET 声明 |
| --- | ---: | --- | --- | --- | --- |
| `ml-builder` | 114 | `192.168.2.50` | `2c86750714` | `198.18.0.114` | 仅最小系统；不声明 server mesh 对等 |
| `ml-home-vm` | 115 | `192.168.2.51` | `c340ae9a91` | `198.18.0.115` | 对等 `colocrossing` |
| `colocrossing` | 18 | `192.168.2.52` | `fd2e98dccf` | `198.18.0.18` | 对等 `logvm`、`ml-home-vm`、`twvm`；`ml-home-vm` 为路由反射客户端 |
| `pve-2700` | 113 | `192.168.2.53` | `214f8619a9` | `198.18.0.113` | 当前没有 server mesh 声明 |
| `pve-5700u` | 116 | `192.168.2.54` | `706ba6d04d` | `198.18.0.116` | 当前没有 server mesh 声明 |
| `jpvm` | 117 | 无 | `a073934677` | `198.18.0.117` | 对等 `twvm` |
| `twvm` | 2 | 无 | `94602ea0ad` | `198.18.0.2` | 对等 `colocrossing`、`jpvm`；`jpvm` 为路由反射客户端 |

ZeroTier 受控节点的静态地址由 index 推导：IPv4 为 `198.18.0.<index>`，IPv6 为 `fdd8:1938:4e88::<index>`。额外客户端仅在 secrets 的 `zerotier-additional-hosts.nix` 中声明，不能在本文件假定其地址。

## WireGuard 与 LTNET

| 项目 | 当前实现 |
| --- | --- |
| 私钥 | 每台启用 mesh 的主机从 `per-host/wg-priv/<hostname>.yaml` 由 SOPS 解密 |
| 公钥 | 由 secrets 的 `wg-pubkey.nix` 提供；不在仓库文档中复制 |
| 对等选择 | 仅 `server` 主机，且双方有 ZeroTier ID；`ltnet.peers` 非空时只建立列表中的对等 |
| 端点选择 | 同一 `interconnect.name` 时走局域网；双方无公网地址时走对端 LTNET/ZeroTier 地址；否则走公网地址 |
| 特例 | `twvm -> colocrossing` 使用 `wg-home.zhyi.cc`，由 colocrossing 的 DDNS 维护 |
| 路由 | BIRD 通过每条 `wgmesh<peer-index>` 链路上的 IPv6 link-local iBGP 交换 LTNET、DN42 与附加路由 |
| 可观察性 | WireGuard exporter 监听本机 LTNET IPv4；BIRD 配置见 `nixos/server-apps/bird/config/ltnet.nix` |

当前 DN42 前缀只由 `colocrossing` 宣告：`172.20.46.224/27` 与 `fdd8:1938:4e88::/48`。不要将家庭局域网前缀加入 DN42 路由。

## 域名与入口

DNSControl 只声明记录；运行时的 `/etc/hosts` 可以在局域网中覆盖解析，优先级高于公网 DNS。`home-ddns.zhyi.cc` 与 `wg-home.zhyi.cc` 在 DNSControl 中标记为 `IGNORE`，由 colocrossing 的 Gcore DDNS 脚本维护。

| 域名/模式 | DNS 声明 | 服务入口/后端 |
| --- | --- | --- |
| `*.zhyi.cc` | 默认 CNAME 到 `home-ddns.zhyi.cc` | 家庭公网入口；具体 TLS SNI 再按反向代理配置分发 |
| `*.ml-home-vm.zhyi.cc` | CNAME 到 `home-ddns.zhyi.cc` | `ml-home-vm` 的私有 HTTPS，标准端口 `8443` |
| `homepage.ml-home-vm.zhyi.cc`、`archivebox.ml-home-vm.zhyi.cc`、`syncthing.ml-home-vm.zhyi.cc` | CNAME 到 `tw.zhyi.cc` | `twvm:443` 的 TLS SNI 转发；未命中本机 SNI 时转发 home DDNS `:8443` |
| `ha.zhyi.cc` | Gcore GEO：`jpvm` 权重 100、`twvm` 权重 1 | 两个 VPS 的 TLS SNI 转发，提供主备公网入口 |
| `hydra.zhyi.cc` | CNAME 到 `tw.zhyi.cc` | Hydra vhost 反代到 `pve-5700u` 的 Hydra 端口 |
| `sub.zhyi.cc` | CNAME 到 `tw.zhyi.cc` | colocrossing vhost 反代至 `ml-home-vm:8443`，订阅地址由本机服务生成 |
| `attic.zhyi.xin` | CNAME 到 `home-ddns.zhyi.cc` | Attic URL 为 `https://attic.zhyi.xin:8443/lantian`；局域网主机显式直连 colocrossing `192.168.2.52` |
| `zhyi.xin`、`www`、`hub`、`hk` | `IGNORE` | DNSControl 不接管，保留现有独立用途 |
| `*.zhyi.xin` | A `101.96.199.157` | 兜底记录；下列 CNAME 例外优先 |
| `ai`、`attic`、`gemini`、`lemmy`、`mail`、`matrix`、`n8n`、`pb`、`rsshub` 等 `zhyi.xin` 服务 | CNAME 到 `home-ddns.zhyi.cc` | 家庭公网入口 |
| `api`、`cal`、`element`、`git`、`id`、`login`、`posts`、`rss`、`stats`、`tools`、`whois` | CNAME 到 `tw.zhyi.cc` | VPS TLS SNI 入口 |
| `jp.zhyi.cc` | A `36.50.85.113` | `jpvm` 自身服务 |
| `tw.zhyi.cc` | `IGNORE` | 由 VPS 地址自行维护 |
| `autoconfig.moliy.site` | CNAME 到 `home-ddns.zhyi.cc` | 家庭公网入口 |

## 局域网覆盖

| 生效主机 | 覆盖关系 | 用途 |
| --- | --- | --- |
| `ml-builder` | `openclash.zhyi.cc -> 192.168.2.51` | 构建机使用迁移后的 MetaCubeXD；`attic.zhyi.xin -> 192.168.2.52` |
| `ml-home-vm` | `openclash.zhyi.cc -> 192.168.2.51` | 本机媒体服务使用 MetaCubeXD；多个基础服务直连 colocrossing `192.168.2.52` |
| `pve-5700u` | `attic.zhyi.xin`、`hydra.zhyi.cc`、`vaults3.zhyi.cc -> 192.168.2.52` | 避免家庭内访问绕经公网 |

MetaCubeXD 对 LAN 保留兼容地址 `192.168.2.51:7892`；控制界面和 Clash API 仅绑定回环地址，并经 `metacubexd.ml-home-vm.zhyi.cc:8443` 的私有 Nginx vhost 访问。Halo 已迁移至 `ml-home-vm`，其私有验证入口为 `halo.ml-home-vm.zhyi.cc:8443`；根域 `zhyi.xin` 当前由 DNSControl 保留，未在本仓库中改写其公网转发。

## 快速核对

```bash
# 节点网络与 WireGuard
ip -4 -brief addr
networkctl status zttalxbxtu
birdc show protocols

# 缓存和内部服务
curl -fsS https://attic.zhyi.xin:8443/lantian/nix-cache-info
curl --resolve halo.ml-home-vm.zhyi.cc:8443:198.18.0.115 -kI \
  https://halo.ml-home-vm.zhyi.cc:8443/

# 配置来源
rg -n 'interconnect|zerotier|ltnet|endpointOverrides' hosts/*/host.nix
rg -n 'home-ddns|publicVpsTarget|CNAME|GEO' dns/domains
```
