# 公开服务域名迁移计划（zhyi.cc → zhyi.xin，2026-08-14）

依据 [域名配置审计](domain-config-audit-2026-08-14.md) 第七节核对表，
将 8 项公开服务从 zhyi.cc 迁到 zhyi.xin（公开服务统一 zhyi.xin；访问控制
保持与作者一致，全部不动）。

## 一、迁移范围与目标

| # | 服务 | 旧域名 | 新域名 | 所在主机 | 连带项 |
| --- | --- | --- | --- | --- | --- |
| 1 | prometheus | prometheus.zhyi.cc | prometheus.zhyi.xin | tencent | 探针 |
| 2 | alert | alert.zhyi.cc | alert.zhyi.xin | tencent | 探针 |
| 3 | dashboard | dashboard.zhyi.cc | dashboard.zhyi.xin | tencent | 探针 + dex 回调 |
| 4 | netbox | netbox.zhyi.cc | netbox.zhyi.xin | greencloud | 探针 |
| 5 | hydra | hydra.zhyi.cc | hydra.zhyi.xin | greencloud→ml-builder | 探针 + hydraURL + watchdog + 反代 override + 白名单 |
| 6 | flapalerted | flapalerted.zhyi.cc | flapalerted.zhyi.xin | greencloud | 探针 + stayrtr RPKI + scrape + 白名单 |
| 7 | dav | dav.<host>.zhyi.cc | dav.zhyi.xin（公开 BasicAuth；2026-08-15 定案，不用 `<host>` 格式） | opi5p | rock5c 边缘反代；无需新证书 |
| 8 | vaults3 | vaults3.zhyi.cc | vaults3.zhyi.xin | opi5p（家庭） | 探针 + attic S3 + gitea S3 + memos 脚本 + hosts + 白名单 |

访问控制（public/private/auth）8 项全部保持现状，与作者一致，仅域名变更。

## 二、文件改动清单

### vhost 定义（8 个文件）
| 文件 | 改动 |
| --- | --- |
| `nixos/optional-apps/prometheus/default.nix` | 域名 + `sslCertificate` → `lets-encrypt-zhyi.xin` |
| `nixos/optional-apps/prometheus/alertmanager.nix` | 同上 |
| `nixos/optional-apps/grafana.nix` | 同上 |
| `nixos/optional-apps/netbox.nix` | 同上 |
| `nixos/common-apps/nginx/vhost-hydra-proxy.nix` | 域名 → `hydra.zhyi.xin`；ssl → `zerossl-zhyi.xin` |
| `nixos/optional-apps/flapalerted.nix` | 域名 + ssl → `lets-encrypt-zhyi.xin` |
| `nixos/optional-apps/webdav.nix` | 域名 → `dav.zhyi.xin`；ssl → `lets-encrypt-zhyi.xin`（现有通配，无需新证书） |
| `hosts/opi5p/edge-vhosts.nix` | vhost 域名 → `vaults3.zhyi.xin` + `networking.hosts` 条目同步 |

### 连带引用（8 个文件）
| 文件 | 改动 |
| --- | --- |
| `nixos/optional-apps/dex.nix` | grafana 客户端 `redirectURIs` → `https://dashboard.zhyi.xin/login/generic_oauth` |
| `nixos/optional-apps/hydra/default.nix` | `hydraURL` → `https://hydra.zhyi.xin` |
| `nixos/optional-apps/hydra/watchdog.py` | `HYDRA_QUEUE_URL`/`HYDRA_STATUS_URL` → zhyi.xin |
| `hosts/greencloud/configuration.nix` | hydra 反代 override 域名 → `hydra.zhyi.xin` |
| `nixos/server-apps/bird/stayrtr.nix` | `--cache https://flapalerted.zhyi.xin/flaps/active/roa` |
| `nixos/optional-apps/prometheus/scrape-configs.nix` | flapalerted 抓取目标 → zhyi.xin |
| `nixos/optional-apps/prometheus/blackbox-exporter.nix` | 8 项探针 + 遗留 qnap 探针 → zhyi.xin |
| `nixos/optional-apps/attic.nix` | S3 `endpoint` → `https://vaults3.zhyi.xin:8443` |
| `nixos/optional-apps/gitea/default.nix` | `MINIO_ENDPOINT` → `vaults3.zhyi.xin:8443` |
| `tools/memos/configure-memos.sh` | `VAULTS3_ENDPOINT` → `https://vaults3.zhyi.xin` |

### 白名单（1 个文件）
`helpers/constants/public-sites.nix`：第 2 类（自带认证）alert/dashboard/hydra/
prometheus/vaults3 换 zhyi.xin；第 3 类（有意公开无认证）flapalerted 换
zhyi.xin。netbox 不在白名单（OAuth 满足断言），dav 不在白名单（BasicAuth）。

### DNS（2 个文件）
- `dns/domains/zhyi.cc.nix`：删 7 条 CNAME（hydra/alert/dashboard/flapalerted/
  netbox/prometheus/vaults3）
- `dns/domains/zhyi.xin.nix`：加 8 条 CNAME——
  - prometheus/alert/dashboard → `tencent.zhyi.cc.`
  - netbox/flapalerted/hydra → `greencloud.zhyi.cc.`
  - vaults3 → `home-ddns.zhyi.cc.`（与 qnap 同模式）
  - `dav` → `home-ddns.zhyi.cc.`（公开入口，复刻作者 dav.<domain> 暴露；经家庭边缘
    反代到 OPI5P，2026-08-15 定案）

### 当前状态文档（8 个文件，机械替换域名）
`docs/infrastructure/monitoring.md`、`domain-service-layout.md`、
`fleet-service-chain.md`、`network/reference.md`、`../../human/network/regional-dns.md`、
`hosts-mapping-cleanup.md`、`services/memos.md`、`gcore-dnscontrol-free-plan.md`。
历史归档（docs/migrations/archive、docs/old、docs/research）不改。

## 三、DNS 部署顺序（避免全断窗口）

1. **第一次 DNS push**：只加 zhyi.xin 的 8 条新记录（zhyi.cc 旧记录暂留）
2. **apply 相关主机**：tencent（prometheus/alert/dashboard）、greencloud
   （netbox/hydra/flapalerted + hydra 反代）、opi5p（dav/vaults3 + 家庭入口）
   ——新 vhost 生效，新域名可用；旧域名此刻 vhost 已删（404，服务在新域名）
3. **验证**：新域名逐个 curl / dig；探针目标更新后 Prometheus 面板正常
4. **第二次 DNS push**：删 zhyi.cc 的 7 条旧记录
5. **收尾验证** + 三端对齐

## 四、证书

| 项 | 证书 | 状态 |
| --- | --- | --- |
| prometheus/alert/dashboard/netbox/flapalerted/vaults3 | `lets-encrypt-zhyi.xin`（`*.zhyi.xin` 通配） | 已有 ✓ |
| hydra | `zerossl-zhyi.xin`（`*.zhyi.xin` zerossl 通配） | 已有 ✓ |
| dav | `lets-encrypt-zhyi.xin`（`*.zhyi.xin` 通配） | 已有 ✓（`dav.zhyi.xin` 单级，通配直接覆盖，无需新签） |

## 五、风险与回滚

- 服务中断窗口：DNS 第一次 push 后 ~apply 完成前，新旧域名交替期
  （分钟级，监控面板类服务可接受）。
- 每步独立 git 提交，可逐项回滚；vaults3 迁移影响 attic/gitea/memos 的
  S3 访问，改后立即验证 attic push/pull。
- flapalerted 迁移同步改 stayrtr `--cache`，改后验证 RPKI 缓存刷新
  （stayrtr 日志无报错）。
- dav 走 `dav.zhyi.xin`（复用 `*.zhyi.xin` 通配证书），无新证书依赖；若边缘反代
  异常，回退为 opi5p 直连（`dav` CNAME 改回 LTNET）。

## 六、验收清单

- [ ] dig 8 个新域名 → 解析到正确主机
- [ ] curl 各新域名 → 200 / 401（认证挑战）
- [ ] blackbox 探针 8 项 + qnap 全部 green
- [ ] attic push/pull 正常（vaults3 新端点）
- [ ] gitea 对象存储正常（MINIO 新端点）
- [ ] stayrtr RPKI 缓存正常（flapalerted 新数据源）
- [ ] hydra 面板 + watchdog 正常
- [ ] 三端对齐（mac/origin/ml-builder）
