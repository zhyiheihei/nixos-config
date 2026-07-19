# 当前 hosts 概览

`hosts/<name>/host.nix` 保存主机元数据，`configuration.nix` 保存主机配置，
`hardware-configuration.nix` 保存硬件与文件系统信息。`hosts/` 只保存 8 台自有
主机；作者参考配置位于 `hosts-exam/`，不生成可部署的 NixOS configuration。

## 当前自有拓扑

当前日常在线主机为：
`ml-builder`、`ml-home-vm`、`pve-5700u`、`colocrossing`、`jpvm`、`logvm`、`cnvm`。
`pve-2700` 是自有保留主机。`Makefile` 沿用作者的 Colmena 标签目标，并增加安全的
默认帮助；实际部署命令见 [构建与部署](./deployment.md)。

| 主机 | index | 角色 | 主机元数据地址 | 说明 |
| --- | ---: | --- | --- | --- |
| `ml-builder` | 114 | `nix-builder` | `ml-builder.zhyi.cc` | 强构建机，28 vCPU；不运行自动 Attic watch-store。 |
| `ml-home-vm` | 115 | `server` | `ml-home-vm.zhyi.cc` | 家庭应用 VM 与 NCPS；不参与远程构建。 |
| `pve-5700u` | 116 | `nix-builder` / PVE | `pve-5700u.zhyi.cc` | PVE 宿主、Hydra 与本机构建能力。 |
| `colocrossing` | 18 | `server` / DN42 / 公网入口 | `colocrossing.zhyi.cc` | Attic、家庭入口与 LTNET 路由反射端。 |
| `jpvm` | 117 | `server` / DN42 / 公网入口 | `36.50.85.113` | JP 公网入口及 LTNET 中继。 |
| `cnvm` | 119 | `server` / DN42 / 公网入口 | `cnvm.zhyi.cc` | `zhyi.xin` 公网入口；运行 Dex、Pocket ID 与 Vaultwarden。 |
| `logvm` | 118 | `server` | `logvm.zhyi.cc` | 家庭网络内的日志/基础服务节点。 |
| `pve-2700` | 113 | PVE 保留主机 | `pve-2700.zhyi.cc` | 不属于日常部署集合；仅在机器状态明确时单独处理。 |

家庭局域网地址、MAC 与 DHCP 边界以 [家庭局域网 IP 规划](./home-lan-ip-plan.md)
为准；LTNET、ZeroTier、WireGuard 与 DN42 关系以
[网络参照](./network-reference.md) 为准。

## 保留的作者参考主机

以下 host 位于 `hosts-exam/`，用于复刻作者模块、硬件与网络结构，不是可部署的
自有机器。部分旧模块仍通过兼容元数据引用它们，但它们不会出现在 Colmena Hive：

| 类别 | 主机 |
| --- | --- |
| 作者公网/DN42 模板 | `alice`、`bwg-lax`、`terrahost`、`v-ps-sea`、`virmach-ny1g`、`virmach-ny6g`、`zgocloud` |
| 作者家庭客户端与设备模板 | `lt-dell-wyse`、`lt-dell-wyse-thin`、`lt-home-rdp`、`lt-hp-omen` |

这些目录可能包含作者的真实地址、SSH host key 与 DN42 元数据。不要为“清理”而修改它们；
新增自有机器应复制相近角色的结构，再替换为自己的硬件、地址和密钥。

## 关键字段

| 字段 | 作用 |
| --- | --- |
| `index` | 稳定主机编号；用于 LTNET、ZeroTier 静态地址和 WireGuard 接口命名。 |
| `tags` | 决定导入 server/client/builder 等模块。 |
| `hostname` | Colmena 默认 SSH 目标；DNS 或 IP 改动必须同步检查。 |
| `ssh.ed25519` | SSH host key，不是登录私钥。重装后需重新采集并提交。 |
| `interconnect` | 家庭 LAN 直连地址；当前为 `192.168.2.0/24`。 |
| `zerotier` / `ltnet` | ZeroTier 成员和 LTNET/WireGuard/BIRD 对等关系。 |
| `public` / `dn42` | 仅拥有对应地址和路由条件时声明。 |
| `manualDeploy` | 该机不应被默认部署选择器误操作；仍可显式 `--on <host>`。 |

## 新主机流程

新设备不要复用现有 `host.nix` 中的地址或密钥。按
[新主机接入规范](./new-host-standard.md) 先确认磁盘、持久 SSH host key、SOPS
recipient 与网络，再添加 host 元数据和硬件配置。物理 client 的首次安装必须从
安装环境完成目标文件系统布局，不能从普通 ext4 根在线切换到 tmpfs/preservation。
