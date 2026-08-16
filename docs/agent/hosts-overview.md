# 当前 hosts 概览

`hosts/<name>/host.nix` 保存主机元数据，`configuration.nix` 保存主机配置，
`hardware-configuration.nix` 保存硬件与文件系统信息。`hosts/` 只保存自有
主机；作者原版的独立 checkout 位于仓库上级目录 `../nixos-config-exam`，仅用于人工
对照，不参与当前 flake 求值或部署。

## 当前自有拓扑

当前 `hosts/` 中声明的主机如下。`Makefile` 沿用作者的 Colmena 标签目标，并增加
安全的默认帮助；实际部署命令见 [构建与部署](deployment.md)。

| 主机 | index | 角色 | 主机元数据地址 | 说明 |
| --- | ---: | --- | --- | --- |
| `router` | 112 | 家庭路由器 | `192.168.0.1` | PPPoE、LAN 网关、DHCP、DNS、DDNS 与 qBittorrent 单实例。 |
| `ml-2700` | 113 | `client` | `ml-2700.zhyi.cc` | 家庭客户端，LAN 地址 `192.168.0.53`。 |
| `ml-builder` | 114 | `nix-builder` | `ml-builder.zhyi.cc` | 强构建机，28 vCPU；Hydra 与 x86-only 容器（ArchiveTeam/ClawEmail/Epic Awesome Gamer）自 2026-08-12 起运行于此。 |
| `ml-home-vm` | 115 | x86_64 / 家庭服务 VM | ~~`192.168.0.51`~~ | 已退役（2026-08-03）：应用迁至 ROCK5C/OPI5P/PVE，主机定义已从 flake 移除；`*.ml-home-vm.zhyi.cc` 服务别名由 ROCK 5C 继续承载。 |
| `pve-5700u` | 116 | PVE | `pve-5700u.zhyi.cc` | PVE 宿主（仅虚拟化）；Hydra 与本机构建能力已迁至 ml-builder。 |
| `hostdare` | 117 | `server` / DN42 / 公网入口 | `36.50.85.113` | JP VPS；`zhyi.cc` 通配符公网入口。 |
| `volcengine` | 119 | `server` / 公网入口 | `volcengine.zhyi.cc` | CN VPS；`zhyi.xin` 公网入口；运行 Dex、Pocket ID 与 Vaultwarden。 |
| `greencloud` | 120 | `server` / DN42 / 公网入口 | `203.55.176.158` | SG VPS；公共服务、协作内容链路与 ZeroTier controller（监控栈 2026-08-14 迁至 tencent）。 |
| `google` | 121 | `server` / 公网入口 / 日志目标 | `35.212.152.140` | US VPS（GCP）；Filebeat 目标仍指向此机，但当前未部署 Elasticsearch，日志链待修复。 |
| `opi5p` | 122 | RK3588 / reDroid | `192.168.0.62` | Orange Pi 5 Plus；vendor kernel、Mali GPU，以及不依赖 eMMC 的 SPI + NVMe 启动。 |
| `rock5c` | 123 | RK3588 / 家庭边缘 | `192.168.0.64` | Radxa ROCK 5C；边缘代理、控制链、MetaCubeXD 与 reDroid。 |
| `lubancat1` | 124 | RK3566 / `server` / `low-ram` | `192.168.0.65` | 原版 LubanCat-1（非 V2），2 GiB RAM、无 eMMC；server 基线已上线，尚未迁入用户应用。 |
| `h28k` | 125 | RK3528 / 异地路由器（预部署） | WAN DHCP / LAN `192.168.30.1` | HINLINK H28K；双千兆口、Kea、CoreDNS 与 nftables NAT；SSH/SOPS/ZeroTier 身份已采集（08-04 修正 ZeroTier 身份），仍在家中 staging（临时 SSH 放行规则保留），待迁异地站点。 |
| `opi03` | 126 | H618 / reDroid 实验设备 | DHCP（未固定） | Orange Pi Zero 3；本地 Android 镜像和硬件加速仍在开发，尚未完成正式网络身份与实机验收。 |
| `taishanpi` | 127 | RK3566 / 暂停维护 | 未定（Wi-Fi bring-up） | LCKFB Taishan Pi（泰山派）；无有线网卡，Wi-Fi/MIPI 适配中；2026-08 起暂停维护。 |
| `tencent` | 128 | `server` / 公网入口 / DN42 | `tencent.zhyi.cc` | 腾讯云首尔 VPS（2C/4G，AS132203）；DN42 节点、cn-accel 出口、监控中心（Prometheus/Grafana 自 greencloud 迁入，2026-08-14）；2026-08-13 重装完成，host key/ZeroTier 已回填，LTNET mesh 已接入（hostdare 不可达期间除外）。 |

家庭局域网地址、MAC 与 DHCP 边界以 [家庭局域网 IP 规划](home-lan-ip-plan.md)
为准；LTNET、ZeroTier、WireGuard 与 DN42 关系以
[网络参照](reference.md) 为准。

服务实际运行位置和跨主机依赖以
[全主机服务归属与链路](fleet-service-chain.md) 为准。旧服务域名中包含
主机名不表示服务仍运行在该主机，例如多个 `*.ml-home-vm.zhyi.cc` 入口已由 ROCK 5C
承载并反代到 OPI5P 或 PVE。

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
[新主机接入规范](new-host-standard.md) 先确认磁盘、持久 SSH host key、SOPS
recipient 与网络，再添加 host 元数据和硬件配置。物理 client 的首次安装必须从
安装环境完成目标文件系统布局，不能从普通 ext4 根在线切换到 tmpfs/preservation。
