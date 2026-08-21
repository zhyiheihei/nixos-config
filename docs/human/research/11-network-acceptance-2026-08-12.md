# 网络验收：内网 / 外网 / DNS / HTTP / 丢包（2026-08-12）

> 验收对象：家庭 router（NanoPi R5C / RK3568 / 2.5G RTL8125 / PPPoE）。
> 控制面经 OPI5P 或 LTNET；iperf 数据面走家庭局域网。

## 结论

- 内网 2.5G 基本贴线速；WAN 下载四流聚合约 981 Mbps，接近家宽上限。
- DNS、HTTP、IPv4/IPv6 连通均正常；公网丢包主要来自外部目标 ICMP 限速。
- Hairpin P16 多流重传仍有波动，router CPU/`rx_missed` 很低，判定为
  hairpin NAT/多队列乱序而非网卡丢包。

## 内网

| 项目 | 结果 |
| --- | --- |
| LAN ping | 100/100，0% 丢包，avg 0.305ms，max 0.497ms |
| 直连 P1 | 2.35 Gbit/s，0 重传 |
| 直连 P16 | 2.38-2.39 Gbit/s，重传 0-60（个别轮 1.9k） |
| Hairpin P1 | 1.90 Gbit/s |
| Hairpin P16 | 最新三轮中位数 2.31 Gbit/s，重传约 38k |
| UDP 直连 | 100M，抖动 0.09ms，0% 丢包 |
| UDP hairpin | 100M，抖动 0.007ms，0% 丢包 |

## DNS 与 HTTP

- 本地 CoreDNS：`router.zhyi.xin`/`opi5p.zhyi.xin` 解析正常，首次查询约 19ms。
- 外部递归：223.5.5.5 约 7ms，119.29.29.29 约 15ms。
- `bt.router.zhyi.xin`：200，TTFB 267ms。
- `vaults3.zhyi.xin:8443/health` hairpin：200，TLS 41ms，TTFB 45ms。
- 公网 HTTP：baidu TTFB 324ms，USTC TTFB 476ms。

## 外网与 IPv6

- WAN 下载：单流 724 Mbps，四流聚合 981 Mbps。
- WAN 上行：qBittorrent 真实采样 18 Mbps（非 ISP 上限测试）。
- 223.5.5.5：0% 丢包，avg 6.94ms。
- 119.29.29.29：0% 丢包，avg 8.08ms。
- baidu.com：5% 丢包，avg 87ms（ICMP 限速）。
- IPv6 AliDNS：0% 丢包，avg 11.4ms；IPv6 DNS 查询 15ms。

## 风险与后续

- Hairpin P16 重传波动：已通过 WAN-only flowtable + `fq_codel` 显著下降；
  仍需长时间观察。
- `rx_missed_errors`/drop 累计值：新增 `router-quality-check` 每分钟导出
  `router_quality_netdev_*`，可由 Prometheus 监控。
- NAPI `1200/30000`：新增 `router_quality_ping_*` 与 `router_quality_dns_query_ms`
  指标，持续观察 DNS/ICMP 延迟。
- WAN 上行上限：未找到稳定公网 iperf 端点，未测到 ISP 上限。

## 相关文件

- `hosts/router/quality-monitoring.nix`
- `hosts/router/prometheus.nix`
- `docs/research/router-r5c-tuning.md`
