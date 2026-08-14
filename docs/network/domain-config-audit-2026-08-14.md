# 域名配置审计（2026-08-14）

按 [内网服务域名规范](./service-domain-norms.md) 与「公开服务统一用 zhyi.xin」
规则审计全部 `lantian.nginxVhosts` 定义与 DNS 记录。

- 审计范围：`nixos/` + `hosts/` 全部 vhost 定义（118 条，含模块级未启用项）
- 判定标准：
  - 公开服务（公网可访问）→ 统一 `*.zhyi.xin`
  - 内网服务（private）→ `<svc>.<host>.zhyi.cc` + `accessibleBy = "private"`

## 一、符合规范（无需改动）

### 1. zhyi.xin 公开服务（约 25 个）✓
`api` `avatar` `ca` `cal` `element` `git` `id` `index` `lab.zhyi.xin` `lemmy`
`login` `matrix-client` `matrix-federation` `posts` `rss` `stats` `sub` `tools`
`ai` `attic` `comments` `whois` `www` `ltn.pw` `filebox` `sun-panel` 等。

### 2. zhyi.cc 内网服务（private）✓
`hub.tencent` `metapi.tencent` `uni-api.<host>` `searx.<host>` `adsb.<host>`
`axonhub.<host>` `archivebox.<host>` `bifrost.<host>` `memos.<host>`
`moviepilot.<host>` `radarr.<host>` `sonarr.<host>` `prowlarr.<host>`
`bazarr.<host>` `qbit*.<host>` `syncthing.<host>` `clawemail.<host>`
`metacubexd.<host>` `peerbanhelper.<host>` `fastapi-dls.<host>`
`openai-edge-tts.<host>` `handbrake.<host>` `mtranserver.<host>`
`n8n-bridge.<host>` `vertex.<host>` `sakura-llm.<host>` `qwen3-reranker.<host>`
`openspeedtest.<host>` `cliproxyapi.<host>` `elasticsearch.<host>` 等。

## 二、违反「公开统一 zhyi.xin」（zhyi.cc 下的公开服务）

### P0 — 安全风险（无认证公网暴露，需尽快处理）
| 域名 | 位置 | 现状 | 说明 |
| --- | --- | --- | --- |
| `qnap.zhyi.cc` | rock5c home-lan-edge | public 无认证 | 反代家庭 NAS（192.168.0.40）；DNS 走 home-ddns 公网 DDNS，**NAS 公网可直连** |
| `couchdb.zhyi.cc` | rock5c home-lan-edge | public 无认证 | 同上，NAS 上 CouchDB 公网暴露 |

建议：确认用途——仅自用则设 `accessibleBy = "private"`（家庭侧 hosts 解析）；需远程访问则迁 zhyi.xin。

### P1 — 规则合规迁移（有认证或基础设施服务）
| 域名 | 位置 | 认证 | 说明 |
| --- | --- | --- | --- |
| `prometheus.zhyi.cc` | prometheus/default.nix | OAuth | 监控面板，DNS 已迁 tencent |
| `alert.zhyi.cc` | prometheus/alertmanager.nix | OAuth | 告警面板，DNS 已迁 tencent |
| `dashboard.zhyi.cc` | grafana.nix | 无(需复核) | Grafana |
| `netbox.zhyi.cc` | netbox.nix | OAuth | 资产/网络管理 |
| `flapalerted.zhyi.cc` | flapalerted.nix | 无(需复核) | BGP 告警，greencloud |
| `hydra.zhyi.cc` | greencloud | 需复核 | Hydra 构建服务（反代 ml-builder），公共模块 vhost-hydra-proxy |
| `vaults3.zhyi.cc` | opi5p edge-vhosts | 无 | **有意公网**（Attic 8443 兼容端点，router DNAT）；迁移影响 attic 客户端配置 |
| `es.<host>.zhyi.cc` | elasticsearch.nix | BASIC | Elasticsearch |
| `dav.<host>.zhyi.cc` | webdav.nix | BASIC | WebDAV |

### 待决策 — 主机入口 vhost
`google.zhyi.cc` `greencloud.zhyi.cc` `hostdare.zhyi.cc` `tencent.zhyi.cc`
`zhyi.cc`（裸域）——承载 v2ray /ray 出口、DDNS 默认页等**基础设施入口**，
非服务本体。迁移影响 v2ray 客户端、监控探针、DDNS 配置，建议保持现状并
在规范中单独说明。

## 三、遗留与异常

| 项 | 位置 | 说明 |
| --- | --- | --- |
| `actual.xuyh0120.win` | actual.nix | **作者域名** xuyh0120.win 遗留；无任何主机 import（未启用）→ 建议删除模块或改 zhyi 域名 |
| `sip.lantian.pub` | asterisk/dialplan | **作者域名** lantian.pub 遗留；未启用 → 同上 |
| `rsshub.zhyi.xin` | rsshub.nix | private 访问但用 zhyi.xin 域（反向混合）——RSS 源若仅内网用应迁 `<svc>.<host>.zhyi.cc`；若公网订阅应去掉 private |
| `n8n.zhyi.xin` `bitwarden.zhyi.xin` `asf.zhyi.xin` | n8n/vaultwarden/asf | zhyi.xin 域但 localhost 访问（未实际暴露）——域名虚挂，建议对齐实际访问方式 |
| `zhyi.xin`（裸域） | halo.nix | private+OAuth 却挂在 zhyi.xin 裸域（作者遗留 halo 配置）——未启用则忽略 |

## 四、DNS 侧观察

- zhyi.xin 已有 `internalServices` CNAME 记录体系，公开服务迁移到 zhyi.xin
  需在此补充记录（与 zhyi.cc 通配模式不同，zhyi.xin 无 `*.<host>` 通配）。
- `qnap`/`couchdb` 的 DNS CNAME → home-ddns（公网 DDNS），与 public vhost
  叠加构成 NAS 公网暴露面，优先处理。
- 2026-08-14 监控栈迁移中 `alert`/`dashboard`/`prometheus` DNS 已切 tencent，
  与 vhost 目标一致，但域名仍属 zhyi.cc（P1 迁移对象）。

## 五、迁移影响面（P1 共 9 项）

每项迁移 = vhost 域名改 zhyi.xin + DNS 记录（zhyi.xin internalServices）+
证书（zhyi.xin 通配已存在）+ 客户端引用更新（监控探针、Homepage、attic 等）。
建议分批：先 P0（qnap/couchdb 设 private），再 P1 按服务迁移，每次验证
blackbox/监控指标后再继续。
