# 网络参照

本文件记录当前仓库声明的网络关系。它是排障和新增节点的参照，不存放私钥、令牌或动态公网地址。配置的最终来源仍是各主机的 `host.nix`、`dns/` 与 `nixos/` 模块。

## 地址层次

| 层次 | 作用 | 地址/接口来源 |
| --- | --- | --- |
| 家庭局域网 | 同一 `home-lan` 的直接管理与服务访问 | `hosts/*/host.nix` 中的 `interconnect.IPv4`；当前统一使用 `192.168.0.0/24`（Router VM 后，MTU 9000） |
| H28K 站点局域网 | 当前嵌套测试、以后迁往异地的独立 LAN | `192.168.30.0/24`；`h28k` 为 `192.168.30.1`，WAN 使用 DHCP |
| ZeroTier | 设备可达性与无公网节点之间的 WireGuard 建链 | 网络 `466270de75000001`，接口 `zttalxbxtu` |
| LTNET | 内部服务地址与路由前缀 | `198.18.0.<index>`、`198.18.<index>.0/24`、`fdd8:1938:4e88::<index>` |
| WireGuard mesh | LTNET 的加密点对点传输 | `wgmesh<peer-index>`；本机 UDP 端口为 `10000 + 本机 index` |
| DN42 | 仅 DN42 节点对外发布的路由 | `172.20.46.224/27`、`fdd8:1938:4e88::/48` |

`interconnect` 优先用于同一局域网的直连。LTNET 的路由由 BIRD 在 WireGuard 链路上交换；ZeroTier 不是 LTNET 的替代品，而是在两个端点都没有可用公网地址时，为 WireGuard 提供可达的底层端点。

## 家庭 LAN 静态分配

家庭网络统一使用 `192.168.0.0/24`。Router VM 直连光猫并作为 `192.168.0.1` 网关，PVE 的 `br-lan` 将物理设备和 VM 接入同一 LAN。基础设施使用 DHCP 池外的静态地址，Router 的 DHCP 池为 `192.168.0.100-249`。

| Address | Host | Status |
| --- | --- | --- |
| `192.168.0.1` | `router` VM | 网关 / NAT / DDNS |
| `192.168.0.2` | `pve-5700u` | PVE 宿主 |
| `192.168.0.40` | QNAP NAS | NFS 与 S3 存储 |
| `192.168.0.41` | `fn-os` (PVE VM 101) | 飞牛 NAS / NFS 客户端 |
| `192.168.0.50` | `ml-builder` | 强构建机 / Hydra |
| `192.168.0.51` | `ml-home-vm` | 已退役（2026-08-03）；地址保留 |
| `192.168.0.53` | `ml-2700` | 客户端 |
| `192.168.0.54` | `macmini` | Mac mini（M4）客户端；nix-darwin 管理 |
| `192.168.0.55` | `ml-laptop` | 物理笔记本客户端 |
| `192.168.0.62` | `opi5p` | RK3588 应用与数据节点 |
| `192.168.0.63` | `opi5p` (lan1) | 备用网口救援地址（lan0 主地址为 .62，无默认路由） |
| `192.168.0.64` | `rock5c` | RK3588 边缘与控制节点 |
| `192.168.0.65` | `lubancat1` | RK3566 适配节点 |
| `192.168.0.104` | `cam-bedroom` | 乐橙卧室摄像头（Kea 静态预留，RTSP/ONVIF） |
| `192.168.0.115` | `cam-livingroom` | 乐橙客厅摄像头（Kea 静态预留，RTSP/ONVIF） |

### H28K 站点 LAN

H28K 管理独立的 `192.168.30.0/24`，它不是家庭 `home-lan` 的扩展。设备暂放家中调试时，WAN 口 `eth1` 从家庭 Router 的 `192.168.0.0/24` 动态取址；LAN 口 `eth0` 始终保持以下规划，因此以后迁到异地不需要重新编号。

| Address/range | 用途 |
| --- | --- |
| `192.168.30.1` | `h28k` LAN 网关、DHCP 与 DNS |
| `192.168.30.2-99` | 站点静态基础设施预留 |
| `192.168.30.100-249` | Kea DHCP 池 |
| `192.168.30.250-254` | 网络设备与救援地址预留 |

正式加入 ZeroTier 后，`h28k` 以 LTNET `198.18.0.125` 承载 `192.168.30.0/24` 的附加路由；该前缀不得发布到 DN42。

### 分配备注

- `router`、`opi5p`、`rock5c`、`fn-os`（PVE VM 101）的 NFS 挂载源为 `192.168.0.40:/nixos`；`fn-os` 在 `/vol1/1000/Photos` automount。
- ARM 板卡统一从 `192.168.0.60` 起分配静态地址，不占用原 VM 地址。
- 部署 `router`/`opi5p`/`rock5c`/`fn-os` 前需在 QNAP NFS export 中放行对应客户端地址（`fn-os` 为 `192.168.0.41`）。
- Router VM 提供 IPv6 RA 广播，VM 通过 SLAAC 获取 IPv6 地址。
- `greencloud` 已迁移到 SG 公网节点，不占用家庭 LAN 地址。
- `h28k` 的 `192.168.30.0/24` 是独立站点网段，不计入家庭静态地址池。

## 主机表

| 主机 | index | 家庭局域网 IPv4 | ZeroTier 节点 ID | LTNET IPv4 | WireGuard/LTNET 声明 |
| --- | ---: | --- | --- | --- | --- |
| `ml-builder` | 114 | `192.168.0.50` | `2c86750714` | `198.18.0.114` | 主构建机 + Hydra；经 WSS 接入 server mesh |
| `ml-home-vm` | 115 | `192.168.0.51`（保留地址） | `c340ae9a91` | `198.18.0.115` | 已退役（2026-08-03）；不再参与 server mesh |
| `greencloud` | 120 | 无 | `76d1b20a73` | `198.18.0.120` | SG 公网节点；server mesh、DN42 与 ZeroTier controller |
| `ml-2700` | 113 | `192.168.0.53` | `214f8619a9` | `198.18.0.113` | 当前没有 server mesh 声明 |
| `ml-laptop` | 118 | `192.168.0.55` | `08d6522fba` | `198.18.0.118` | 物理笔记本；当前没有 server mesh 声明 |
| `pve-5700u` | 116 | `192.168.0.2` | `706ba6d04d` | `198.18.0.116` | 当前没有 server mesh 声明 |
| `hostdare` | 117 | 无 | `a073934677` | `198.18.0.117` | server mesh 全互联；为 WSS/TCP WireGuard transport 服务端 |
| `volcengine` | 119 | 无 | `ecd09d7bc2` | `198.18.0.119` | server mesh 全互联；到 `hostdare` 经 WSS/TCP |
| `google` | 121 | 无 | `47c75f186a` | `198.18.0.121` | server mesh 全互联；公网节点 |
| `h28k` | 125 | `192.168.30.1`（独立站点 LAN） | 待首启采集 | `198.18.0.125` | 预部署；以后承载附加路由 `192.168.30.0/24` |
| `molishanguang-macbook` | 200 | 无 | `174ea952dd` | `198.18.0.200` | 额外 ZeroTier 客户端；不参与 server mesh |

ZeroTier 受控节点的静态地址由 index 推导：IPv4 为 `198.18.0.<index>`，IPv6 为 `fdd8:1938:4e88::<index>`。额外客户端的声明来源仍是 secrets 的 `zerotier-additional-hosts.nix`；上表只记录已授权的 Mac 固定分配。

`h28k` 行中的 LTNET 地址目前只是由 index 推导的目标地址；在真实 node ID 写回
`host.nix`、controller 授权和 SOPS rekey 完成前，它不是已授权或已验证的在线节点。

## WireGuard 与 LTNET

| 项目 | 当前实现 |
| --- | --- |
| 私钥 | 每台启用 mesh 的主机从 `per-host/wg-priv/<hostname>.yaml` 由 SOPS 解密 |
| 公钥 | 由 secrets 的 `wg-pubkey.nix` 提供；不在仓库文档中复制 |
| 对等选择 | 当前 server mesh 由在线节点组成（`greencloud`、`hostdare`、`volcengine`、`google` 等）；`ml-home-vm` 已退役，不再参与 |
| 端点选择 | 同一 `interconnect.name` 时走局域网；跨网段优先使用各 host 声明的 WSS/TCP transport |
| TCP transport | 在线家庭节点与公网 server 之间的 WireGuard 经本地 WSS/TCP `443` 封装；WireGuard 本体只在本机回环与 `wstunnel` 间通信 |
| 路由 | BIRD 通过每条 `wgmesh<peer-index>` 链路上的 IPv6 link-local iBGP 交换 LTNET、DN42 与附加路由 |
| 可观察性 | WireGuard exporter 监听本机 LTNET IPv4；BIRD 配置见 `nixos/server-apps/bird/config/ltnet.nix` |

当前 DN42 前缀只由 `greencloud` 宣告：`172.20.46.224/27` 与 `fdd8:1938:4e88::/48`。不要将家庭局域网前缀加入 DN42 路由。

## 内部数据库入口

| 服务 | LTNET 地址 | 用途 | 访问范围 |
| --- | --- | --- | --- |
| PostgreSQL 18 | 已随迁移调整 | 原 `ml-home-vm` 数据库入口已退役；当前入口以主机配置为准 | 仅本机与 LTNET；不发布公网 DNS 或反向代理 |
| `edp-panel` | 已随迁移调整 | 临时测试数据库入口随 PostgreSQL 迁移 | 角色仅允许连接自己的数据库；密码不记录在文档 |

## 域名与入口

DNSControl 只声明记录；运行时的 `/etc/hosts` 可以在局域网中覆盖解析，优先级高于公网 DNS。`home-ddns.zhyi.xin` 与 `wg-home.zhyi.xin` 在 DNSControl 中标记为 `IGNORE`，其中 `home-ddns.zhyi.xin` 由 router 上的 Gcore DDNS 服务维护。

| 域名/模式 | DNS 声明 | 服务入口/后端 |
| --- | --- | --- |
| `主机.zhyi.xin`、`*.主机.zhyi.xin` | `host-recs.nix` 按主机公网或 LTNET 地址生成 | 作者式主机与私有服务命名；不经过统一公网入口 |
| `*.ml-home-vm.zhyi.xin` | 历史 CNAME | `ml-home-vm` 已退役；服务由 `rock5c`/`opi5p` 承载，入口以 vhost/DNS 为准 |
| `ha.opi5p.zhyi.xin` | `*.opi5p.zhyi.xin` 通配解析到 OPI5P LTNET | 私有服务规范命名（`服务.承载主机.zhyi.xin`），仅内网/LTNET 可达 |
| `vaults3.zhyi.xin` | CNAME 到 `home-ddns.zhyi.xin` | 家庭动态公网入口 |
| `hydra.zhyi.xin` | CNAME 到 `greencloud.zhyi.xin` | greencloud Nginx 反代到 `ml-builder` 的 Hydra 端口（LTNET `198.18.0.114`） |
| `attic.zhyi.xin` | CNAME 到 `volcengine.zhyi.xin` | volcengine 上的 Attic 服务；存储数据面仍由配置的 S3 后端承担 |
| `greencloud.zhyi.xin` | A `203.55.176.158` | SSH、Colmena、ZeroTier controller 与公共服务入口 |
| `zhyi.xin` | A `101.96.199.157` | VOLCENGINE 上的公开根站入口 |
| 具名 `zhyi.xin` Web 服务 | 显式 CNAME 到 `home-ddns`、`greencloud` 或 `volcengine` | 按作者服务角色逐项声明，不使用统一通配符兜底 |
| `hostdare.zhyi.xin` | A `36.50.85.113` | `hostdare` 自身服务 |

家庭公网封锁标准 `443`。DNS、Nginx vhost、OAuth 回调和应用自身 URL 仍保持
作者的标准 HTTPS 结构；需要从公网直接访问 `home-ddns` 承载的服务时，客户端
显式使用 `https://域名:8443/`，router 将公网 `8443` 转发到家庭入口的
`443`。VaultS3 的公网转发和 LAN Hairpin 同样将外部 8443 转换为 OPI5P 的标准
443；Nginx 不额外监听 8443。不要把 `8443` 固化进 DNS 记录或内部服务配置。

Hydra 已于 2026-08-12 迁到家庭 NAT 后的 `ml-builder`，公网入口统一由 greencloud
的 Nginx vhost 反代到 ml-builder 的 LTNET 地址，不再依赖 hostdare 直连或家庭 PVE 的
公网 IPv6。不要把 Hydra 改回 pve-5700u 或改到 VOLCENGINE 来掩盖入口问题。

## 局域网覆盖

| 生效主机 | 覆盖关系 | 用途 |
| --- | --- | --- |
| `pve-5700u` | `ml-builder.zhyi.xin -> 192.168.0.50` | LAN 内主机互访 |
| `opi5p` | `vaults3.zhyi.xin ->` 本机 interconnect 地址 | VaultS3 本机访问不绕公网 |

MetaCubeXD 运行于 `rock5c`（`192.168.0.64:7892`）；控制界面和 Clash API 仅绑定回环地址，并经 `metacubexd.rock5c.zhyi.xin` 的私有 Nginx vhost 访问。Halo 与根域 `zhyi.xin` 由 VOLCENGINE 承载。

`zhyi.xin` 的公开入口统一静态指向 `volcengine`，不配置自动故障转移。`hostdare`
承担原 TWVM 的公网 LTNET 中继职责，TWVM 不再属于生产拓扑。

## 清理判定

ZeroTier controller 的授权成员以当前 `hosts/*/host.nix` 中仍参与生产的 ZeroTier ID，加上 secrets 中声明的 `molishanguang-macbook` 为准。TWVM 退出拓扑后应在控制器中撤销授权。`peers.d` 是 ZeroTier 的发现缓存，不是授权成员清单；它由 `zerotierone` 的启动前脚本自动重建，不能据此删除设备。

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

# 配置来源
rg -n 'interconnect|zerotier|ltnet|endpointOverrides' hosts/*/host.nix
rg -n 'home-ddns|publicVpsTarget|CNAME|GEO' dns/domains
```
