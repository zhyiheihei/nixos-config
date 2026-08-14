# Prometheus / Grafana 监控链路

本文描述当前仓库的监控链路和操作边界。配置来源是
`nixos/minimal-components/prometheus-exporters.nix`、
`nixos/optional-apps/prometheus/`、`nixos/optional-apps/grafana.nix` 与
`hosts/tencent/`（监控栈自 2026-08-14 起从 greencloud 迁至 tencent）。

## 拓扑

```text
各非 client NixOS 主机
  └─ node exporter（LTNet IPv4:9100）

服务专用 exporter（BIRD、CoreDNS、PostgreSQL、MySQL、WireGuard、SMART、ARR 等）
  └─ LTNet IPv4 上的对应端口

tencent
  ├─ Prometheus：拉取所有 exporter，并保存 365 天或最多 10 GiB 数据
  ├─ Blackbox exporter：每分钟探测已声明的 HTTPS、DNS、Gopher、WHOIS 入口
  ├─ Alertmanager：向 Telegram 发送告警和恢复通知
  └─ Grafana：通过 Dex 登录，公开入口为 dashboard.zhyi.cc
```

Prometheus、Alertmanager 和 Grafana 只监听本机，由 `tencent` 的 Nginx
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

从构建机经 SSH 登录 `tencent` 后执行：

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
- `https://prometheus.tencent.zhyi.cc`（仅私网可达，供 Homepage 资源卡片做只读查询，不叠加 OAuth；rock5c 通过 `hosts/rock5c/home-lan-edge.nix` 固定解析到 tencent LTNET 地址）
- `https://alert.zhyi.cc`

三者均使用 Dex 身份认证。Homepage 只链接这些入口，不链接 exporter 或本地监听
地址。

## 变更与验证

所有求值、构建和部署在 `ml-builder` 执行（见
[构建与部署](../operations/deployment.md)）。监控栈变更按 Colmena 流程构建并
只部署 `tencent`：

```bash
ssh -A -p 2222 root@ml-builder.zhyi.cc
cd /nix/src/nixos-config
nix run .#colmena -- build --on tencent
nix run .#colmena -- apply --on tencent
```

只部署 `tencent`，等待一个 scrape interval 后再复核。LTNet、DNS、HTTPS
入口或证书同步异常应在对应链路修复，不能放宽探针条件来掩盖。

## 近期变更（2026-08-14）

- 监控栈（Prometheus/Alertmanager/Blackbox/Grafana + MariaDB）从 `greencloud`
  迁至 `tencent`（全新开始，未迁移历史数据）。`alert`/`dashboard`/`prometheus`
  CNAME 与 Homepage 只读入口（`prometheus.tencent.zhyi.cc`）随之切换；
  `flapalerted` 留在 greencloud（属 DN42 链路，非监控栈）。迁移动机：greencloud
  内存压力（7.7 GiB / 20+ 服务），SSH 曾因内存耗尽无法握手。
- tencent 为 4 GiB 无 swap 的 VPS：监控栈常驻内存偏高（grafana+MariaDB 较吃
  内存），若水位紧张应缩短 retention 或把 grafana 数据库换 sqlite，而不是堆到
  greencloud 上。

## 近期变更（2026-08-13）

- 主机改名：`colocrossing`→`greencloud`、`jpvm`→`hostdare`、`usvm`→`google`。
  仪表盘查询全部基于动态 label（`{{instance}}`、`job=`），改名后实例与目标
  自动跟随，无需改仪表盘代码。
- 新主机 `tencent`（首尔，public-facing）上线：node/bird/coredns/nginx/knot/
  wireguard exporter 与 `https://tencent.zhyi.cc` 等黑盒目标自动纳入。
- 公共 UniAPI 入口 `ai-api.zhyi.cc` 从不可达的 `hostdare` 迁至 `tencent`。
  该入口受 API key 保护（未认证返回 401/403），新增 `https_ok_403` 探测
  （`blackbox-exporter.nix`），403 视为存活；`服务与网络健康` 的
  「公网服务可用」面板计入该 job。
- `SearXNG` 从 `opi5p` 迁至 `tencent`（`searx.tencent.zhyi.cc`，私有 vhost，
  不探测）。
- 家庭路由器 v2ray 代理出口从 `greencloud` 切至 `tencent`
  （`hosts/router/v2ray.nix`）。路由器仪表盘监控 WAN/接口，不感知出口切换；
  代理可用性以家庭侧实测为准。
