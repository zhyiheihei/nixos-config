# 2026-08-15 上游对齐审计（分批 backport）

## 审计结论

本轮按「分块、分批」方式对 `master` 与作者上游做了一轮对齐审计，全部改动
分批提交，无一次性大合并：

- **刷新了上游基线**：`git fetch upstream` 后 `upstream/master` 为
  `11da4247`（2026-08-14，作者最新），此前本地远端停留在 `0a9340d0`
  （2026-07-27），落后 99 个提交。两仓库 nixpkgs input 同为
  `c0b0e0fddf73`，对照可信。
- **真实缺口很少**：99 个新提交里大部分是作者私有内容（radicle、ATproto
  PDS、包版本 bump、作者主机配置）。逐项核验后，真正需要跟随的缺口只有
  补丁、弃用修复和少量清理（见下文批次 1）。
- **此前差异地图的误报已澄清**：早期对过期远端的 diff 曾把 nix-cache-proxy、
  `low-disk` 门控、`icmp_msgs_per_sec`/`nf_conntrack_max`、speedtest-go、
  NixCacheProxy 端口等列为「上游有我们没有」，用新鲜基线（exam
  `11da4247`）逐项复核后全部不成立——两边一致。
- **C 类（我们主动改的公共模块）全部保留**，其中 2 项做了最小参数化（批次 2），
  其余登记在案（见 §3），不回退。

## 审计基准

| 项目 | 值 |
| --- | --- |
| 本仓库提交 | `b0cd1284`（批次 2 提交后） |
| 上游远端 | `upstream/master = 11da4247`（fetch 后） |
| 作者 checkout | `../nixos-config-exam`，HEAD `11da4247` |
| 上游基线差距 | `0a9340d0..11da4247` 共 99 提交 |
| nixpkgs input | 两边同 rev `c0b0e0fddf73` |
| 审计时间 | 2026-08-15 |

## 批次 1：已知缺口 backport（全部已提交）

| 提交 | 内容 | 来源 |
| --- | --- | --- |
| `9f9dbe3a` | **SSHFP 预计算指纹**：`helpers/host-options.nix` 新增 `ssh.ed25519Fingerprints.{sha1,sha256}`；`dns/common/host-recs.nix` 改用预计算值并对缺失主机 throw；`dns/core/record-handlers.nix` 删除 4 个 `runCommandLocal`（import-from-derivation）处理器；全部 13 台有公钥的 `hosts/*/host.nix` 补指纹。指纹由仓库内公钥离线重算，与 align 分支 2026-08-03 已知值 4/4 吻合，tencent 值与主机注释 SHA256 一致。**顺带消除全局 `nix flake check` 的 IFD 验证缺口**。 | align `4008a7c2` |
| `5790991b` | hydraJobs 去掉 `apps`（hydra-eval-jobs 拒收含字符串元数据的 jobset）。 | align `4008a7c2` |
| `7d1b107a` | 求值弃用修复：netbox `apiTokenPeppersFile`→`apiTokenPepperFiles."1"`；pocket-id 删 `DB_PROVIDER`/`KEYS_STORAGE`；`hardware/lvm.nix` 补 `boot.swraid.mdadmConf`；llama-cpp-qwen3_6 `host/port/hf-repo` 移入 `settings`；readsb `getExe`→`getExe'`；dev-tools flat-flake 按宿主平台解析；stylix cursor 主题改名 `STMCS_601`→`STMC_6_1`；greencloud systemd-networkd `routeConfig` 拍平。 | 上游 `93b300f0` + align `f0c71020` |
| `f6f302b1` | 清理：ai-coding 删 `"npm:pi-lens"`；`dns/common/records.nix` 删无引用 `GeoStorDNSTarget`；删除无主机导入的 `optional-apps/mmrelay.nix`；stylix 显式 `home.pointerCursor.enable` + 禁用过时 opencode target。 | 上游 `3bd34270`/`61aea568`/`93b300f0` + align `7b6c86f1` |
| `f0e104e0` | `patches/nixpkgs/fix-xstatic.patch`：复制自 exam（上游 `30b12e3b`）。setuptools≥83 移除 `pkg_resources.declare_namespace`，9 个 xstatic 包改 `setuptools_80`。经 `nixpkgs-options.nix` 目录全量补丁机制自动应用，惰性不触发不构建。 | 上游 `30b12e3b` |

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

- 本地：全部改动文件 `nix-instantiate --parse` 通过；两个新选项经
  `lib.evalModules` 桩验证可正常声明/加载。
- DNS 求值、`nix flake check`、受影响主机构建需在 **ml-builder** 完成
  （本机 macOS 无法构建 x86_64-linux 的 patched nixpkgs）。
- 提交已推送 origin 并在 ml-builder 拉取验证（见批次 3 验证记录）。
- SSHFP 指纹由仓库内公钥重算，DNS 输出值不变，无需发布 DNS。

## 后续同步守则（沿用）

- 每次同步先记录作者基准提交，再查看作者自上次审计后的提交列表；
- 公共模块的删除、接口变化、安全边界和弃用修复优先跟随作者；
- hosts、硬件、域名、IP、证书、secrets 和生产拓扑禁止机械覆盖；
- 新增公共差异时优先设计参数（本轮 attic/coredns 为例）；
- 每项保留差异都要能指出运行需求、目标主机和验证方法。

## 相关文档

- [2026-08-03 作者配置复刻偏移审计](./upstream-replica-audit-2026-08-03.md)
- [2026-07-28 上游对齐偏差审计](./upstream-alignment-audit-2026-07-28.md)
- [2026-08-13 全量 diff 审计](./alignment-audit-2026-08-13.md)
