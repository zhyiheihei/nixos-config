# Home LAN IP Plan

家庭网络分为两层：

- **物理 LAN**（`192.168.2.0/24`）：光猫/OpenWrt 为网关，PVE 宿主机和 NAS 位于此层。
- **虚拟 LAN**（`192.168.0.0/24`）：Router VM 为网关（`192.168.0.1`），通过 PVE
  `br-lan` 桥接，VM 服务位于此层。MTU 全链路 9000。

## 物理 LAN（192.168.2.0/24）

| Address | Host | Status |
| --- | --- | --- |
| `192.168.2.2` | OpenWrt 路由器 | 网关 |
| `192.168.2.50` | `ml-builder` | 强构建机 |
| `192.168.0.2` | `pve-5700u` | PVE 宿主 / Hydra |
| `192.168.2.93` | QNAP NAS | NFS 与 S3 存储 |

## 虚拟 LAN（192.168.0.0/24，Router VM 后）

| Address | Host | Status |
| --- | --- | --- |
| `192.168.0.1` | `router` VM | 网关 / NAT / DDNS |
| `192.168.0.51` | `ml-home-vm` | 家庭服务 VM |
| `192.168.0.52` | `colocrossing` VM | Attic / 家庭入口 |
| `192.168.0.55` | `logvm` | 日志 / 基础服务 |

## 备注

- `ml-home-vm` 的 NFS 挂载源为 `192.168.2.93:/nixos`（跨子网经 Router VM NAT
  访问 NAS），`clientaddr=192.168.2.51`。
- 部署 `ml-home-vm` 前需在 QNAP NFS export 中放行对应客户端地址。
- Router VM 提供 IPv6 RA 广播，VM 通过 SLAAC 获取 IPv6 地址。
