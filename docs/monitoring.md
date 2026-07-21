# Prometheus / Grafana 监控链路

本文描述当前仓库的监控链路和操作边界。配置来源仍是
`nixos/minimal-components/prometheus-exporters.nix`、
`nixos/optional-apps/prometheus/` 与 `hosts/logvm/`。

## 拓扑

`logvm` 是唯一的监控节点，运行以下服务：

```text
各非 client NixOS 主机
  └─ node exporter（LTNet IPv4:9100）

服务专用 exporter（BIRD、CoreDNS、PostgreSQL、MySQL、WireGuard、SMART、ARR 等）
  └─ LTNet IPv4 上的对应端口

logvm
  ├─ Prometheus：拉取所有 exporter，并保存 365 天或最多 10 GiB 数据
  ├─ Blackbox exporter：每分钟探测已声明的 HTTPS、DNS、Gopher、WHOIS 入口
  ├─ Alertmanager：向 Telegram 发送告警和恢复通知
  └─ Grafana：通过 Dex 登录，公开入口为 dashboard.zhyi.cc
```

Prometheus、Alertmanager 和 Grafana 只监听本机；由 `logvm` 的 Nginx 虚拟主机
提供入口，并经既有公网反向代理链路发布。不要为了监控直接向公网开放 exporter
端口。

## 声明规则

- 非 `client` 主机自动启用 node exporter；不要为每台 server 单独复制 exporter
  配置。
- `scrape-configs.nix` 通过 NixOS option 判断专用 exporter 是否启用并自动加入
  Prometheus。新服务有官方 exporter 时，应让服务模块声明 exporter，而不是把
  IP 地址手写进 Prometheus。
- Blackbox 只保留实际对外提供的入口。受 Dex 或应用认证保护的入口仍可探测，
  但必须允许其正常重定向状态。
- 没有在任一 host 启用的静态抓取目标必须删除；否则采集页面会永久显示无意义的
  `down`。
- 主机级告警使用 Prometheus 固有的 `instance` 标签。不要在规则文案中引用未由
  抓取配置生成的 `alias`；`name` 只能用于确认实际 exporter 提供该标签的专用指标。
- node exporter 连续 15 分钟不可抓取会由 Alertmanager 告警。这是主机失联的基础
  信号；修复网络或正式移除主机后再让告警恢复，不能静默忽略。
- 对局域网外的 LTNet peer，WireGuard 经 `wg-mesh-wstunnel` 的 WSS/TCP 传输。
  WSS client 的本地 UDP 监听端口与 WireGuard peer 的 `Endpoint` 必须相同；改动
  `tcpTransportPeers` 后，除部署外还应确认 `systemd-networkd` 已重新加载该 peer。
  `wstunnel` 显示 `active` 本身不能证明 LTNet 已恢复，仍要以最近握手时间和 BIRD
  `Established` 为准。

## 日常核查

从构建机经 SSH 登录 `logvm` 后，以下命令均为只读：

```bash
systemctl is-active prometheus alertmanager grafana
curl -fsS http://127.0.0.1:9090/-/ready

# 非 up 的抓取目标和错误原因
curl -fsS 'http://127.0.0.1:9090/api/v1/targets?state=active' \
  | jq -r '.data.activeTargets[] | select(.health != "up")
    | [.labels.job, .labels.instance, .lastError] | @tsv'

# 当前 firing / pending 告警
curl -fsS http://127.0.0.1:9090/api/v1/alerts \
  | jq -r '.data.alerts[] | [.state, .labels.alertname, .labels.instance] | @tsv'
```

Grafana、Prometheus 和 Alertmanager 的入口分别是：

- `https://dashboard.zhyi.cc`
- `https://prometheus.zhyi.cc`
- `https://alert.zhyi.cc`

三者均应使用 Dex 身份认证；不要在 Homepage 中放入 exporter 或 Prometheus 本地
监听地址。

## 当前已知运行态

2026-07-21 的审计确认 `logvm` 上的 Prometheus、Alertmanager 与 Grafana 均为
`active`，采集器已能读取多数主机和服务指标。`logvm` 与 `jpvm` 的 WSS WireGuard
peer 曾因运行态仍指向旧本地 UDP endpoint 而导致 BIRD hold timer 过期；重启
`systemd-networkd` 后，WireGuard 握手、`ltnet_jpvm`/`ltnet_logvm` BGP 邻居，以及
`jpvm` 的 node、Nginx、BIRD、CoreDNS、WireGuard 五项采集均已恢复为 `up`。

以下不是监控本身故障，而是应由网络或服务任务处理的真实信号：

- `pve-2700` 的 node exporter 当前不可达；在该主机恢复或明确退役前，这一项会
  保持 `down`。
- 多个 `zhyi.cc` 公网入口从 `logvm` 探测时连接失败。它们通过 `jpvm` 的入口
  链路发布，应与公网入口任务一起修复，不应通过放宽 Blackbox 成功条件掩盖。
- `/nix/sync-servers/acme/` 中仍有旧主机证书，证书 exporter 会为这些文件发出
  即将过期告警。清理旧证书同步内容前需先确认它们没有被任何现役服务引用。

## 变更与验证

修改监控模块后，先在构建机执行轻量求值：

```bash
cd /nix/src/nixos-config
nix build .#nixosConfigurations.logvm.config.system.build.toplevel -L
```

确认通过后，仅部署 `logvm`。部署完成等待一个 scrape interval（约一分钟），再用
上面的只读命令复核。对于 LTNet、DNS、443 入口或证书同步异常，先修复对应链路，
不要用删除探针或扩大成功状态码来制造绿色面板。
