# 1Panel 服务迁移到 ml-home-vm

2026-07-18 将旧 `1panel.zhyi.xin:55555` 上的以下服务迁移到
`ml-home-vm`。旧主机暂时保留运行，作为切换期的回滚源；在确认数据不再写入旧
服务且观察期结束前，不要停止或删除旧容器、卷和数据库。

## 已迁移服务

| 域名 | 目标服务 | 数据位置 | 预期响应 |
| --- | --- | --- | --- |
| `bitwarden.zhyi.xin` | NixOS Vaultwarden | `/var/lib/vaultwarden` | `200` |
| `filebox.zhyi.xin` | FileCodeBox 容器 | `/var/lib/filecodebox` | Dex OAuth `302` |
| `index.zhyi.xin` | Sun Panel 容器 | `/var/lib/sun-panel` | Dex OAuth `302` |
| `index-helper.zhyi.xin` | Sun Panel Helper 容器 | `/var/lib/sun-panel/custom` | Dex OAuth `302` |
| `sso.zhyi.xin` | Zitadel 容器与本机 PostgreSQL | `/var/lib/onepanel-migration/20260718-initial/zitadel.sql` | Zitadel `302` |

首次迁移快照保留在：

```text
/var/lib/onepanel-migration/20260718-initial
```

Zitadel 的恢复单元只在恢复标记不存在时导入该快照。标记为：

```text
/var/lib/onepanel-migration/20260718-initial/.zitadel-restored
```

不要手动删除标记。需要重新从快照恢复时，先确认当前目标数据库可以丢弃，再由
维护者删除标记并重启 `zitadel-db-restore.service`。

## 公网路径

五个域名由 DNSControl 声明为静态 `CNAME -> jp.zhyi.cc.`。TLS 流量路径为：

```text
客户端 -> jpvm:443 -> colocrossing LTNET:443 -> ml-home-vm:8443
```

`hosts/colocrossing/configuration.nix` 按 TLS SNI 将这些域名转发到
`ml-home-vm`。Vaultwarden 和 Zitadel使用各自认证；FileCodeBox 与两项 Sun
Panel 服务使用 Dex OAuth。

## 验证

Nix 求值、SOPS 解密与 DNSControl 必须在 `ml-builder` 运行，不在本机运行 Nix：

```bash
ssh -A -p 2222 root@ml-builder
cd /nix/src/nixos-config
nix run .#dnscontrol -- preview
```

通过公共递归 DNS 检查发布结果：

```bash
for host in bitwarden filebox index index-helper sso; do
  printf '%s ' "$host"
  dig +short CNAME "$host.zhyi.xin" @1.1.1.1
done
```

通过真实公网 URL 检查：

```bash
for host in bitwarden filebox index index-helper sso; do
  printf '%s ' "$host"
  curl -sS -o /dev/null -w '%{http_code}\n' "https://$host.zhyi.xin/"
done
```

预期 Vaultwarden 返回 `200`，其余服务首次访问返回认证或登录跳转 `302`。

## 回滚

若迁移后的服务异常：

1. 在 `dns/domains/zhyi.xin.nix` 的 `publicVpsServices` 移除对应服务名。
2. 在 `ml-builder` 运行 `nix run .#dnscontrol -- preview`，确认仅撤销对应 CNAME。
3. 在 `ml-builder` 运行 `nix run .#dnscontrol -- push`。
4. 等待 DNS TTL（当前为 10 分钟）并确认旧 1Panel 服务恢复承载。

SNI 分发规则可暂时保留；回滚的关键是 DNS CNAME。不要在回滚完成前删除
`ml-home-vm` 的快照或旧 1Panel 数据。
