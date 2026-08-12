# pve-5700u 瘦身为纯 PVE 宿主

> 日期：2026-08-12。范围：pve-5700u 上除 Proxmox VE（hypervisor）之外的服务
> 全部迁到 `ml-builder`，并同步服务分布文档。

## 迁移内容

| 服务 | 原位置 | 目标位置 |
| --- | --- | --- |
| Hydra（evaluator / queue-runner / server / notify / watchdog） | `pve-5700u` | `ml-builder` |
| PostgreSQL（Hydra 数据库） | `pve-5700u` | `ml-builder` |
| `archiveteam` 容器 | `pve-5700u` | `ml-builder` |
| `clawemail` 容器 | `pve-5700u` | `ml-builder` |
| `epic-awesome-gamer` 容器 | `pve-5700u` | `ml-builder` |
| `nix-builder` 回退角色 | `pve-5700u` | 移除（ml-builder 与 opi5p 保留） |

保留在 `pve-5700u`：

- Proxmox VE 与全部 VM（`fn-os`、`ubuntu` 等）；
- VM 数据备份 `backup-nvme-nixos-home-vm`（VirtioFS 数据由 PVE 承载，备份任务不能
  迁走；迁移后重新复核端点）；
- `ncps-client` 的 substituter 配置。

## 入口变化

- `hydra.zhyi.cc` DNS 继续 CNAME 到 `colocrossing.zhyi.cc`；colocrossing 的
  `hydra.zhyi.cc` vhost 后端改为 `ml-builder` LTNET 地址（主机级覆盖，
  不动公共 `vhost-hydra-proxy.nix`）。
- `archiveteam.ml-builder.zhyi.cc`、`clawemail.ml-builder.zhyi.cc` 等私有 vhost
  随容器模块在 ml-builder 本机生成，容器继续绑定 127.0.0.1。

## 执行步骤

1. 停掉 pve-5700u 上的 Hydra 队列、PostgreSQL 与三个容器，避免写入。
2. 用 rsync 把 `/var/lib/postgresql/`、`/var/lib/hydra/`、`/var/lib/archiveteam/`、
   `/var/lib/clawemail/`、`/var/lib/epic-awesome-gamer/` 从 pve-5700u 复制到
   ml-builder。
3. 部署 ml-builder（Hydra + PostgreSQL + 三个容器）与 colocrossing（hydra 反代
   后端），确认服务与数据恢复。
4. 部署 pve-5700u 新代际，移除 Hydra、容器与 `nix-builder` 标签。
5. 按下方验收清单复核，再提交文档与代码。

## 验收清单

```bash
# ml-builder
systemctl is-active hydra-evaluator hydra-queue-runner hydra-server postgresql
podman ps
grep -E 'opi5p|pve-5700u|localhost' /etc/nix/machines-with-localhost

# pve-5700u
systemctl is-active pveproxy pvedaemon
qm list
systemctl --failed

# 入口
curl -fsSI https://hydra.zhyi.cc
```

预期：

- ml-builder 的 Hydra 单元与 PostgreSQL 均为 active，三个容器 running；
- `machines-with-localhost` 不包含 `pve-5700u`；
- pve-5700u 只有 PVE 与 VM 相关 unit，`qm list` 中的 VM 保持原状态；
- `hydra.zhyi.cc` 返回 Hydra 登录页；
- pve-5700u 与 ml-builder 的 `systemctl --failed` 只剩已知备份问题或为 0。

## 回滚

如果 Hydra/容器在 ml-builder 上无法恢复，把反代目标改回 pve-5700u LTNET，
重新部署 pve-5700u 原代际并恢复 `/var/lib/*` 数据。数据目录在 pve-5700u 上
保留至少一个完整迁移周期，迁移确认前不删除。
