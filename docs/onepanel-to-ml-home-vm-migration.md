# 1Panel 服务迁移到 ml-home-vm

2026-07-18 将旧 `1panel.zhyi.xin:55555` 上的以下服务迁移到
`ml-home-vm`。迁移快照已保留在 `ml-home-vm`；旧 1Panel 虚拟机已于
2026-07-18 重装为 NixOS `cnvm`，不再承载或保留 1Panel 服务数据。

## 已迁移服务

| 域名 | 目标服务 | 数据位置 | 预期响应 |
| --- | --- | --- | --- |
| `bitwarden.zhyi.xin` | NixOS Vaultwarden | `/var/lib/vaultwarden` | `200` |
| `filebox.zhyi.xin` | FileCodeBox 容器 | `/var/lib/filecodebox` | Dex OAuth `302` |
| `index.zhyi.xin` | Sun Panel 容器 | `/var/lib/sun-panel` | Dex OAuth `302` |
| `index-helper.zhyi.xin` | Sun Panel Helper 容器 | `/var/lib/sun-panel/custom` | Dex OAuth `302` |

首次迁移快照保留在：

```text
/var/lib/onepanel-migration/20260718-initial
```

## 公网路径

四个域名由 DNSControl 声明为静态 `CNAME -> cnvm.zhyi.cc.`。TLS 流量路径为：

```text
客户端 -> cnvm:443 -> colocrossing LTNET:443 -> ml-home-vm:8443
```

`hosts/colocrossing/configuration.nix` 按 TLS SNI 将这些域名转发到
`ml-home-vm`。Vaultwarden 使用自身认证；FileCodeBox 与两项 Sun Panel 服务使用
Dex OAuth。

## 验证

Nix 求值、SOPS 解密与 DNSControl 必须在 `ml-builder` 运行，不在本机运行 Nix：

```bash
ssh -A -p 2222 root@ml-builder
cd /nix/src/nixos-config
nix run .#dnscontrol -- preview
```

通过公共递归 DNS 检查发布结果：

```bash
for host in bitwarden filebox index index-helper; do
  printf '%s ' "$host"
  dig +short CNAME "$host.zhyi.xin" @1.1.1.1
done
```

通过真实公网 URL 检查：

```bash
for host in bitwarden filebox index index-helper; do
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
4. 等待 DNS TTL（当前为 10 分钟）并确认对应服务停止走 CNVM 入口。

SNI 分发规则可暂时保留；回滚的关键是 DNS CNAME。1Panel 源机已经改作
CNVM，不能作为应用回滚目标；不要删除 `ml-home-vm` 的迁移快照。
