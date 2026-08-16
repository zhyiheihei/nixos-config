# 公共模块对齐审计（2026-08-13）

对 `nixos-config`（fork）与 `nixos-config-exam`（作者原版 xddxdd/nixos-config）
的**全部公共模块**（`nixos/`、`home/`、`helpers/`、`dns/`、`flake-modules/`、
`overlays/`、`patches/`、`pkgs/`、顶层文件）做了一轮完整 `diff` 审计。

结论分两类：
1. **有意偏离**（fork 自有身份/基建，确认保留，记录在案，后续不再当作对齐缺口）
2. **真实对齐缺口**（fork 重构/新增主机时意外丢失，本次已修复）

## 一、完全一致（无需处理）

`nixos/{minimal,server,pve}.nix`、`client-apps` 大部分、`minimal-policies`、
6 个 overlay、26 个补丁、`nvfetcher.toml`、多数 `flake-modules`/`helpers`/`home`
文件、`dns/core` 等。

## 二、有意偏离（确认保留）

### 身份 / 网络
- 用户：`lantian` → `zhyi`；域名：`xuyh0120.win` / `lantian.pub` → `zhyi.xin` / `zhyi.cc`
- 自有 LTNet ULA：`fdd8:1938:4e88:3712::/48`（上游 `fdbc:f9dc:67ad:2547::/48`），
  对应 IPv4 `198.18.0.x`、ZeroTier 网络 ID `466270de75000001`（上游 `91450bd87b000001`）
- DN42 ASN `4242423712`（上游 `4242422547`），连带 bird/反向区/DS 记录/asterisk 拨号前缀
- GPG 签名密钥、SSH 主机密钥、SMTP 账号、邮件地址

### 国内网络适配
- AliDNS 回退（networking、powerdns-recursor）、`dnssec validation=process-no-validate`
- substituter：自建 attic 优先 + 上交/中科大/清华镜像；部署 `apply --no-substitute`
- GOPROXY goproxy.cn、USTC conda 镜像、`timeZone=Asia/Shanghai`
- 服务级 `VERSION_CHECK_DISABLED`（国内无法访问 api.github.com）等

### 供应商 / 后端切换
- 备份：Hetzner StorageBox → 自建 sftp（`/backups/rustic-storagebox`）
- 日志：Humio → Axiom（filebeat7）
- S3：Telnyx → 自建 VaultS3（`vaults3.zhyi.xin:8443`）
- DNS 体系：`registrars=[]`、providers `bind+gcore` + `NO_PURGE` handler（上游
  doh/porkbun + bind/bunny/cloudflare/desec/gcore）
- sops 密钥普遍改为 template / 单独 secret + `after/requires sops-install-secrets`

### fork 自有扩展
- Rockchip 硬件全家（`nixos/hardware/` 18 文件、`pkgs/` 9 个内核/库、overlay 49/53-56）
- `optional-apps/` 21 个自有应用（filecodebox/freshrss/halo/home-assistant/
  linkwarden/memos/metacubexd/mmrelay/moviepilot/sublinkpro/sun-panel/vertex/
  grafana-dashboards/qbittorrent-seedbox/immich-rockchip/jellyfin-rockchip 等）
- `server-apps/wg-mesh-wstunnel.nix`、pve overlay、`home/client-apps/ai-coding`
- `minimal-components/firewall.nix`（上游为 `firewall/` 目录，fork 拍平为一文件）
- nginx tmpfiles 运行时账户权限规则（fork 增强，上游无）

### 未承接上游的（预期）
- OpenNIC / NeoNetwork 域名运营（coredns 权威区、bird、zones.nix 对应删减）
- `radicle.nix`、`tranquil-pds.nix`、`nixos-hardware` 输入、`tools/sync-uptimerobot-monitors.py`
- 作者专属域名 zone 文件（`lantian.pub`/`ltn.pw`/`xuyh0120.win` 等）

## 三、本次修复的对齐缺口

| 位置 | 缺口 | 修复 |
| --- | --- | --- |
| `nixos/minimal-components/firewall.nix` | 拍平时丢失上游 `arp.nix` 的 `wanARPSubnets` 选项 + ARP 反欺骗表（fork 全仓 0 使用；上游 colocrossing 等公网机在用） | 恢复选项 + `lantian_arp` 表（并入扁平文件，默认 null 不改变现有主机） |
| `nixos/common-apps/nginx/vhost-hydra-proxy.nix` | 丢失 `blockBadUserAgents` / `blockBadTLSSignatures` | 从上游恢复 |
| `patches/lemmy-disable-specific-error.patch` + `overlays/50-general.nix` | 补丁与覆盖缺失，但 `hosts/greencloud` 仍在跑 lemmy | 恢复补丁 + overlay 条目 |
| `patches/iperf3-socket-activation.patch` + `overlays/50-general.nix` | 补丁与覆盖缺失（当前无主机引用 iperf.nix，潜伏断链） | 恢复补丁 + overlay 条目 |
| `patches/nixpkgs/fix-xstatic.patch` | 缺失（nixpkgs-options 自动加载目录，当前无 xstatic 引用） | 恢复补丁 |
| `home/client-apps/ai-coding/rules/05-writing-style.md` | 规则文件缺失 | 恢复 |

## 四、遗留 / 后续

- **`wanARPSubnets` 主机级取值**：恢复的是选项能力；公网主机（如 colocrossing，
  上游为 `23.94.65.216/30`，fork 的 WAN 是 `203.55.176.158` 不同段）需要按其
  **提供商真实网段**设置，值待确认后补主机级配置。
- 误报澄清：`powerdns-recursor` 的 NTA 列表（`zhyi.cc`+`zhyi.xin`）非笔误；
  `host-options.nix` 的 `nixBuilder`/`ltnet.tcpTransport` 选项 fork 均存在。
