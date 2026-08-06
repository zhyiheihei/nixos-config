# 2026-08-06 公共模块上游对齐

## 背景与目标

按用户要求完成公共模块对齐：

- 把作者有、我们没有的公共模块补上；
- 对比共同模块的配置信息，除域名这类硬编码外，可对齐的都对齐。

本次是实施任务，配套的只读评估见
`docs/migrations/upstream-server-chain-alignment-2026-08-06.md`。

## 基准

| 项目 | 值 |
| --- | --- |
| 作者仓库 HEAD | `4cfd2f19` |
| 本仓库实施提交 | `cb0312f6` |
| 涉及范围 | `nixos/`、`flake-modules/`、`overlays/`、`patches/`、`pkgs/`、`home/` |

## 盘点结果

作者有、我们没有的文件：

| 目录 | 缺失数 | 说明 |
| --- | ---: | --- |
| `nixos/` | 2 | `optional-apps/handbrake-server.nix`、`optional-cron-jobs/skyland-auto-checkin.nix` |
| `flake-modules/` | 0 | 文件清单一致 |
| `overlays/` | 0 | 仅本仓库多出 4 个本地 overlay |
| `patches/` | 2 | `iperf3-socket-activation.patch` 已被模块级 socket activation 实现替代，不补；`fix-xstatic.patch` 双方均无引用，不补 |
| `pkgs/` | 0 | 仅本仓库多出本地 ARM 包 |
| `home/` | 0 | 文件清单一致 |

`nixos/` 共同文件 472 个，其中 173 个存在差异；本次逐文件分类后实施可对齐项。

## 本次已对齐（提交 `cb0312f6`）

### 补齐缺失模块

- `nixos/optional-apps/handbrake-server.nix`：按作者版本补齐，
  仅替换本地域名与证书名；
- `nixos/optional-cron-jobs/skyland-auto-checkin.nix`：与作者版本一致，
  并补充：
  - `nvfetcher.toml` 的 `[skyland-auto-checkin]` 源；
  - `helpers/_sources/generated.nix` 与 `generated.json` 的对应条目。

### 配置差异对齐

- `nixos/common-apps/nginx/default.nix`：恢复作者仍保留的 `./hosts.nix`
  导入；
- `nixos/common-apps/nginx/vhost-tools/default.nix`：补 `it-tools`
  静态资源；
- `nixos/minimal-components/environment.nix`：补 `speedtest-go`；
- `nixos/minimal-components/networking.nix`：补
  `net.nf_conntrack_max = 131072` 与 `net.ipv4.icmp_msgs_per_sec = 10`；
- `nixos/optional-apps/prometheus/alertmanager.nix`：补
  `node_nf_conntrack_using_90percent` 告警；
- `nixos/common-apps/nginx/vhosts.nix`：webfinger 改为作者同款的 302，
  账号保留本地 Mastodon 账号；
- `nixos/common-apps/yggdrasil/public-peers.json`：同步为作者版本。

## 分类保留的本地差异

以下差异属于域名/用户、网络身份或本地拓扑，不在本次对齐范围内，沿用
07-28 与 08-03 两次审计的 fork 原则：

- 域名、证书、用户：`zhyi.xin/zhyi.cc`、`molishanguang`、`zhyi`；
- DN42 身份：AS `4242423712`、ULA `fdd8:1938:4e88::/48`、
  ZeroTier/LTNET 网络 ID；
- 时区：`Asia/Shanghai`；
- 本地基础设施：私有 Attic、OPI5P NCPS、VaultS3、QNAP NFS、备份 SFTP
  端点、Axiom 日志（作者用 Humio）；
- ARM/PVE 适配：Rockchip 硬件、PVE LXC 容器单元、cups 的 aarch64
  条件驱动、PVE LVM `dm-thin-pool`；
- 构建拓扑：`ml-builder`/`pve-5700u`/`opi5p` 定向构建图、国内
  substituter 顺序、`colmena --no-substitute`；
- 本地强化与运维：`mihomo.enable` 参数化、dae 本地 fork、Stylix
  autoEnable 修复、prometheus-exporters 未入网绑定、
  nginx 上传缓存目录、flexget/bitmagnet 等业务守卫。

## 验证

- 所有改动 Nix 文件 `nix-instantiate --parse` 通过；
- `generated.json` 与 `public-peers.json` JSON 校验通过；
- `public-peers.json`、`skyland-auto-checkin.nix` 与作者版本逐字节一致；
- ml-builder 已拉取 `cb0312f6`，`colocrossing` 整机配置求值成功，
  仅有既有弃用警告（pointerCursor、netbox、routeConfig）；
- `LT.sources.skyland-auto-checkin` 在 ml-builder 上解析成功；
- `nix flake check --no-build` 仍失败于既有的
  `allow-import-from-derivation` 全局问题（08-03 审计已记录），
  不是本次改动引入。

## 后续事项

- 主机级链路对齐（mihomo 启用、actual/ncmm/skyland/auto-mihoyo 导入等）
  属于服务编排改动，见服务端链路评估文档，等用户确认后单独实施；
- 全局 `nix flake check` 的 import-from-derivation 验收缺口仍待解决；
- 新补的 `handbrake-server` 与 `skyland-auto-checkin` 尚未被任何主机
  import，部署前需按承载主机补配置和 secrets。
