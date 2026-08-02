# Home LAN IP Plan

家庭网络统一使用 `192.168.0.0/24`。Router VM 直连光猫并作为
`192.168.0.1` 网关，PVE 的 `br-lan` 将物理设备和 VM 接入同一 LAN。基础设施
使用 DHCP 池外的静态地址，Router 的 DHCP 池为 `192.168.0.100-249`。

## 家庭 LAN

| Address | Host | Status |
| --- | --- | --- |
| `192.168.0.1` | `router` VM | 网关 / NAT / DDNS |
| `192.168.0.2` | `pve-5700u` | PVE 宿主 / Hydra |
| `192.168.0.40` | QNAP NAS | NFS 与 S3 存储 |
| `192.168.0.50` | `ml-builder` | 强构建机 |
| `192.168.0.51` | `ml-home-vm` | 家庭服务 VM |
| `192.168.0.53` | `ml-2700` | 客户端 |
| `192.168.0.62` | `opi5p` | RK3588 应用与数据节点 |
| `192.168.0.64` | `rock5c` | RK3588 边缘与控制节点 |
| `192.168.0.65` | `lubancat1` | RK3566 适配节点 |

## 备注

- `ml-home-vm` 的 NFS 挂载源为 `192.168.0.40:/nixos`。
- ARM 板卡统一从 `192.168.0.60` 起分配静态地址，不占用原 VM 地址。
- 部署 `ml-home-vm` 前需在 QNAP NFS export 中放行对应客户端地址。
- Router VM 提供 IPv6 RA 广播，VM 通过 SLAAC 获取 IPv6 地址。
- `colocrossing` 已迁移到 SG 公网节点，不占用家庭 LAN 地址。
