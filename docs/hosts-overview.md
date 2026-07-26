# 当前 hosts 概览

`hosts/<name>/host.nix` 保存主机元数据，`configuration.nix` 保存主机配置，
`hardware-configuration.nix` 保存硬件与文件系统信息。`hosts/` 只保存 9 台自有
主机；作者原版的独立 checkout 位于仓库上级目录 `../nixos-config-exam`，仅用于人工
对照，不参与当前 flake 求值或部署。

## 当前自有拓扑

当前 `hosts/` 中声明的主机如下。`Makefile` 沿用作者的 Colmena 标签目标，并增加
安全的默认帮助；实际部署命令见 [构建与部署](./deployment.md)。

| 主机 | index | 角色 | 主机元数据地址 | 说明 |
| --- | ---: | --- | --- | --- |
| `router` | 112 | 家庭路由器 | `192.168.0.1` | PPPoE、LAN 网关、DHCP、DNS 与 DDNS。 |
| `ml-2700` | 113 | `client` | `ml-2700.zhyi.cc` | 家庭客户端，LAN 地址 `192.168.0.53`。 |
| `ml-builder` | 114 | `nix-builder` | `ml-builder.zhyi.cc` | 强构建机，28 vCPU；不运行自动 Attic watch-store。 |
| `ml-home-vm` | 115 | `server` | `ml-home-vm.zhyi.cc` | 家庭应用 VM 与 NCPS；不参与远程构建。 |
| `pve-5700u` | 116 | `nix-builder` / PVE | `pve-5700u.zhyi.cc` | PVE 宿主、Hydra 与本机构建能力。 |
| `jpvm` | 117 | `server` / DN42 / 公网入口 | `36.50.85.113` | JP VPS；`zhyi.cc` 通配符公网入口。 |
| `cnvm` | 119 | `server` / 公网入口 | `cnvm.zhyi.cc` | CN VPS；`zhyi.xin` 公网入口；运行 Dex、Pocket ID 与 Vaultwarden。 |
| `colocrossing` | 120 | `server` / DN42 / 公网入口 | `203.55.176.158` | SG VPS；公共服务、监控栈与 ZeroTier controller。 |
| `usvm` | 121 | `server` / 公网入口 / 日志 | `35.212.152.140` | US VPS（GCP）；运行低资源 Elasticsearch 日志入口。 |

家庭局域网地址、MAC 与 DHCP 边界以 [家庭局域网 IP 规划](./home-lan-ip-plan.md)
为准；LTNET、ZeroTier、WireGuard 与 DN42 关系以
[网络参照](./network-reference.md) 为准。

## 关键字段

| 字段 | 作用 |
| --- | --- |
| `index` | 稳定主机编号；用于 LTNET、ZeroTier 静态地址和 WireGuard 接口命名。 |
| `tags` | 决定导入 server/client/builder 等模块。 |
| `hostname` | Colmena 默认 SSH 目标；DNS 或 IP 改动必须同步检查。 |
| `ssh.ed25519` | SSH host key，不是登录私钥。重装后需重新采集并提交。 |
| `interconnect` | 家庭 LAN 直连地址；VM 位于 Router VM 后的 `192.168.0.0/24`。 |
| `zerotier` / `ltnet` | ZeroTier 成员和 LTNET/WireGuard/BIRD 对等关系。 |
| `public` / `dn42` | 仅拥有对应地址和路由条件时声明。 |
| `manualDeploy` | 该机不应被默认部署选择器误操作；仍可显式 `--on <host>`。 |

## 新主机流程

新设备不要复用现有 `host.nix` 中的地址或密钥。按
[新主机接入规范](./new-host-standard.md) 先确认磁盘、持久 SSH host key、SOPS
recipient 与网络，再添加 host 元数据和硬件配置。物理 client 的首次安装必须从
安装环境完成目标文件系统布局，不能从普通 ext4 根在线切换到 tmpfs/preservation。
