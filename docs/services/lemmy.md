# Lemmy 链路（lemmy.zhyi.xin）

## 概览

Lemmy（ActivityPub 联邦式链接聚合社区）跑在 **greencloud**（新加坡 SG，
`hosts/greencloud`，原 colocrossing 改名），**不在任何国内主机上**——全仓库仅
`hosts/greencloud/configuration.nix` 引入 `optional-apps/lemmy.nix`。入口：
`https://lemmy.zhyi.xin`。

- API：`https://lemmy.zhyi.xin`（`blockMainlandChina`，大陆 IP 403）
- 实例身份（actor_id）：`https://lemmy.lantian.pub/`（⚠️ 见下方已知问题）

## 链路

```
公网 (lemmy.zhyi.xin, lets-encrypt)
  → nginx vhost（proxyWebsockets, blockMainlandChina, noIndex）
    → lemmy_server :13200 (API, lemmy.zhyi.xin)
      ├─ postgresql（本地，db=lemmy，unix socket）
      └─ pict-rs :13202（图片代理, image_mode=ProxyAllImages）
  └─ lemmy-ui :13201 — 默认禁用（systemd.services.lemmy-ui.enable = mkForce false）
```

## 配置位置

- 模块：`nixos/optional-apps/lemmy.nix`（imports `./pict-rs.nix`、`./postgresql.nix`）
- 主机接入：`hosts/greencloud/configuration.nix`
- 端口常量：`helpers/constants/ports.nix`（`Lemmy.API=13200`、`Lemmy.UI=13201`、`Pict-RS=13202`）
- 补丁：`patches/lemmy-disable-specific-error.patch`（由 `overlays/50-general.nix`
  应用到 `lemmy-server`，抑制 "next send id higher than latest id" 错误日志；
  alignment-audit-2026-08-13 恢复）

## 服务与状态（greencloud）

| 服务 | 状态 | 说明 |
| --- | --- | --- |
| `lemmy.service` | active | `lemmy-server-0.19.20`，hardened（`LT.serviceHarden`），User/Group=lemmy |
| `pict-rs.service` | active | 图片代理存储 |
| `postgresql.service` | active | 本地数据库 |
| `lemmy-ui.service` | 禁用 | 设计如此（无 Web UI，走 API/客户端） |

## 联邦

- 联邦 worker 每分钟输出 `Federation state` 统计；当前 `Federating to 1/1
  instances (0 dead, 0 disallowed)`、`0 instances behind`（无滞后）。
- 对端数量：1 个远端实例。

## 监控

- Blackbox Exporter 每 ~30s 探测 `GET /`（日志可见 `Blackbox-Exporter/0.28.0`
  200），纳入 Prometheus 监控链。
- 巡检参考 `docs/operations/inspection-playbook.md`。

## 可用性验证（2026-08-14）

- 服务：lemmy / pict-rs / postgresql 均 active；lemmy-ui 按设计禁用。
- API：本机 `http://127.0.0.1:13200/api/v3/site` → 200（有效 JSON）。
- 公网：`https://lemmy.zhyi.xin/api/v3/site` 对大陆出口 IP 返回 403（`blockMainlandChina`
  预期拦截，非故障）；海外出口应可访问。
- 联邦：worker 正常、无 dead/disallowed、无滞后。
- 补丁：`next send id higher than latest id` 在 2026-08-14 后 0 次出现（补丁生效）。

## 已知问题 / 待办

1. **actor_id 陈旧**：site 行 `actor_id = https://lemmy.lantian.pub/`（2026-07-12
   建库时的上游域名），与配置 `settings.hostname = lemmy.zhyi.xin` 及 nginx vhost
   不一致。联邦外发身份仍是 `lemmy.lantian.pub`，可能与真实该域实例冲突。
   需要：更新 `site` 表 actor_id（或重建站点）后再验证联邦。⚠️ 修改前先确认对端。
2. **lemmy-ui 禁用**：无 Web 界面，用 API 或 Lemmy 客户端访问。
3. **大陆访问被拦**：`blockMainlandChina` 使国内 IP 403（预期行为）。
4. **主机名未同步**：greencloud 机器 `hostname` 仍是 `colocrossing`（rename 未带
   hostname 变更），journal 前缀显示旧名；影响有限，可后续对齐。
