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
  cnvm/hostdare/google/colocrossing 与默认重复的显式 nameserver（colocrossing 仅保留
  Google IPv6）。
- 2026-08-10（独立 agent 验证与部署）：`0abf17ee` 在 ml-builder 上求值通过，
  cnvm toplevel 构建成功；`google`、`colocrossing` 已部署，运行态 resolv.conf、
  `/etc/pdns-recursor/recursor.yml` 与 `dig @198.19.0.253` 均符合预期。
- 2026-08-10（SERVFAIL 根因）：AliDNS、DNSPod、Google 对 `zhyi.cc`/`zhyi.xin`
  均返回 NOERROR 且无 RRSIG/AD，而 recursor 报 EDE 6（DNSSEC Bogus），因此按
  `m-team.cc` 模式为 `zhyi.cc`、`zhyi.xin` 加 NTA，待 cnvm 部署后复测。
- 2026-08-10（NTA 验证）：`031fb238` 在 ml-builder 上求值与 cnvm toplevel
  构建通过；ml-builder 侧 `dig @198.19.0.253 vaults3.zhyi.cc` 与 `zhyi.cc`
  均已恢复 NOERROR，无 EDE 6。
- 2026-08-10（cnvm 部署）：统一 SSH 端口为 `2222` 后，cnvm 已通过
  `colmena apply --on cnvm` 部署成功；cnvm 与 ml-builder 两侧
  `dig @198.19.0.253 vaults3.zhyi.cc` / `zhyi.cc` 均为 NOERROR，无 EDE 6。
- 2026-08-10（根域 Bogus 修复）：AliDNS/DNSPod 对根域 `.` 的 NS 不返回 RRSIG，
  导致 CN recursor 校验根域时报 `Got Bogus validation result for .|NS` 并整体
  SERVFAIL；CN recursor 改为 `process-no-validate`，国外保持 `validate`。
- 2026-08-10（Attic 验证）：CN recursor 修复部署到 cnvm 与 ml-builder 后，
  `attic.zhyi.xin`、`vaults3.zhyi.cc` 等解析均为 NOERROR，热缓存 0-1 ms；
  据此撤销 `attic-s3-connect-timeout.patch`，无补丁部署后 atticd active、
  Attic 443 与 VaultS3 8443 探测均 200。
- 2026-08-10（Attic 迁移）：按作者布局把 Attic 迁回 `colocrossing` 公网 VPS，
  S3 后端保持现有 VaultS3；`attic.zhyi.xin` 公网 DNS 指向 colocrossing。
- 2026-08-10（Attic 迁移执行）：colocrossing 已部署 atticd 并恢复元数据，
  DNS 已切换，cnvm 的 atticd 已移除；待 colocrossing 链路稳定后重推
  moviepilot 并清理临时 dump/key。
- 待办：`hostdare` 流量耗尽不可达，配置未切换；配额恢复后执行
  `colmena apply --on hostdare` 并复核。
