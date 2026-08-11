# 事故：Router eth0 LAN 口掉链（r8125 NETDEV WATCHDOG）

> 日期：2026-08-11。对象：家庭 router（NanoPi R5C / RK3568 / r8125 9.018.00-NAPI-DASH）。
> 现象：LAN 口掉，指示灯不亮；用户重启后恢复。本文记录重启前日志与嫌疑点。

## 重启前日志时间线（boot -1，2026-08-11 17:40:44）

- `r8125 0001:11:00.0 eth0: NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out 6004 ms`
- `r8125 0001:11:00.0 eth0: Transmit timeout reset Device!`
- `r8125 0001:11:00.0 eth0: Device reseting!`
- `systemd-networkd: eth0: Lost carrier`
- `br-lan: port 1(eth0) entered disabled state`

超时前没有 PHY/EEE/PCIe AER 报错，链路此前一直 2.5G up。全量 journal 里这是第一次
r8125 触发 NETDEV WATCHDOG；此前的 link down 主要来自重启、PPPoE 重拨或 wlan。

## 重启后状态

- boot 0：eth0/eth1 均 2.5G up，仍为 r8125；无新 NETDEV WATCHDOG；
  `router-flowtable`/`router-rps`/`pppd-wan` active。
- 但 `ethtool --show-eee` 显示 eth0/eth1 的 EEE 仍为 enabled，eth1 为 active。

## 嫌疑点

1. EEE 关闭没有真正落到链路层
   - `disable-eee.service` 在 eth0/eth1 设备出现后、链路 up 前执行成功；链路协商后驱动重新开启 EEE。
   - 调研 [01-openwrt-nanopi-r5c](./01-openwrt-nanopi-r5c.md) 的调优配方明确要求 EEE off；
     RTL8125B PHY 固件存在 EEE 低功耗唤醒失败导致的载波丢失记录。
2. PCIe ASPM L1 开着
   - 两个 RTL8125 的 `LnkCtl` 都是 `ASPM L1 Enabled`。
   - NUR r8125 源码默认 `CONFIG_ASPM=y`、`ENABLE_EEE=y`，当前 derivation 没有覆盖。
   - OpenWrt 官方 r8125 Makefile 使用 `CONFIG_ASPM=n`；调研 01 也记录 vendor r8125
     在其他平台有 NETDEV WATCHDOG TX timeout，且 issue #22110 的 R6S r8125-rss
     反复 link flap，换回 r8169 解决。

## 可选处理

- 方案 A（保留 r8125）：构建时覆盖 `CONFIG_ASPM=n ENABLE_EEE=n`，并把 EEE off
  放到链路 up 后/定时重设；下个维护窗口重启验证。
- 方案 B（回滚 r8169）：OpenWrt 官方 R5C 默认驱动，研究里 r8169 更稳；
  移除 blacklist、改回 r8169 后重启。
- 即时缓解：`ethtool --set-eee eth0 eee off; ethtool --set-eee eth1 eee off`
  可临时关 EEE，但驱动 reset 后可能恢复，仍需修服务顺序。

## 未完成

- 未确认超时前是否有瞬时流量/中断触发；Prometheus 未取到该窗口的数据。
- r8125 2.5G hairpin 吞吐复测仍未做。
- “重启变关机”事故仍待观察。
