# 成功案例：R5C Router 启用 nftables flowtable 前后的对照

> 日期：2026-08-11。对象：家庭核心 router（NanoPi R5C / RK3568 / PPPoE + br-lan / nftables）。
> 部署提交：`ca84caad`（origin/master）。本文件记录对照方法、结果与未完成项。

## 结论

- 在受控 hairpin iperf3 回路中，开启 flowtable/RPS 后吞吐小幅提升约 2-3%，TCP 重传下降 97-99%。
- 软中断（aggregate）采样反而偏高，RPS 分散和 ingress hook 造成混淆，不作为提速证据；per-core/真实 WAN 对照仍未完成。
- 部署、PPPoE 重拨自愈、回滚路径均已验证，属于一次成功上线案例。

## 对照方法

- 公网 iperf3 测试点在当前网络不可用（`iperf.he.net`/`iperf.online.net` busy，其他不可达），改用受控 hairpin 回路：
  - rock5c 上 `iperf3 -s -B 192.168.0.64 -p 5201`
  - router 临时加 hairpin DNAT：WAN IP `122.246.115.27:5201` -> `192.168.0.64:5201`
  - rock5c 客户端连 `122.246.115.27:5201`，流量经 router DNAT/hairpin 往返
- 对照组为同一内核（6.18.42）下“fast path 开启” vs “关闭 flowtable/RPS 并复位 sysctl”，消除内核版本差异。
- 每组：`iperf3 -t 15/-t 20`，`-P 1` 与 `-P 4`；router CPU 用 `top -bn1` 5 次采样取中位。

## 结果

| 场景 | 基线（关闭） | 开启 | 变化 |
| --- | ---: | ---: | ---: |
| Forward P4（receiver） | 889 Mbit/s | 913 Mbit/s | +2.7% |
| Forward P4 重传 | 17732 | 493 | -97.2% |
| Reverse P4（receiver，两轮中位） | ~896 Mbit/s | ~914 Mbit/s | +2.0% |
| Reverse P4 重传 | 11967 | 104 | -99.1% |
| Reverse P1（receiver） | 879 Mbit/s | 904 Mbit/s | +2.8% |
| 基线 CPU（软中断中位） | ~22.7% | - | - |
| 开启 CPU（软中断中位） | - | ~31.1% | 偏高，不作为提速证据 |

注：吞吐为 hairpin 回路约 900M 级，可能受 rock5p 单机 client/server 与 1G 路径限制；重传下降是稳定性收益的主要证据。真实 WAN 高负载场景的收益预期更大（参考 OpenWrt 社区 331 Mbit/s -> 1.73 Gbit/s），仍需实测。

## 已完成的验证

- 新内核 `6.18.42`，`NF_FLOW_TABLE`/`NF_FLOW_TABLE_INET`/`NFT_FLOW_OFFLOAD`/`TCP_CONG_BBR` 生效。
- `nftables`、`router-flowtable`、`router-rps`、`router-flowtable-check.timer` active；flowtable 含 `br-lan`+`ppp0`；forward 规则单条 `ct state { established, related } flow add @f`。
- RPS `f/4096`、backlog 5000、缓冲 16M、`rps_sock_flow_entries=4096`、BBR 生效。
- WAN：pppd active、网关 ping 0% 丢包、`baidu.com` 200。
- PPPoE 重拨自愈：`systemctl restart pppd-wan` 后 flowtable 与规则仍正确。
- 内网服务：`dav.opi5p.zhyi.cc` 401、`bt.router.zhyi.cc` 200、`vaults3.zhyi.cc:8443/health` hairpin 200。
- 回滚：extlinux 保留旧 generation；`nixos-rebuild --rollback boot` 后可回旧内核/配置。

## 验收（2026-08-11，只读，未重启）

- 当前运行：`system-51-link` / kernel `6.18.42`；eth0/eth1 均绑定 r8125；`dmesg` 的 NETDEV WATCHDOG 计数为 0；无 failed units。
- flowtable/RPS 生效：`nftables`、`router-flowtable`、`router-flowtable-check.timer`、`router-rps`、`pppd-wan` active；flowtable 为 `br-lan`+`ppp0`，forward 有 `flow add @f`；RPS `f/4096`、backlog 5000、缓冲 16M、BBR。
- 网络可达：PPPoE 在线，`223.5.5.5` 0% 丢包，`baidu.com` 200；从 rock5c 实测 LAN hairpin：`dav.opi5p.zhyi.cc` 401、`bt.router.zhyi.cc` 200、`vaults3.zhyi.cc:8443/health` 200。
- 回滚路径：extlinux 保留 generation 50（`nixos-50-default`），`r8169.ko` 仍在 closure；切回 r8169 是一行配置改动，但需要维护窗口重启。
- MAC 核实与处理：两个口的 EEPROM 永久地址分别为 eth0 `36:57:34:66:a7:af`、eth1 `72:e9:d6:2c:3a:38`；r8125 探测时读不到 EEPROM 并生成临时地址，eth1 靠 `10-router-wan.link` 固定为 `02:c8:90:df:19:eb`，eth0 当前为 udev persistent 策略生成的 `aa:88:6c:c7:9b:47`。旧 r8169 启动日志同样存在“can't read MAC address, setting random one”，说明这是 R5C 这块板卡/驱动共有的读取限制，不是 r8125 独有回归。按 systemd.link 文档，persistent 策略对同一 machine-id/同一设备跨重启稳定，因此不是每次随机；已新增 `10-router-lan.link` 改为显式固定到 EEPROM 永久地址，待下次维护窗口重启验证。
- 未查明：用户反映“重启变成关机”。`journalctl -b -1` 显示 r8125 加载后进入正常启动，无 panic/WATCHDOG/poweroff 记录，当前无法从日志定位；需要继续观察 24-72h，暂不重启。

## 未完成 / 待办

- 公网 iperf3 前后对照（当前测试点不可用；需可用公网 server 或自有 VPS 起 iperf3）。
- 真实 WAN NAT 场景对照（LAN 多设备 + WAN 下载/上传）。
- CPU per-core、单队列 vs RPS、以及 flowtable 命中前后 `/proc/net/softnet_stat` 的严格采样。
- 48 小时稳定性观察（服务、flowtable 条目、PPPoE 重拨次数、内存）。
- vendor r8125 驱动 A/B 未闭环：eth0 已加 `10-router-lan.link` 固定 EEPROM MAC，待重启验证；2.5G hairpin 吞吐复测未做；“重启变关机”事故未定位。
- BBRv3、TCP Brutal、Clang/ThinLTO、nft-fullcone 未实施（记录见调研文档 02）。
- `nanopi-r5c/kernel-config` 同时被 taishanpi/lubancat/h28k 复用，改动会影响这些板卡（当前无行为风险，需留意发布范围）。

## 相关文件

- `hosts/router/flowtable.nix`、`hosts/router/performance.nix`、`hosts/router/configuration.nix`
- `nixos/hardware/nanopi-r5c/kernel-config`
- 调研：`docs/research/01-openwrt-nanopi-r5c.md`、`02-r5s-cooluc.md`、`03-istoreos-r5c.md`
