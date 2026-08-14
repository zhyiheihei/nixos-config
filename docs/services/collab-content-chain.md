# 协作/内容联邦链路（greencloud：Element/Matrix + Lemmy）

## 概览

greencloud（新加坡 SG，`hosts/greencloud`，原 colocrossing 改名）上承载的
"协作/内容"联邦服务族——**Matrix（Element 客户端 + Synapse）**与
**Lemmy（ActivityPub）**。两者互相关联（同主机、同 nginx、同数据库服务器、
同为联邦服务），视为**一条链路**管理。**全部跑在海外，无国内主机。**

| 入口 | 服务 | 协议 |
| --- | --- | --- |
| `https://element.zhyi.xin` | Element Web（Matrix 客户端） | Matrix |
| `https://matrix-client.zhyi.xin` | Matrix Synapse API | Matrix |
| `https://lemmy.zhyi.xin` | Lemmy（链接聚合社区） | ActivityPub |

## 为什么算一条链路（互相关联点）

- **同主机**：均在 greencloud（SG，唯一 import 这两条链的主机）。
- **同 nginx**：都走 `lantian.nginxVhosts` + lets-encrypt（zhyi.xin）+
  `blockMainlandChina`（大陆 IP 403，预期）。
- **同数据库服务器**：共用本地 postgresql（两个库：`matrix-synapse`、`lemmy`）。
- **同 LTNET 基础设施**：Matrix 用 LDAP 认证
  （`ldap://[fdd8:1938:4e88:3712::389]`，`matrix-synapse-ldap3`）。
- **同为联邦服务**：Matrix 联邦 + ActivityPub 联邦，分别与外部实例互通。

## 链路一：Matrix（Element → Synapse）

```
公网 element.zhyi.xin / matrix-client.zhyi.xin
  → nginx vhost（静态托管 element-web / 反代 Synapse API）
    → matrix-synapse（本地 postgresql 库 matrix-synapse；LDAP 认证；联邦 :8448）
```

- 模块：`nixos/optional-apps/matrix-synapse/`（matrix-synapse.nix、mautrix-gmessages*、
  synapse-compress-state.nix）；Element：`nixos/common-apps/nginx/vhost-matrix-element/default.nix`
- Element 是**静态 nginx vhost**（`pkgs.element-web` 压缩静态资产），无独立 systemd 服务
- 端口：`Matrix.Public = 8448`（联邦）、Synapse API 经 nginx

## 链路二：Lemmy（ActivityPub）

```
公网 lemmy.zhyi.xin（lets-encrypt, blockMainlandChina, proxyWebsockets）
  → lemmy_server :13200 (API)
    ├─ postgresql（本地，db=lemmy）
    └─ pict-rs :13202（图片代理, image_mode=ProxyAllImages）
  └─ lemmy-ui :13201 — 默认禁用（无 Web UI，走 API/客户端）
```

- 模块：`nixos/optional-apps/lemmy.nix`（imports `./pict-rs.nix`、`./postgresql.nix`）
- 补丁：`patches/lemmy-disable-specific-error.patch`（overlay `50-general.nix` 应用，
  抑制 "next send id higher than latest id"；alignment-audit-2026-08-13 恢复）
- 认证：本地账号（不走 LDAP，与 Matrix 不同）

## 共享基础设施

- nginx：`lantian.nginxVhosts`、lets-encrypt（zhyi.xin）、`blockMainlandChina`
- postgresql：本机，两库 `matrix-synapse` / `lemmy`
- LDAP：LTNET（Matrix 用）；监控：Blackbox Exporter 探测两条链入口
- 计划任务/其它协作服务（Gitea、Maddy 等）见 `docs/infrastructure/fleet-service-chain.md`

## 可用性验证（2026-08-14）

### Matrix 链路
- `matrix-synapse.service`：active；联邦活跃（5 分钟 48 条 `edu from` 事件，
  对端如 beney.io / dopsi.ch）
- element.zhyi.xin：HTTP 200；matrix-client.zhyi.xin：301（https 跳转，正常）

### Lemmy 链路
- `lemmy.service` / `pict-rs.service` / `postgresql.service`：active
- 本机 API `:13200/api/v3/site` → 200；联邦 `Federating to 1/1 instances
  (0 dead, 0 disallowed)`、0 滞后
- 补丁生效：被抑制错误 0 次
- 公网对大陆出口 403（`blockMainlandChina` 预期）；海外可访问

## 已知问题 / 待办

1. **Lemmy actor_id 陈旧**：site 行 `actor_id = https://lemmy.lantian.pub/`
   （2026-07-12 建库时的上游域名），与配置 `lemmy.zhyi.xin` 不一致——联邦外发
   身份仍是旧域名，可能与真实该域实例冲突。需更新 site 表 actor_id（或重建站点）
   后复验联邦。⚠️ 改前先确认对端。
2. **lemmy-ui 禁用**：无 Web 界面（设计如此），用 API 或 Lemmy 客户端。
3. **主机名未同步**：greencloud 机器 `hostname` 仍是 `colocrossing`
   （rename 未带 hostname 变更），journal 前缀显示旧名，可后续对齐。
4. **大陆访问被拦**：两链入口均 `blockMainlandChina`（预期行为）。
