# clash-verge LTNET/dn42 兼容层

clash-verge（mihomo 内核）默认配置与本项目网络层存在三处硬冲突，直接开 TUN
模式会整机断网。本兼容层只改 clash-verge 侧配置，不触碰网络层；由
`nixos/optional-apps/clash-verge.nix` 的 `lantian.clash-verge.ltnetCompat`
（默认启用）通过 systemd-tmpfiles 把两个文件以只读符号链接安装进 Verge 的
profiles 目录：

- `profiles/Merge.yaml` —— Verge 全局 Merge（增强链对每个订阅深合并）
- `profiles/Script.js` —— Verge 全局 Script（增强链编程环节）

部署后需重启 Verge（或在「订阅」页重新激活）重新生成运行时配置方可生效。

## 网络层回顾（冲突的来源）

- LTNET：`198.18.0.0/15` + `fdd8:1938:4e88::/48`，经 ZeroTier 接口路由
  （本机 `198.18.0.<index>/24` 骨干网 + 指向 `198.18.0.123` 网关的
  `/15` 静态路由）；netns 内服务（coredns-client / kms / tnl-buyvm）也用
  该地址段（`198.18.<index>.<suffix>/32` 对端路由）。
- 本机 DNS：resolv.conf 首选 netns CoreDNS（`198.18.<index>.56`），dn42/
  mesh 等特殊域名由其转发 LTNET DNS（`198.19.0.253`）。
- systemd-networkd `ManageForeignRoutes=false`：主表路由（ZeroTier/LAN/
  netns）全部优先于任何 TUN 默认路由。

## 三处硬冲突（均在实机复现确认）

1. **TUN 设备地址撞 LTNET**：mihomo 默认 `tun.inet4-address 198.18.0.1/30`，
   连同 sing-tun 的 `ip rule 9000: to 198.18.0.0/30 lookup 2022` 会把
   LTNET 骨干网前 4 个地址抢进 TUN。
2. **fake-ip 池撞 LTNET + DNS 劫持黑洞（断网根因）**：默认
   `fake-ip-range 198.18.0.1/16` 与 LTNET `/15` 完全重叠。sing-tun 会强制
   接管所有 dport 53（`ip rule 9001: not ... dport 53 lookup main
   suppress_prefixlength 0`，本机发往 netns CoreDNS 甚至 LAN 路由器的查询
   全部进 TUN 被 `dns-hijack any:53` 劫持）；mihomo 应答的 fake-ip
   （198.18.x.x）随后被主表 ZeroTier 路由黑洞（suppress_prefixlength 只
   抑制默认路由，/15 更长路由照走）——所有域名连接全部超时。
3. **订阅无豁免**：sublinkpro `/c/` 统一订阅实际下发 ACL4SSR 全量模板，
   没有 `198.18.0.0/15` 直连、ZeroTier 进程/9993 端口豁免等规则，进 TUN
   的 overlay 流量会被 GEOIP 落到 `MATCH → 代理`，经境外节点黑洞。

## 修复方案（最小集）

思路与 `docs/human/network/flclash-home-override.yaml`（FlClash 同款覆写）
一致。经实机逐项验证后收敛为两处，全部落在 Verge 全局 Merge 的 `dns` 段
与全局 Script：

- **fake-ip 池迁出（Merge `dns.fake-ip-range: 28.0.0.1/8`）**：唯一必需的
  地址修复。mihomo 启用 fake-ip 时 TUN 设备地址自动派生为池子首个 /30
  （实测 `inet4-address` 字段在该模式下被忽略，故无需也不应再覆盖）。
- **`+.zhyi.xin` 进 fake-ip-filter**：内网域名拿真实 LTNET IP 后交给内核，
  由主表路由直走 ZeroTier。mihomo 出站绑定物理网卡（auto-detect-interface）
  够不到 LTNET，绝不能让它经手内网连接。
- **DNS 上游固定为国内 DoH（120.53.53.53 / 223.5.5.5）**。刻意**不用**
  `respect-rules`：实测它会让部分查询回落到真实解析，被污染域名（google 系）
  拿到假 IP 后以 IP 直连节点失败；全量 fake-ip 下被代理域名以**域名**交给
  节点远程解析，对污染免疫，直连域名由 mihomo 走国内 DoH 解析（本身干净）。
- **豁免规则前置（Script.js，仅 6 条）**：`Merge.yaml` 的 `prepend-rules`
  键实测被 Verge 原样透传、不合并进 `rules`（mihomo 忽略未知键），规则前置
  必须走全局 Script。只前置订阅没有的条目（zhyi.xin / zhyi.dn42 /
  zerotier 进程 / 9993 端口 / 198.18.0.0/15 / fdd8::/48）；RFC1918 等私网
  直连订阅已自带，不重复。

## 实机验证结论（ml-laptop，TUN 开启）

| 项目 | 结果 |
| ---- | ---- |
| 国内直连（baidu） | 200，直连稳定（多轮浸泡无抖动） |
| 海外代理（google g204 / github / wikipedia） | 204/200，域名交节点远程解析，无污染 |
| LTNET 网关/成员 ping | 正常，不经 TUN |
| LAN（192.168.0.0/24） | 正常，不经 TUN |
| 内网域名（`*.zhyi.xin`） | 返回真实 LTNET IP，内核直走 ZeroTier |

## 已知限制

- **TUN 开启时 dn42/meshname/Ygg 等特殊域名不可解析**：DNS 劫持绕过了
  netns CoreDNS，而 mihomo 出站绑定物理网卡够不到 LTNET DNS。需要 dn42
  解析时关闭 TUN 即可（走本机 CoreDNS 链路）。
- 两个覆写文件由 NixOS 管理，在 Verge GUI 里编辑全局 Merge/Script 保存会
  失败（只读符号链接）；要改行为请改仓库模块。
- Verge 升级若更换数据目录名（`io.github.clash-verge-rev.clash-verge-rev`）
  需同步调整 `lantian.clash-verge.ltnetCompat` 的安装路径。
