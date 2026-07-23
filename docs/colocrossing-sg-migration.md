# colocrossing 迁移到新加坡节点

## 目标

- `sgvm` 接管逻辑主机名 `colocrossing`，保留新加坡节点的硬件、SSH host key、
  ZeroTier 客户端身份和公网地址。
- 保留作者 `colocrossing` 的服务角色，并合并原 `sgvm` 的 AI 与监控服务。
- 只能访问家庭 NAS 的反向代理迁移到 `ml-home-vm`。
- 验证完成后关闭并移除旧家庭 VM，不再保留 `sgvm` 这个逻辑主机。

## 主机身份

| 项目 | 迁移后值 |
| --- | --- |
| 逻辑主机名 | `colocrossing` |
| 部署地址 | `203.55.176.158:2222` |
| LTNET index | `120` |
| LTNET IPv4 | `198.18.0.120` |
| ZeroTier 客户端 ID | `76d1b20a73` |
| DN42 IPv4 | `172.20.46.230` |

新主机保留新加坡节点自己的
`/nix/persistent/etc/ssh/ssh_host_ed25519_key` 和
`/nix/persistent/var/lib/zerotier-one`。不要用旧 VM 的同名目录覆盖它们。

ZeroTier 控制器必须迁移旧 VM 的
`/nix/persistent/var/lib/zerotier-one-controller`，以保留控制器 ID
`466270de75`、网络 ID `466270de75000001` 和成员授权状态。

## 服务归属

新 `colocrossing` 承载：

- 作者原 colocrossing 的 Gitea、Matrix、Maddy、Miniflux、NetBox、
  Plausible、Quassel、Radicale、Syncthing、RSSHub、Bepasty、Byparr、
  ZeroTier controller、DN42 和配套任务。
- 原 sgvm 的 AxonHub、Grafana、Metapi、N8N、Open WebUI 和 Prometheus。

`ml-home-vm` 承载只能访问家庭 NAS 的入口：

- `vaults3.zhyi.cc` -> `192.168.2.93:9000`
- `qnap.zhyi.cc` -> `192.168.2.93:8080`
- `couchdb.zhyi.cc` -> `192.168.2.93:5984`

Attic、Dex、GLAuth、Pocket ID、Halo 和 Vaultwarden 已由 `cnvm` 承载，
不从旧 colocrossing 的历史数据目录重复迁移。

## 数据迁移规则

可直接通过 `rsync -aHAX --numeric-ids` 迁移应用状态，但数据库目录不得直接
覆盖：

- PostgreSQL 使用 `pg_dump --format=custom` 和 `pg_restore`。
- MariaDB 的 Gitea 数据库使用 `mariadb-dump --single-transaction` 和
  `mariadb` 导入。
- 新加坡节点已有的 PostgreSQL、MariaDB、Grafana、Prometheus、N8N、
  Open WebUI、AxonHub 和 Metapi 数据必须保留。

迁移 PostgreSQL 数据库：

- `lemmy`
- `maddy`
- `matrix-synapse`
- `mautrix-gmessages`
- `miniflux`
- `netbox`
- `plausible`
- `quassel`

不迁移旧机中已经退出该角色的 `atticd`、`dex`、`pocket-id` 和 `waline`
数据库。

## 切换顺序

1. 构建 `colocrossing` 和 `ml-home-vm`，验证 SOPS 解密。
2. 不停机预同步应用数据和数据库快照。
3. 停止旧机应用服务、数据库、WireGuard 和 ZeroTier controller。
4. 做最后一次增量同步和数据库导出。
5. 部署新 `colocrossing`，初始化数据库用户和空数据库。
6. 导入数据库，启动并逐项验证服务。
7. 部署 `ml-home-vm` 的 NAS 本地入口。
8. 更新 DNS 并用 `curl --resolve` 验证新公网入口。
9. 关闭旧 VM，观察一轮后移除旧 VM、路由转发和 PVE 备份引用。
10. 检查 LTNET、ZeroTier、WireGuard 和 DN42 邻接。

任何一步失败时，先停止新机对应服务，再重新启动旧 VM 的服务。DNS 和路由
清理必须放在验收之后，确保回退路径仍然存在。

## 完成状态

迁移已于 2026-07-24 完成：

- 迁移前 `colocrossing` 与 `sgvm` 的 NixOS 服务模块并集已全部由新
  `colocrossing` 导入。
- `vaults3.zhyi.cc`、`qnap.zhyi.cc` 和 `couchdb.zhyi.cc` 已迁移至
  `ml-home-vm`，其三个 NAS 后端均可达。
- 新 `colocrossing` 使用 index 120、LTNET 地址 `198.18.0.120` 和原
  `sgvm` 的主机密钥及 ZeroTier 身份。
- `cnvm`、`jpvm`、`logvm`、`ml-home-vm` 和 `usvm` 到新
  `colocrossing` 的 WireGuard 与 BGP 会话均已恢复，rsync 主服务器统一为
  `198.18.120.1`。
- PVE VM 200、`virtiofs-nixos-colocrossing` 映射、旧 VirtioFS 数据和对应
  备份任务均已删除。仓库、DNS 和运行时网络中不再保留旧 index 18 身份。
