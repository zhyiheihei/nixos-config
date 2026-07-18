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
| `logvm` | 118 | `192.168.2.55` | `cba3cdffbf` | `198.18.0.118` | 对等 `colocrossing` |
| `jpvm` | 117 | 无 | `a073934677` | `198.18.0.117` | 对等 `twvm` |
| `twvm` | 2 | 无 | `94602ea0ad` | `198.18.0.2` | 对等 `colocrossing`、`jpvm`；`jpvm` 为路由反射客户端 |
| `cnvm` | 119 | 无 | `ecd09d7bc2` | `198.18.0.119` | 对等 `twvm`；`cnvm` 为路由反射客户端 |

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
| `*.zhyi.cc` | 默认 CNAME 到 `jp.zhyi.cc` | JPVM `443` Web 入口；主机精确记录优先并保持直连 |
| `*.ml-home-vm.zhyi.cc` | CNAME 到 `jp.zhyi.cc` | JPVM 经 colocrossing LTNET 转发到 `ml-home-vm:8443`，对外只使用标准 `443` |
| `homepage.ml-home-vm.zhyi.cc`、`archivebox.ml-home-vm.zhyi.cc`、`syncthing.ml-home-vm.zhyi.cc`、`halo.ml-home-vm.zhyi.cc`、`linkwarden.ml-home-vm.zhyi.cc`、`excalidraw.ml-home-vm.zhyi.cc`、`freshrss.ml-home-vm.zhyi.cc`、`memos.ml-home-vm.zhyi.cc`、`vertex.ml-home-vm.zhyi.cc` | CNAME 到 `jp.zhyi.cc` | `jpvm:443` 的 TLS SNI 转发至 colocrossing LTNET 入口，再转发到 `ml-home-vm:8443`；正式入口受 OAuth 保护 |
| `ha.zhyi.cc` | CNAME 到 `jp.zhyi.cc` | JP VPS 的 TLS SNI 转发至家庭服务 |
| `hydra.zhyi.cc` | CNAME 到 `jp.zhyi.cc` | Hydra vhost 反代到 `pve-5700u` 的 Hydra 端口 |
| `sub.zhyi.cc` | CNAME 到 `jp.zhyi.cc` | 标准 `443` 经 JP VPS 与 colocrossing 转发至 `ml-home-vm:8443`，订阅地址由本机服务生成并受 OAuth 保护 |
| `attic.zhyi.xin`、`vaults3.zhyi.cc` | CNAME 到 `home-ddns.zhyi.cc` | 高流量缓存数据面和家庭入口 DDNS；Attic URL 为 `https://attic.zhyi.xin:8443/lantian` |
| `colocrossing.zhyi.cc` | 主机 LTNET 地址 | SSH、Colmena 与主机身份，不承担公网 Web 入口命名 |
| `zhyi.xin` | A `101.96.199.157` | CNVM 公网入口 |
| `*.zhyi.xin` | CNAME 到 `cnvm.zhyi.cc` | CNVM 公网入口的兜底记录；`attic` 精确记录优先 |
| `www` 与所有具名 `zhyi.xin` Web 服务 | CNAME 到 `cnvm.zhyi.cc` | CNVM TLS SNI 入口；colocrossing 再按承载主机分发 |
| `jp.zhyi.cc` | A `36.50.85.113` | `jpvm` 自身服务 |
| `tw.zhyi.cc` | `IGNORE` | 由 VPS 地址自行维护 |
| `autoconfig.moliy.site` | CNAME 到 `home-ddns.zhyi.cc` | 家庭公网入口 |

## 局域网覆盖

| 生效主机 | 覆盖关系 | 用途 |
| --- | --- | --- |
| `ml-builder` | `openclash.zhyi.cc -> 192.168.2.51` | 构建机使用迁移后的 MetaCubeXD；`attic.zhyi.xin -> 192.168.2.52` |
| `ml-home-vm` | `openclash.zhyi.cc -> 192.168.2.51` | 本机媒体服务使用 MetaCubeXD；多个基础服务直连 colocrossing `192.168.2.52` |
| `pve-5700u` | `attic.zhyi.xin`、`hydra.zhyi.cc`、`vaults3.zhyi.cc -> 192.168.2.52` | 避免家庭内访问绕经公网 |

MetaCubeXD 对 LAN 保留兼容地址 `192.168.2.51:7892`；控制界面和 Clash API 仅绑定回环地址，并经 `metacubexd.ml-home-vm.zhyi.cc` 的私有 Nginx vhost 访问。Halo 已迁移至 `ml-home-vm`，根域 `zhyi.xin` 经 CNVM 和 colocrossing 转发到该服务。

`zhyi.xin` 的公开入口统一静态指向 `cnvm`，不配置自动故障转移。`jpvm` 与
`twvm` 保留各自独立服务；`twvm` 不承接正常的公开服务流量。

## 清理判定

ZeroTier controller 的授权成员应恰好是主机表中有 ZeroTier ID 的八台主机，加上 secrets 中声明的 `molishanguang-macbook`。`peers.d` 是 ZeroTier 的发现缓存，不是授权成员清单；它由 `zerotierone` 的启动前脚本自动重建，不能据此删除设备。

WireGuard 只应有 `ltnet.peers` 生成的 `wgmesh<index>` 接口，实际可用性以 `wg show` 的最新握手和 `birdc show protocols` 的 `Established` 状态判断。不要通过删除 WireGuard 私钥、公钥或 SOPS 文件来清理失效节点，应先从相应 `host.nix` 的 `ltnet.peers` 拓扑中移除并部署两端。

迁移 SQL 备份至少保留一份经校验的最终快照和仍存在的源数据库。Halo 的 `pre-migration.sql` 已在最终快照与冻结源库校验一致后删除；`final-source-halo.sql` 与 CT 103 的原数据库目前都是恢复点，不应删除。

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
