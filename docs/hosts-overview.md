# hosts 目录机器分类

这篇文档用来快速理解原作者 `hosts/` 目录里的机器布局。每台机器的入口是：

```text
hosts/<机器名>/host.nix
```

`host.nix` 不是系统配置本体，而是“主机元数据”：机器编号、角色标签、CPU 线程数、SSH host 公钥、是否公网、是否 DN42、是否内网机器、是否手动部署等。

当前仓库一共有 30 台 host。

## 1. 角色标签

常见标签大概是这些：

| 标签 | 含义 |
| --- | --- |
| `server` | 服务器机器，会导入 server 类模块 |
| `client` | 桌面/客户端机器，会导入 client 类模块 |
| `nix-builder` | Nix 远程构建机 |
| `dn42` | 接入 DN42 网络 |
| `public-facing` | 有公网服务入口 |
| `lan-access` | 家里/内网可访问机器 |
| `low-disk` | 低磁盘机器，需要减少磁盘占用 |
| `low-ram` | 低内存机器，需要减少内存压力 |
| `ipv4-only` | 只有 IPv4 或主要按 IPv4 使用 |

有些机器 `tags = [ ];`，这不代表没用，而是它们可能是 PVE、路由器、缓存机等特殊机器，系统配置在各自目录里处理。

## 2. 公网/云服务器

这些机器主要跑在 VPS、云厂商或托管机房里，承担公网服务、DN42 节点、反代、监控、网络互联等角色。

| 机器 | 位置 | 主要标签 | 用途理解 |
| --- | --- | --- | --- |
| `alice` | 香港 | `server`, `public-facing`, `dn42` | 公开服务 + DN42 节点 |
| `buyvm` | 瑞士 Bern | `server`, `dn42`, `low-disk`, `low-ram` | 小规格 VPS，兼顾 DN42 |
| `bwg-lax` | 洛杉矶 | `server`, `public-facing`, `dn42` | 美国公网节点 |
| `colocrossing` | 纽约 | `server`, `public-facing`, `dn42` | 公网节点，CPU 线程更多 |
| `terrahost` | 挪威 Sandefjord | `server`, `public-facing` | 欧洲公网节点 |
| `v-ps-sea` | 西雅图 | `server`, `public-facing` | 美国西海岸公网节点 |
| `virmach-ny1g` | 纽约 | `server`, `dn42` | 纽约 DN42/VPS 节点 |
| `virmach-ny6g` | 纽约 | `server`, `ipv4-only` | IPv4 VPS 节点 |
| `zgocloud` | 香港 | `server`, `public-facing`, `ipv4-only` | 香港 IPv4 公网节点 |
| `azure-vm1` | 香港 | `server`, `ipv4-only` | Azure 节点，接入 azure-oci interconnect |
| `azure-vm2` | 香港 | `server`, `ipv4-only` | Azure 节点，接入 azure-oci interconnect |
| `azure-vm3` | 香港 | `server`, `ipv4-only`, `aarch64-linux` | ARM Azure/OCI 入口，使用自定义 SSH 端口 |
| `oracle-vm1` | 东京 | `server`, `public-facing`, `dn42` | Oracle 日本公网/DN42 节点 |
| `oracle-vm2` | 东京 | `server`, `public-facing` | Oracle 日本公网节点 |
| `oracle-vm-arm1` | 东京 | `server`, `nix-builder`, `aarch64-linux` | ARM 服务器，同时作为远程构建机 |

这一组通常会配置：

```nix
public = { ... };
dn42 = { ... };
zerotier = "...";
interconnect = { ... };
```

如果你只是先复刻自己的桌面机，这一类很多字段都不用急着填。

## 3. 家里/内网机器

这些机器大多在作者家里，位置是 `US Bellevue`，通过 `home-lan`、ZeroTier、内网 IPv4/IPv6 组织起来。

| 机器 | 主要标签 | 用途理解 |
| --- | --- | --- |
| `lt-home-vm` | `server`, `lan-access` | 作者的家里主服务器/大 VM，64 线程 |
| `lt-home-builder` | `nix-builder`, `lan-access` | 家里强构建机，64 线程 |
| `ml-home-vm` | `server`, `lan-access`, `nix-builder` | 你的家庭服务 VM，并兼作远程构建机 |
| `ml-builder` | `nix-builder`, `lan-access` | 你的强机器/虚拟机构建机 |
| `lt-home-rdp` | `client`, `lan-access` | 远程桌面/客户端机器 |
| `lt-home-router` | 无标签 | 家里路由器，手动部署 |
| `lt-home-lancache` | `lan-access` | 局域网缓存/加速类机器 |
| `lt-home-lte` | `lan-access` | LTE/网络相关内网设备 |
| `lt-rpi4` | `lan-access`, `aarch64-linux` | 树莓派 4，内网 ARM 设备 |
| `lt-dell-wyse` | `client` | 轻客户端/桌面机 |
| `lt-dell-wyse-thin` | 无标签 | 低功耗 thin client，手动部署 |
| `lt-hp-omen` | `client` | 作者主力桌面/客户端，16 线程 |
| `pve-epyc` | 无标签 | Proxmox/虚拟化大机器，128 线程 |
| `pve-c3758` | 无标签 | Proxmox/虚拟化或网络设备 |
| `pve-hp-z220-sff` | 无标签 | Proxmox/旧工作站类设备 |
| `ml-2700u` | `client` | 你的 Ryzen 7 2700U 客户端机器 |

这一组常见字段：

```nix
hostname = "192.168.x.x";
manualDeploy = true;
firewalled = true;
interconnect = {
  name = "home-lan";
  IPv4 = "192.168.x.x";
};
```

`manualDeploy = true` 表示这台机器不适合自动批量部署，通常需要你手动在机器上 `nixos-rebuild switch`。

## 4. 客户端/桌面机

带 `client` 标签的机器会进入作者的客户端配置体系，包含桌面环境、GUI 软件、输入法、浏览器、音频、KDE/GNOME 之类的组件。

| 机器 | CPU 线程 | 说明 |
| --- | ---: | --- |
| `lt-hp-omen` | 16 | 作者的主力客户端 |
| `lt-home-rdp` | 8 | 远程桌面客户端 |
| `lt-dell-wyse` | 4 | 轻客户端 |
| `ml-2700u` | 8 | 你的 KDE 开发办公客户端 |

你现在适配的 `ml-2700u` 属于这一类。它应该优先保证：

- SSH 能登录
- 桌面能启动
- AMD 核显驱动正常
- 基础开发办公软件可用
- 不误启用 DN42、public、interconnect 等还没准备好的网络模块

## 5. 构建机

带 `nix-builder` 标签的机器用于远程构建 Nix derivation，解决弱机器本地编译太慢、内存不够的问题。

| 机器 | 架构 | CPU 线程 | 说明 |
| --- | --- | ---: | --- |
| `lt-home-builder` | `x86_64-linux` | 64 | 家里强构建机 |
| `ml-builder` | `x86_64-linux` | 6 | 你的强机器/虚拟机构建机 |
| `oracle-vm-arm1` | `aarch64-linux` | 2 | ARM 架构构建机/服务器 |

你现在自己的路线里，强机器/虚拟机也可以做同样角色。等稳定后，可以新增一个类似：

```text
hosts/<your-builder>/host.nix
```

并打上：

```nix
tags = with tags; [
  lan-access
  nix-builder
];
```

## 6. PVE/虚拟化机器

这些机器名字以 `pve-` 开头，通常不是普通 `server` 或 `client`，而是虚拟化底座。

| 机器 | CPU 线程 | 说明 |
| --- | ---: | --- |
| `pve-epyc` | 128 | 大型 EPYC 虚拟化主机 |
| `pve-c3758` | 8 | 低功耗虚拟化/网络主机 |
| `pve-hp-z220-sff` | 4 | HP 小型工作站虚拟化主机 |

它们通常 `manualDeploy = true`，避免自动部署误动底层虚拟化宿主机。

## 7. 网络字段怎么理解

`host.nix` 里常见的网络字段：

| 字段 | 含义 | 什么时候填 |
| --- | --- | --- |
| `hostname` | 部署/SSH 默认连接地址 | 没有可用域名时填 IP |
| `ssh.ed25519` | 目标机器 SSH host 公钥 | 机器 sshd host key 确定后填 |
| `zerotier` | ZeroTier node id | 机器加入 ZeroTier 后填 |
| `public.IPv4` / `public.IPv6` | 公网地址 | 有公网地址且要作为公网节点时填 |
| `firewalled` | 公网不可直连或在 NAT 后 | 有网络限制时填 |
| `interconnect` | 作者自己的跨机房/家庭互联网络 | 你自己搭好同类网络后再填 |
| `dn42` | DN42 地址和区域 | 接入 DN42 后再填 |
| `additionalRoutes` | 额外静态路由 | 只有网络模块需要时填 |

对于你自己的普通桌面机，最小可用版本通常只需要：

```nix
{
  index = 113;
  tags = with tags; [ client ];
  cpuThreads = 8;
  hostname = "192.168.3.237";
  city = geo.cities."US Bellevue";
  manualDeploy = true;
  ssh.ed25519 = "ssh-ed25519 AAAA...";
}
```

## 8. 你适配新机器时的顺序

1. 先新建 `hosts/<name>/host.nix`，只填最小字段。
2. 用 `nixos-generate-config` 生成硬件配置。
3. 确认能 SSH 登录后，填 `ssh.ed25519`。
4. 如果是桌面机，加 `client` 标签。
5. 如果是服务器，加 `server` 标签。
6. 如果是构建机，加 `nix-builder` 标签。
7. ZeroTier、公网、DN42、interconnect 后面再接，不要一开始全开。
