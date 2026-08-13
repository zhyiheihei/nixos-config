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

Elasticsearch 日志链路与监控栈彼此独立。Filebeat 当前仍被声明为把日志发送到
`es-ingest.google.zhyi.cc`，但 2026-08-03 审计确认 `hosts/google/configuration.nix`
没有导入 Elasticsearch 模块，实机也没有 Elasticsearch unit 或容器。因此这条日志
链目前不完整，不能把 Filebeat 的 `active` 当作日志已经成功落库。后续必须对照作者
结构决定恢复 google Elasticsearch，或明确关闭/改写舰队 Filebeat 输出；不要在没有
容量和持久化审计时把 Elasticsearch 临时塞入家庭 VM。

## 声明规则

- 非 `client` 主机自动启用 node exporter，不要为每台 server 重复声明。
- `scrape-configs.nix` 通过 NixOS option 自动发现已启用的 exporter。新服务应在
  自己的模块中声明 exporter，不要把 IP 手写进 Prometheus。
- Blackbox 只保留实际入口。受 Dex 或应用认证保护的入口可以返回正常重定向。
- Blackbox 自动生成 `<hostname>.zhyi.cc` 目标只对拥有该入口的主机有效；cnvm
  属于 `zhyi.xin` 体系（无 `cnvm.zhyi.cc` 实际服务），其入口在
  `httpMonitorTargets` 中显式声明。
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
- `https://prometheus.colocrossing.zhyi.cc`（仅私网可达，供 Homepage 资源卡片做只读查询，不叠加 OAuth；rock5c 通过 `hosts/rock5c/home-lan-edge.nix` 固定解析到 colocrossing LTNET 地址）
- `https://alert.zhyi.cc`

三者均使用 Dex 身份认证。Homepage 只链接这些入口，不链接 exporter 或本地监听
地址。

## 变更与验证

所有求值、构建和部署在 `ml-builder` 执行（见
[构建与部署](../operations/deployment.md)）。监控栈变更按 Colmena 流程构建并
只部署 `colocrossing`：

```bash
ssh -A -p 2222 root@ml-builder.zhyi.cc
cd /nix/src/nixos-config
nix run .#colmena -- build --on colocrossing
nix run .#colmena -- apply --on colocrossing
```

只部署 `colocrossing`，等待一个 scrape interval 后再复核。LTNet、DNS、HTTPS
入口或证书同步异常应在对应链路修复，不能放宽探针条件来掩盖。
