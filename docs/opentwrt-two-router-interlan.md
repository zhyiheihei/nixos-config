# OpenWrt 两级路由网段互访配置

这篇文档记录两台 OpenWrt / iStoreOS 路由器分属两个 IPv4 网段时，如何配置成两个网段互访。

示例拓扑：

```text
一级路由 LAN: 192.168.2.2/24
一级路由网段: 192.168.2.0/24

二级路由 LAN: 192.168.3.1/24
二级路由上级口: 192.168.2.20/24
二级路由网段: 192.168.3.0/24
```

目标：

- `192.168.2.0/24` 可以访问 `192.168.3.0/24`
- `192.168.3.0/24` 可以访问 `192.168.2.0/24`
- 尽量不要继续依赖二级路由 NAT

## 1. 确认二级路由上级口地址

在二级路由执行：

```bash
ip -4 addr
ip -4 route
uci show network
```

确认二级路由接入一级网段的地址。本文示例是：

```text
192.168.2.20/24
```

同时确认二级路由 LAN 地址：

```text
192.168.3.1/24
```

## 2. 一级路由添加去二级网段的静态路由

在一级路由上添加：

```bash
uci add network route
uci set network.@route[-1].interface='lan'
uci set network.@route[-1].target='192.168.3.0/24'
uci set network.@route[-1].gateway='192.168.2.20'
uci commit network
/etc/init.d/network reload
```

验证：

```bash
ip -4 route get 192.168.3.1
```

预期类似：

```text
192.168.3.1 via 192.168.2.20 dev br-lan src 192.168.2.2
```

## 3. 二级路由关闭上级口 NAT

默认二级路由一般会把 LAN 流量 NAT 到上级网段，这会导致一级网段看不到真实的 `192.168.3.0/24` 客户端。

先备份配置：

```bash
ts=$(date +%Y%m%d-%H%M%S)
cp /etc/config/firewall /etc/config/firewall.bak-$ts
```

关闭二级路由 `wan` zone 的 masquerade。示例里 `wan` zone 是 `firewall.@zone[1]`，实际操作前先确认：

```bash
uci show firewall
```

关闭 NAT：

```bash
uci delete firewall.@zone[1].masq
uci commit firewall
/etc/init.d/firewall restart
```

验证 `wan` zone 里不再有：

```text
masq='1'
```

## 4. 二级路由放行一级网段访问二级网段

在二级路由上允许 `192.168.2.0/24` 访问二级 LAN：

```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Primary-LAN-to-Secondary-LAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest='lan'
uci set firewall.@rule[-1].src_ip='192.168.2.0/24'
uci set firewall.@rule[-1].dest_ip='192.168.3.0/24'
uci set firewall.@rule[-1].proto='all'
uci set firewall.@rule[-1].family='ipv4'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

如果需要从一级网段访问二级路由本机，例如 SSH 到 `192.168.3.1`，再加一条 input 规则：

```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Primary-LAN-to-Secondary-Router'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].src_ip='192.168.2.0/24'
uci set firewall.@rule[-1].proto='all'
uci set firewall.@rule[-1].family='ipv4'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

## 5. 二级路由添加回程路由

如果二级路由的上级口本身就在 `192.168.2.0/24`，它默认会认为整个 `192.168.2.0/24` 都是直连网段：

```text
192.168.2.0/24 dev phy0.1-sta0 src 192.168.2.20
```

这在一些环境里会出问题：一级网段客户端访问二级网段时，请求包经过一级路由转发到二级路由，但二级路由回包时可能直接从上级口找客户端，而不是交回一级路由 `192.168.2.2`。如果上级 Wi-Fi、桥接、AP 隔离或客户端策略不允许这种直连回包，就会出现：

```text
一级路由自己能访问二级路由
一级网段客户端访问二级路由超时
```

可以先临时验证单台客户端。假设当前一级网段客户端是 `192.168.2.211`：

```bash
ip route replace 192.168.2.211/32 via 192.168.2.2 dev phy0.1-sta0
ip route get 192.168.2.211
```

如果加完这条后客户端能直连 `192.168.3.1`，说明问题就是回程路由。

持久化时不要直接加 `192.168.2.0/24 via 192.168.2.2`，因为它和二级路由上级口的直连路由同前缀，可能不会按预期覆盖。可以拆成两条更具体的 `/25`：

```bash
ts=$(date +%Y%m%d-%H%M%S)
cp /etc/config/network /etc/config/network.bak-$ts

uci add network route
uci set network.@route[-1].interface='wwan'
uci set network.@route[-1].target='192.168.2.0'
uci set network.@route[-1].netmask='255.255.255.128'
uci set network.@route[-1].gateway='192.168.2.2'

uci add network route
uci set network.@route[-1].interface='wwan'
uci set network.@route[-1].target='192.168.2.128'
uci set network.@route[-1].netmask='255.255.255.128'
uci set network.@route[-1].gateway='192.168.2.2'

uci commit network
/etc/init.d/network reload
```

验证：

```bash
ip -4 route
ip -4 route get 192.168.2.211
```

预期 `192.168.2.211` 这类一级网段客户端会走一级路由：

```text
192.168.2.211 via 192.168.2.2 dev phy0.1-sta0 src 192.168.2.20
```

## 6. 验证互访

从一级路由验证：

```bash
ip -4 route get 192.168.3.1
ping -c 3 192.168.3.1
ssh admin@192.168.3.1 true
```

从二级路由验证：

```bash
ip -4 route get 192.168.2.2
ping -c 3 192.168.2.2
```

从一级网段客户端验证：

```bash
ssh admin@192.168.3.1
```

如果客户端 `ping` 不通，不一定代表路由失败。很多手机、电脑或 NAS 会默认丢弃 ICMP。优先用实际服务验证，例如 SSH、HTTP、SMB。

## 7. 排障 checklist

- 一级路由是否有 `192.168.3.0/24 via 192.168.2.20`
- 二级路由 `wan` zone 是否还开着 `masq='1'`
- 二级路由是否允许 `wan -> lan` 中来自 `192.168.2.0/24` 的流量
- 二级路由是否允许 `192.168.2.0/24` 访问路由器本机
- 一级网段客户端到 `192.168.3.0/24` 是否走一级路由
- 二级路由回一级网段客户端时是否走 `192.168.2.2`
- 客户端本机防火墙是否丢弃 ICMP 或目标服务端口

## 8. 本次实际配置摘要

本次环境中：

```text
一级路由: 192.168.2.2
二级路由 LAN: 192.168.3.1
二级路由上级口: 192.168.2.20
当前一级网段客户端: 192.168.2.211
```

已经验证：

```text
192.168.2.2 -> 192.168.3.1 通
192.168.3.1 -> 192.168.2.2 通
192.168.2.2 -> 192.168.3.128 通
192.168.2.211 -> 192.168.3.1 在添加临时回程路由后通
```

关键临时验证命令：

```bash
ip route replace 192.168.2.211/32 via 192.168.2.2 dev phy0.1-sta0
```
