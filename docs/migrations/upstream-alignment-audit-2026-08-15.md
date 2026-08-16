# 2026-08-15 上游对齐审计（分批 backport）

## 审计结论

本轮按「分块、分批」方式对 `master` 与作者上游做了一轮对齐审计，全部改动
分批提交，无一次性大合并：

- **刷新了上游基线**：`git fetch upstream` 后 `upstream/master` 为
  `11da4247`（2026-08-14，作者最新），此前本地远端停留在 `0a9340d0`
  （2026-07-27），落后 99 个提交。注意：两仓库的 nixpkgs input 实际**不同**
  （本仓库 `b7c2ada94fe9`，作者 `624af665418d`，本仓库新约 10 天），对照时以
  文件级语义为准。
- **真实缺口很少**：99 个新提交里大部分是作者私有内容（radicle、ATproto
  PDS、包版本 bump、作者主机配置）。逐项核验后，真正需要跟随的缺口只有
  弃用修复和少量清理（见下文批次 1）。
- **fix-xstatic.patch 未采纳**：作者因旧 nixpkgs rev（`624af665418d`）缺少
  setuptools 兼容修复而加的补丁，在本仓库的 nixpkgs（`b7c2ada94fe9`）里
  **已包含**该修复，补丁重复会导致 pkgs-patched 构建失败（Reversed patch）。
  已 revert（`f1d8d81b`）；将来若 nixpkgs 回退到旧 rev 再按需引入。
- **此前差异地图的误报已澄清**：早期对过期远端的 diff 曾把 nix-cache-proxy、
  `low-disk` 门控、`icmp_msgs_per_sec`/`nf_conntrack_max`、speedtest-go、
  NixCacheProxy 端口等列为「上游有我们没有」，用新鲜基线（exam
  `11da4247`）逐项复核后全部不成立——两边一致。
- **C 类（我们主动改的公共模块）全部保留**，其中 2 项做了最小参数化（批次 2），
  其余登记在案（见 §3），不回退。

## 审计基准

| 项目 | 值 |
| --- | --- |
| 本仓库提交 | `f1d8d81b`（fix-xstatic revert 后） |
| 上游远端 | `upstream/master = 11da4247`（fetch 后） |
| 作者 checkout | `../nixos-config-exam`，HEAD `11da4247` |
| 上游基线差距 | `0a9340d0..11da4247` 共 99 提交 |
| nixpkgs input | 本仓库 `b7c2ada94fe9`；作者 `624af665418d`（不同，本仓库更新） |
| 审计时间 | 2026-08-15 |

## 批次 1：已知缺口 backport（全部已提交）

| 提交 | 内容 | 来源 |
| --- | --- | --- |
| `9f9dbe3a` | **SSHFP 预计算指纹**：`helpers/host-options.nix` 新增 `ssh.ed25519Fingerprints.{sha1,sha256}`；`dns/common/host-recs.nix` 改用预计算值并对缺失主机 throw；`dns/core/record-handlers.nix` 删除 4 个 `runCommandLocal`（import-from-derivation）处理器；全部 13 台有公钥的 `hosts/*/host.nix` 补指纹。指纹由仓库内公钥离线重算，与 align 分支 2026-08-03 已知值 4/4 吻合，tencent 值与主机注释 SHA256 一致。**顺带消除全局 `nix flake check` 的 IFD 验证缺口**。 | align `4008a7c2` |
| `5790991b` | hydraJobs 去掉 `apps`（hydra-eval-jobs 拒收含字符串元数据的 jobset）。 | align `4008a7c2` |
| `7d1b107a` | 求值弃用修复：netbox `apiTokenPeppersFile`→`apiTokenPepperFiles."1"`；pocket-id 删 `DB_PROVIDER`/`KEYS_STORAGE`；`hardware/lvm.nix` 补 `boot.swraid.mdadmConf`；llama-cpp-qwen3_6 `host/port/hf-repo` 移入 `settings`；readsb `getExe`→`getExe'`；dev-tools flat-flake 按宿主平台解析；stylix cursor 主题改名 `STMCS_601`→`STMC_6_1`；greencloud systemd-networkd `routeConfig` 拍平。 | 上游 `93b300f0` + align `f0c71020` |
| `07a46e23` | tencent systemd-networkd `routeConfig` 拍平（补漏：tencent 08-13 新加，align 时代不存在；同一弃用形式）。 | 对齐 `7d1b107a` 同项 |
| `f6f302b1` | 清理：ai-coding 删 `"npm:pi-lens"`；`dns/common/records.nix` 删无引用 `GeoStorDNSTarget`；删除无主机导入的 `optional-apps/mmrelay.nix`；stylix 显式 `home.pointerCursor.enable` + 禁用过时 opencode target。 | 上游 `3bd34270`/`61aea568`/`93b300f0` + align `7b6c86f1` |
| `f0e104e0` | ~~`patches/nixpkgs/fix-xstatic.patch`~~ —— **已 revert**（`f1d8d81b`）：本仓库 nixpkgs（`b7c2ada94fe9`）已含该修复，补丁重复导致 pkgs-patched 构建失败。 | 上游 `30b12e3b`（不适用） |

## 批次 2：C 类最小参数化（默认值=现状，零行为变化）

| 提交 | 模块 | 选项 | 说明 |
| --- | --- | --- | --- |
| `b0cd1284` | `optional-apps/attic.nix` | `lantian.attic.hostVhost`（默认 false） | 镜像上游 per-host `attic.<hostName>` vhost 模式；启用时需另行配置 DNS 与证书。单实例场景当前不启用。 |
| `b0cd1284` | `common-apps/coredns.nix` | `lantian.coredns.cnSplit`（默认 true） | 把 AliDNS 国内分流分支收进选项，作者 `zones.all` 通用结构可辨认。 |

## C 类登记：有意保留的本地差异（不回退）

| 模块 | 本地差异 | 保留理由 |
| --- | --- | --- |
| `minimal-components/nix.nix` | substituter 顺序：自建 Attic/国内镜像优先、官方垫底 | 大陆网络直连官方慢；注释已写明 |
| `minimal-components/networking.nix` | backupDNSServers CN 感知（AliDNS） | 大陆网络优化 |
| `minimal-components/environment.nix` | `timeZone = Asia/Shanghai` | 本地时区 |
| `minimal-components/firewall.nix` | 压平为单文件 + `wanARPSubnets` 选项（作者为 `firewall/` 目录） | 结构重构、功能等价；后续作者改防火墙目录时注意手工合并 |
| `hosts/router/firewall.nix` | WAN input drop-by-default + 保留源拒绝（作者 lt-home-router 为 policy accept） | 路由层安全审计 2026-08-16 §3.1/3.2 加固；样板 `hosts/h28k/firewall.nix` |
| `common-apps/nginx/proxy.nix` 及 vhost 系列 | 启用门控 `server && public-facing`（作者同用 `public-facing`，08-13 已核对） | 公开站点边界由 `public-facing` 标签控制 |
| `server-components/logging.nix` | Axiom（filebeat7）替代作者 Humio（filebeat8） | 自建日志链路，见 service-providers.md |
| `optional-apps/ncps.nix` | 整文件重写（缓存路径/代理/上游过滤/LRU），含 `cache.upstream.urls` | 私有缓存基础设施；`cache.upstream` 结构与上游一致 |
| `client-apps/mcp-servers.nix` | 锁定 `mcp<2`（SDK 2.x 兼容问题） | 已记录在提交历史 |
| `helpers/constants/nix.nix` | 自建 attic + 国内镜像 substituter 列表 | 与 nix.nix 配套 |
| `optional-apps/acme/default.nix` | `dnsProvider = gcore`、`dnsPropagationCheck = false`、删 nginx reload | Gcore 免费套餐发布规范 |
| `optional-apps/backup/` | `sftpEndpoint` 参数化 + opi5p/google 双仓库 + home 保留期下调至 7/4/1 | 私有备份服务器；保留期下调为有意（作者 08-09 又上调，见遗留项） |
| `optional-apps/attic.nix` | 单一 `attic.zhyi.xin` + vaults3 S3 存储（作者 Telnyx + per-host vhost） | 单实例基础设施；多机时开 `hostVhost` 即可 |
| `helpers/constants/zones.nix` | 删除 NeoNetwork/OpenNIC/作者反解，`zhyi.dn42` 替代 | 不跑 neonetwork，删除自洽 |
| `helpers/host-options.nix` | `neonetwork` 默认 `null`（作者为具体网段） | 防误入作者网络段 |
| `helpers/constants/ports.nix` | 删 Radicle/TranquilPDS，新增自有服务端口 | 实际服务清单 |
| 品牌差异 | `zhyi.xin/zhyi.cc/moliy.site`、`zhyi` 用户、`wg-zhyi`、`fdd8:1938:4e88` LTNET 段、mastodon 账号 | 复刻身份边界 |

## 评估后延后 / 跳过项

| 项 | 上游提交 | 结论 |
| --- | --- | --- |
| n8n 加密密钥用 SOPS 管理 | `cc16c9c1` | 生产 n8n 已有加密凭据，直接设置 `N8N_ENCRYPTION_KEY` 会导致存量凭据不可解密；需先做密钥迁移流程，单独立项 |
| dex 从 clients 自动派生 secrets | `e16dcdc0` | 涉及 oauth2-proxy/dex 生产认证链路与 secrets，风险高，单独评估 |
| `flake.nix` 导出 ipv4/ipv6 列表 | `60cbf21a` | 无已知消费方，跳过 |
| 服务器瘦身选项（tunings/nix-registry/stylix） | `c7235bdd` | 低价值，跳过 |
| firewall ICMPv6 过滤删除 / WAN ARP 强化 | `4e10a15f`/`9d0b2892` | 我们的压平 firewall 已有 `wanARPSubnets` 等价能力，不做目录重构 |
| 备份保留期上调 | `47649a1c` | 我们下调为有意；如备份量允许可重新评估 |
| attic per-host vhost 启用 | — | 单实例场景不启用，见 `hostVhost` 选项 |

## 验证状态与后续

- 本地（macOS）：全部改动文件 `nix-instantiate --parse` 通过；两个新选项经
  `lib.evalModules` 桩验证可正常声明/加载。
- **ml-builder 验证（2026-08-15）**：
  - 关键主机 `toplevel.drvPath` 求值全部成功：greencloud（attic + coredns +
    routeConfig + SSHFP）、hostdare、ml-builder（hydraJobs + llama-cpp）、
    volcengine（pocket-id/netbox）、router，以及无公钥主机 opi03/taishanpi
    （不触发指纹缺失 throw）。
  - 新选项默认值正确：greencloud 上 `lantian.attic.hostVhost = false`、
    `lantian.coredns.cnSplit = true`。
  - `dnscontrol-config` 成功构建，输出 26 条 SSHFP 记录（13 台有公钥主机 ×
    SHA1/SHA256），指纹与仓库内公钥重算值一致，DNS 输出无变化。
  - **`nix flake check` 仍失败，但为既有缺口**：在原始 master
    （`12391e85`，本轮改动前）上复现同样失败——`pkgs-patched` 的
    import-from-derivation 在 flake check 求值期间被禁用（Nix 限制），这是
    nixpkgs 打补丁机制的固有 IFD，与 DNS SSHFP 无关。本轮 SSHFP 改动已移除
    DNS 路径上的 IFD（`runCommandLocal` 处理器），但 flake check 仍需
    pkgs-patched 先存在于 store 才能完整通过。该缺口延续 08-03/08-06 审计
    记录，单列跟踪。
- 提交已推送 origin（`9f9dbe3a`..`11e65f77`）并在 ml-builder 拉取验证。
- SSHFP 指纹由仓库内公钥重算，DNS 输出值不变，无需发布 DNS。
- **fix-xstatic.patch 已回退**（`f1d8d81b`）：本仓库 nixpkgs 已含该修复，
  补丁会导致 pkgs-patched 构建失败，详见审计结论。

## 后续同步守则（沿用）

- 每次同步先记录作者基准提交，再查看作者自上次审计后的提交列表；
- 公共模块的删除、接口变化、安全边界和弃用修复优先跟随作者；
- hosts、硬件、域名、IP、证书、secrets 和生产拓扑禁止机械覆盖；
- 新增公共差异时优先设计参数（本轮 attic/coredns 为例）；
- 每项保留差异都要能指出运行需求、目标主机和验证方法。

## 批次 3：GitHub Actions 工作流对齐（2026-08-15 下午）

| 项目 | 状态 |
| --- | --- |
| `auto-update-data.yml` | 与上游**完全一致**（`diff` 空）：补上 `nix flake update` + push 到 `auto-update` 分支两步，提交步骤改名对齐 |
| `dnscontrol.yml` | 保留 fork 定制：`actions/checkout@v5`（上游 v4）、`install-nix-action@v31`（上游 v26）、rsync 目标 `ci@rsync-ci.zhyi.cc`（上游 `xuyh0120.win`）——动作版本更新与自有 CI 主机，不回退 |
| 定时触发 | 仓库是 **public fork**，GitHub 默认不跑 fork 的 schedule；2026-08-15 已有一次 `schedule` 触发的 dnscontrol 成功 run，说明已可定时触发，后续观察即可 |
| 验证 | `workflow_dispatch` 触发 auto-update-data：**三次均在同一步骤失败**——"Commit updated packages" 推送 master 时 `non-fast-forward`。根因确凿：运行期间（~10–13 分钟）用户对 master 有并发推送，其中一次为 **force push**（`a1ba6bc...9fa4769 forced update`，历史被重写），runner 检出的旧 master 与 origin 分叉。git-auto-commit-action 官方明确不做 `git pull`/rebase（README "No git pull when the repository is out of date"），上游同样承受该竞态，只是作者 master 安静。dnscontrol 工作流在 push 触发下持续全绿（含一次 `schedule` 触发成功 run），不受影响。**决策（用户确认，2026-08-15）：保持与上游逐字节一致，不做 rebase 健壮化**——23:32 UTC 定时（北京 07:32）通常安静预期可通过；工作时段手动触发失败无危害（改动可再生、不碰服务），后续观察定时 run 即可 |

> `codex/upstream-align` 分支内容已被批次 1 以不同 hash 适配到 master（审计正文多处引用该分支 hash），保留不删以免引用悬空。

## 相关文档

- [2026-08-03 作者配置复刻偏移审计](./upstream-replica-audit-2026-08-03.md)
- [2026-07-28 上游对齐偏差审计](./upstream-alignment-audit-2026-07-28.md)
- [2026-08-13 全量 diff 审计](./alignment-audit-2026-08-13.md)
