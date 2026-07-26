# Prometheus / Grafana 监控链路

本文描述当前仓库的监控链路和操作边界。配置来源是
`nixos/minimal-components/prometheus-exporters.nix`、
`nixos/optional-apps/prometheus/`、`nixos/optional-apps/grafana.nix` 与
`hosts/colocrossing/`。

## 拓扑

```text
各非 client NixOS 主机
  └─ node exporter（LTNet IPv4:9100）

服务专用 exporter（BIRD、CoreDNS、PostgreSQL、MySQL、WireGuard、SMART、ARR 等）
  └─ LTNet IPv4 上的对应端口

colocrossing
  ├─ Prometheus：拉取所有 exporter，并保存 365 天或最多 10 GiB 数据
  ├─ Blackbox exporter：每分钟探测已声明的 HTTPS、DNS、Gopher、WHOIS 入口
  ├─ Alertmanager：向 Telegram 发送告警和恢复通知
  └─ Grafana：通过 Dex 登录，公开入口为 dashboard.zhyi.cc
```

Prometheus、Alertmanager 和 Grafana 只监听本机，由 `colocrossing` 的 Nginx
虚拟主机提供入口。不要为了监控直接向公网开放 exporter 端口。

Elasticsearch 日志链路与监控栈彼此独立。Filebeat 将日志发送到
`es-ingest.usvm.zhyi.cc`，Elasticsearch 运行在低资源 `usvm` 上，使用按日索引并
只保留最近 3 天。不要把 Elasticsearch 数据目录或入口重新指向家庭 VM。

## 声明规则

- 非 `client` 主机自动启用 node exporter，不要为每台 server 重复声明。
- `scrape-configs.nix` 通过 NixOS option 自动发现已启用的 exporter。新服务应在
  自己的模块中声明 exporter，不要把 IP 手写进 Prometheus。
- Blackbox 只保留实际入口。受 Dex 或应用认证保护的入口可以返回正常重定向。
- 没有在任一 host 启用的静态抓取目标必须删除，不能留下永久 `down`。
- node exporter 连续 15 分钟不可抓取会触发告警。应修复网络或正式移除主机，
  不能通过删探针制造绿色面板。
- 局域网外的 LTNet peer 使用 `wg-mesh-wstunnel` 的 WSS/TCP 传输。可用性以
  WireGuard 最近握手和 BIRD `Established` 为准，不能只看 wstunnel `active`。

## 日常核查

从构建机经 SSH 登录 `colocrossing` 后执行：

```bash
systemctl is-active prometheus alertmanager grafana
curl -fsS http://127.0.0.1:9090/-/ready

curl -fsS 'http://127.0.0.1:9090/api/v1/targets?state=active' \
  | jq -r '.data.activeTargets[] | select(.health != "up")
    | [.labels.job, .labels.instance, .lastError] | @tsv'

curl -fsS http://127.0.0.1:9090/api/v1/alerts \
  | jq -r '.data.alerts[] | [.state, .labels.alertname, .labels.instance] | @tsv'
```

入口：

- `https://dashboard.zhyi.cc`
- `https://prometheus.zhyi.cc`
- `https://alert.zhyi.cc`

三者均使用 Dex 身份认证。Homepage 只链接这些入口，不链接 exporter 或本地监听
地址。

## 变更与验证

监控栈变更先在 `pve-5700u` 构建：

```bash
cd /nix/src/nixos-config
nix build .#nixosConfigurations.colocrossing.config.system.build.toplevel -L
```

只部署 `colocrossing`，等待一个 scrape interval 后再复核。LTNet、DNS、HTTPS
入口或证书同步异常应在对应链路修复，不能放宽探针条件来掩盖。
