# 2026-08-06 服务端链路上游对齐评估

## 目标

服务端对齐作者链路：作者弃用的我们也弃用，作者新增的我们也新增。
本文是只读评估，不包含实施改动；实施前需要逐项确认影响面和前置条件。

## 评估基准

| 项目 | 值 |
| --- | --- |
| 上次对齐审计 | `docs/migrations/upstream-replica-audit-2026-08-03.md` |
| 上次审计作者基线 | `6a9e45a3`（2026-07-30） |
| 本次作者基线 | `6a9e45a3..HEAD` 的提交列表 |
| 评估方式 | 作者 git 历史 + 双方主机 import + 公共模块 diff |

上次审计已经吸收：

- `nix-cache-proxy` 删除（`6a9e45a3`）
- 公开 Nginx vhost 的 `public-facing` 边界（`0f750d89`）
- `low-disk` 标签删除（`07c18751`）
- Hydra 输出与 `nix-cache-attic` 导入（`4df34856` 等）

## 一、作者弃用，需要同步清理

### 1. AxonHub（`4e8e01a6`）

作者从 `lt-home-vm` 移除 `axonhub.nix` import，并删除 Firefox 的
`all-api-hub` 扩展。

本仓库现状：

- 没有主机 import `axonhub.nix`，主链路已对齐；
- `hosts/rock5c/home-lan-edge.nix` 仍残留
  `axonhub.colocrossing.zhyi.cc` 的 hosts 映射，属于死配置。

建议：删除该映射，一行改动，无运行影响。

### 2. dae（`a7962510`）

作者先在 `5c8e8a95` 把 dae 移到 `lt-home-router`，随后在 `a7962510`
停用。当前作者任何主机都不再 import dae。

本仓库现状：没有主机 import dae，已对齐。`nixos/optional-apps/dae.nix`
保留本地参数化版本，公共模块不动原则下无需删除。

### 3. openvpn-gameaccel（`e4ad78fb`）

作者从 cn-accel 主机（bwg-lax/v-ps-sea/zgocloud）移除该模块，改用
mihomo。

本仓库现状：从未启用，已对齐。

### 4. 独立 lancache 主机（`e1887f8e`）

作者删除 `lt-home-lancache` 主机并把组件并入 `lt-home-router`
（`7ccf4c6a`）。

本仓库现状：没有独立 lancache 主机，已对齐。是否在路由上补 lancache
见新增清单。

### 5. 独立构建机（`8f189e2d`）

作者把 `lt-home-builder` 合并进 `pve-epyc`。

本仓库现状：保留 `ml-builder` 专用构建机，这是
`docs/migrations/upstream-replica-audit-2026-08-03.md` 明确保留的本地
构建拓扑。不建议机械对齐；如需变更必须重排构建图，属于独立决策。

### 6. Open WebUI（`7706ab61`）

作者用 LibreChat 完全替换 Open WebUI。

本仓库现状：07-28 合并时已替换，已对齐。

## 二、作者新增，本仓库尚未跟上

### 1. mihomo CN-unblock 链路（`e4ad78fb`）

作者在 cn-accel 主机启用 `services.mihomo`，端口 `Mihomo = 13792`，
提供 CN 订阅分流 SOCKS。

本仓库现状：

- `nixos/server-apps/mihomo.nix` 存在，但本地加了 `lantian.mihomo.enable`
  option（默认 true）；
- `colocrossing`、`hostdare`、`google` 三台 cn-accel 主机显式
  `lantian.mihomo.enable = false`，注释说明使用 v2ray 出口并省内存；
- `nixos/server-apps/v2ray.nix` 与作者一致，按 cn-accel 标签启用，
  因此我们目前只跑 v2ray，作者是 v2ray + mihomo。

建议：删除三处 `lantian.mihomo.enable = false`，恢复作者默认链路。
注意 hostdare（1 vCPU）和 google（2GB）内存较小，建议先 colocrossing，
另外两台 dry-run + 内存观察后决定。

### 2. actual 记账（`4223a903`、`0ffe18a3`）

作者在 colocrossing 启用 `actual.nix` 并补 OAuth。

本仓库现状：`nixos/optional-apps/actual.nix` 存在，但没有主机 import。

建议：在 colocrossing 加入 import 并配置数据目录/证书。

### 3. ncmm cron（`07653345`）

作者在 `lt-home-vm` 启用 `ncmm.nix`。

本仓库现状：模块存在，没有主机 import；对齐位置是 opi5p 的
home-services（lt-home-vm 拆分后的承载主机）。

前置条件：确认 secrets 中是否有 ncmm 需要的账号配置。

### 4. skyland-auto-checkin cron（`8134c190`）

作者在 v-ps-sea 启用该 cron，并新增 nvfetcher 源。

本仓库现状：`nixos/optional-cron-jobs/` 缺少
`skyland-auto-checkin.nix`，也没有主机 import。

建议：新增模块 + nvfetcher 源 + 主机 import；依赖 secrets 中的账号凭据。

### 5. auto-mihoyo-bbs cron

作者在 v-ps-sea 启用（与本轮新增的 skyland 同主机）。

本仓库现状：模块存在，无主机 import。

建议：与 skyland 一起补到对应 cn-accel/公开服务器角色。

### 6. it-tools（`d0f8b932`）

作者在 `vhost-tools` 增加 `it-tools` 静态资源（`BASE_URL=/it-tools/`）。

本仓库现状：`nixos/common-apps/nginx/vhost-tools/default.nix` 缺该块。

建议：补齐静态资产配置，纯静态、风险低。

### 7. speedtest-go（`a048d0dd`）

作者在 `nixos/minimal-components/environment.nix` 增加 `speedtest-go`。

本仓库现状：缺失。

建议：补一行系统包。

### 8. conntrack 告警（`e823e69c`）

作者在 alertmanager 增加 `node_nf_conntrack_using_90percent`。

本仓库现状：`prometheus/alertmanager.nix` 是本地改写版本，缺该规则；
router 已有 conntrack 指标和 Grafana 面板。

建议：补规则，保持现有本地 alert 风格。

### 9. nftables 连接数与 ICMP（`bf7c7fbd`、`975bd953`）

作者在 minimal networking 设置：

- `net.nf_conntrack_max = 131072`
- `net.ipv4.icmp_msgs_per_sec = 10`

本仓库现状：两条 sysctl 均缺失。

建议：补回 minimal networking。

### 10. webfinger 302（`9eea1da4`）

作者把 `/.well-known/webfinger` 改为 302 到 Mastodon。

本仓库现状：`nixos/common-apps/nginx/vhosts.nix` 用 proxy_pass 转发，
账号写死为 `molishanguang@mastodon.social`。

建议：跟随作者改 302，账号替换为本地 Mastodon 账号。

### 11. 包版本 bump

`4cfd2f19`、`9b9091f8`、`019999ea`、`bce29f6c` 等属于上游版本更新，
本仓库使用自己的 nvfetcher/lock 管理，不强制逐提交跟随。

## 三、作者长期在跑、本仓库从未部署的服务端服务

以下不是本轮新增，但对齐完整链路时会涉及，需要逐项确认：

- `waline`、`yourls`、`nginx-lab`：作者放在公开服务器；
- `asterisk`：作者放在 v-ps-sea，依赖电话/SIP 业务；
- `open5gs + mysql`：作者放在 lt-home-lte，依赖移动核心业务；
- `adsb`、`lora`：作者放在 lt-rpi4，依赖射频硬件；
- `handbrake-server`：作者放在 lt-home-rdp/lt-home-vm，我们只有
  `handbrake-rockchip`；
- `lancache`：作者放在路由器，依赖缓存磁盘。

这些服务不建议盲目补齐，应先确认业务需求、存储、硬件和 secrets。

## 四、本仓库有、作者没有的服务端服务

以下属于本地迁移和 ARM 适配产出，不是作者弃用项，对齐时不删除：

- `halo`（cnvm）
- `home-assistant`、`memos`、`sun-panel`、`filecodebox`（opi5p）
- `metacubexd`、`worker-vless2sub`、`homepage-dashboard`（rock5c）
- `immich-rockchip`、`immich-rknn-worker`、`jellyfin-rockchip`、
  `handbrake-rockchip`、`qbittorrent-seedbox`、`vertex`
- router 上的 v2ray、prometheus、qbittorrent 本地模块
- lt-home-vm 拆分产生的 home-edge/app-edge/media-apps/ml-home-x86 等

## 五、建议执行顺序

1. 低风险纯对齐：删 axonhub 残留映射、补 it-tools、speedtest-go、
   nf_conntrack/ICMP sysctl、conntrack 告警、webfinger 302。
2. mihomo：先在 colocrossing 开启，hostdare/google 评估内存后再决定。
3. actual、ncmm、auto-mihoyo、skyland：先确认 secrets 凭据，再补模块
   和主机 import。
4. lancache、asterisk、open5gs 等大服务：单独出方案确认。
5. 每批改动后按工作规范提交并对齐三方仓库。

## 六、验证方式

- 每批改动后对承载主机执行 `nix flake check` 或
  `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`；
- mihomo 验证 `cn.sub` 加载、SOCKS 端口监听和 CN 站点可达性；
- cron 验证日志中任务实际执行；
- webfinger/it-tools/speedtest 验证公开 vhost 返回；
- 公共模块改动参考作者原版 diff，避免覆盖本地参数化实现。
