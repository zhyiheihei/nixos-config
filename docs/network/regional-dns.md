# 分地区 DNS 方案

## 调研结论

作者原版不是“PowerDNS 或 CoreDNS”二选一，而是三层 DNS：

| 层 | 组件 | 地址 | 职责 |
| --- | --- | --- | --- |
| 权威 | `server-apps/coredns.nix` 的 CoreDNS + Knot | `198.19.0.254` | DN42、LTNET、AD、反解等内部 zone |
| 递归 | `server-apps/powerdns-recursor.nix` | `198.19.0.253` | 内部 zone 转发到 `.254`，公共 `.` 转发到公共解析器，Lua RPZ/NTA |
| 边缘 | `common-apps/coredns.nix` | `198.19.0.56` | 仅 recursor 未启用时运行；公共域名 DoT，内部 zone 转发到 `.253` |

提交历史佐证：`coredns: replace with pdns recursor where enabled` 把服务器从
CoreDNS 换成 PowerDNS Recursor；`powerdns: directly connect to upstream DNS`
让 PowerDNS 直连公共解析器；`powerdns: perform recursion on its own` 试过自递归
后回退，最终形态是“本地递归器 + 公共上游转发”。

没有检索到叫 `vpsdns` 的项目或文件；该词最合理的解释是作者在 VPS 上的 DNS
分层设计，即本文件描述的架构。

## 为什么是 PowerDNS Recursor

CoreDNS 的 `forward` 插件是“转发 + 缓存”，不是完整递归解析器。服务器角色需要
DNSSEC 校验、RPZ、Lua `addNTA`、`forward-zones-recurse` 和按 zone 分流到内部
权威，这些是 PowerDNS Recursor 的能力。CoreDNS 仍留在边缘做轻量 DoT 转发。

## 分地区方案

### 国内

- 第一跳保持本机 recursor/CoreDNS，LTNET 与 DN42 不经过公共 DNS。
- recursor 公共上游：AliDNS `223.5.5.5/223.6.6.6` + DNSPod `119.29.29.29/119.28.28.28`。
- CoreDNS 国内上游：AliDNS DoT 主，DNSPod UDP 兜底。
- minimal 默认 fallback：`223.5.5.5/223.6.6.6/119.29.29.29`。

### 国外

- recursor 公共上游：Google `8.8.8.8/8.8.4.4`、Google IPv6、Cloudflare
  `1.1.1.1/1.0.0.1` 与对应 IPv6。
- CoreDNS 保持 Google DoT。
- minimal 默认 fallback：`8.8.8.8/8.8.4.4/1.1.1.1`。

### 私有域

DN42、LTNET、CRXN、Meshname、Yggdrasil/Alfis、Emercoin、`ad.zhyi.cc` 和反解
zone 必须继续走 `198.19.0.253 → 198.19.0.254 → Knot`。只改 `.` 的公共上游，
不动 `forwardZones` 与 zone 列表。

## 实施状态

- 2026-08-10：新增本文档；recursor 公共上游按地区扩容；国内 CoreDNS 增加
  DNSPod 兜底；minimal 默认 fallback 按 `LT.this.city.country` 分流；移除
  cnvm/jpvm/usvm/colocrossing 与默认重复的显式 nameserver（colocrossing 仅保留
  Google IPv6）。
- 待办：cnvm SSH banner 当前超时，无法读取 `journalctl -u pdns-recursor`；
  `vaults3.zhyi.cc` 的 SERVFAIL 需在可达后确认是否按 `m-team.cc` 模式加 NTA，
  再执行 `dig @198.19.0.253 vaults3.zhyi.cc` 验证。
