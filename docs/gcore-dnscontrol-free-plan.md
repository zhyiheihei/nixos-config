# Gcore 免费套餐 DNSControl 发布规范

本仓库的 `zhyi.cc`、`zhyi.xin` 目前使用 Gcore DNS 免费套餐。Gcore 的 API
限制与 DNSControl 的 `preview` 不完全一致；发布含健康检查或加权记录前，必须按
本规范执行。

## 已验证的 API 限制

2026-07-18 实测，当前套餐对动态 RRSet 有以下限制：

- 加权过滤器名必须是 `weighted_shuffle`，不是 `weighted`。
- 动态记录 TTL 不得小于 `120s`。
- 健康检查频率不得小于 `300s`。
- 整个当前账户只允许一个动态 RRSet。第二条及之后会被 API 拒绝为
  `You can not have additional dynamic rrset on the Free plan.`

因此，不能把一批现有 CNAME 一次性改成带健康检查的 GEO 记录。`preview` 只能
计算期望差异，不会校验这些套餐限制。

## 当前约定

- `zhyi.cc` 的公开服务使用静态 `CNAME -> jp.zhyi.cc.`，包括 `ha.zhyi.cc`；
  `zhyi.xin` 的公开服务使用静态 `CNAME -> cnvm.zhyi.cc.`。
- `twvm` 不是正常的公开服务出口，只保留为手动 VLESS 备用节点。
- 目前不实施公网自动故障转移。未来若恢复该需求，应先升级 Gcore 套餐或迁移到
  支持多条健康检查记录的 DNS 提供商；不要在免费套餐上重新批量改 GEO。

## 发布流程

在拥有 SOPS 解密 key 的 `ml-builder` 上运行：

```bash
cd /nix/src/nixos-config
nix run .#dnscontrol -- preview
```

发布前检查：

1. `preview` 中的删除项是否都有对应创建项。
2. 如包含 Gcore 动态记录，确认仍只有一条动态 RRSet，TTL 至少 `120s`，检查频率
   至少 `300s`。
3. 先用一个未承载服务的测试记录验证新类型；不要直接替换一批生产 CNAME。

确认后才执行：

```bash
nix run .#dnscontrol -- push
```

发布后用公共递归 DNS 检查，而不是只看本地缓存：

```bash
dig +short ha.zhyi.cc @1.1.1.1
dig +short hydra.zhyi.cc @1.1.1.1
```

若主机网络拦截 UDP/53，`dig @1.1.1.1` 仍可能命中本地缓存。此时用 DoH 交叉验证，
不要据此重复发布 DNS：

```bash
curl -fsS -H 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=cnvm.zhyi.cc&type=A'
```

## 失败恢复

DNSControl 对 CNAME 与 A/GEO 的替换不是事务：旧 CNAME 可能先删除，而新记录因
提供商限制创建失败。遇到这种情况，停止继续试验动态记录，先把受影响服务恢复为
原先的静态 CNAME，然后重新运行 `push`。恢复可访问性优先于继续迁移。
