# 上游对齐审计：除 hosts 外逐字对齐（2026-08-20）

> 目标：将本复刻 fork 与上游 xddxdd/nixos-config 逐字对齐，除 hosts 内容外其余文件逐字一致。
> 但审计发现绝大多数差异是**复刻刻意优化/硬性值**（中国网络适配、自建拓扑、域名/用户名/ASN），
> 直接逐字覆盖会破坏复刻。因此本次产出分三类：
> **① 应对齐**（上游纯逻辑新写法/修复，复刻未跟随）→ 实际修改
> **② 复刻优化/特有**（刻意保留，不动）→ 需用户逐项确认
> **③ 硬性值**（域名/用户名/时区/IP/ASN/证书/SSH key）→ 必须保留（复刻硬性偏离，不算对齐范围）

## 审计范围

- `diff -rq` 复刻 vs 上游，排除 `hosts`/`docs`/`reference`/`.github`/`flake.lock`/`AGENTS.md`/`README.md`/`Makefile`/`.gitignore`
- 同名文件内容不同：**218 个**
- 复刻独有文件：**103 个**（含 6 个垃圾文件）
- 上游独有文件：**21 个**

---

## 第一部分：A 类「应对齐」（纯逻辑差异，复刻未跟随上游新逻辑）

这是本对齐任务**真正要改**的部分。4 组审计子代理结论汇总：

### core 组（5 个）

| 文件 | 上游新增/新写法 | 复刻现状 |
|---|---|---|
| `nixos/client-apps/mcp-servers.nix` | 新增 `exa` MCP server + `sops.secrets.mcp-exa-api-key` → `common/mcp.yaml` | 缺 exa |
| `nixos/minimal-components/kernel.nix` | 新增 `emperors-scepter` 内核模块 | 未同步 |
| `nixos/minimal-components/nix-registry.nix` | registry 条目改为 `to = { type = "path"; path = v; }` | 仍用旧 `flake = { outPath = v; }` |
| `nixos/minimal-components/podman.nix` | podman-auto-update timer 加 `wantedBy = [ "timers.target" ]` | 只有 enable |
| `nixos/hardware/disable-watchdog.nix` | Watchdog 值改 `lib.mkForce null` | 仍 `"0"`（语义等价，写法上游已更新） |

### srv（4 个）

| 文件 | 上游新增/新写法 | 复刻现状 |
|---|---|---|
| `nixos/common-apps/nginx/vhost-options/location-options.nix` | `$host:${LT.portStr.HTTPS}` 显式补端口 | 用 `$http_host`（旧写法） |
| `nixos/common-apps/yggdrasil/public-peers.json` | 新增 peer `tls://153.120.42.137:54232` | 未同步 |
| `nixos/server-apps/bird/config/dn42.nix` | 新增 `prefer older yes`（anti-flap，两处）+ grc CN 分支 | 缺 |
| `nixos/server-apps/bird/config/ltnet.nix` | 新增 `prefer older yes`（anti-flap） | 缺 |

### opt（6 处日志降噪 + 无）

| 文件 | 上游新增 | 复刻现状 |
|---|---|---|
| `nixos/optional-apps/clickhouse.nix` | logger `<console>false</console>` | `true` |
| `nixos/optional-apps/lemmy.nix` | `RUST_LOG="error"` | 缺 |
| `nixos/optional-apps/matrix-synapse/matrix-synapse.nix` | `log.root.level="WARNING"` | 缺 |
| `nixos/optional-apps/plausible.nix` | `LOG_LEVEL="warning"` | 缺 |
| `nixos/optional-apps/sonarr/bazarr.nix` | `LOG_LEVEL="warn"` | 缺 |
| `nixos/optional-apps/sonarr/prowlarr.nix` | `LOG_LEVEL="warn"` | 缺 |
| `nixos/optional-apps/sonarr/radarr.nix` | `LOG_LEVEL="warn"` | 缺 |
| `nixos/optional-apps/sonarr/sonarr.nix` | `LOG_LEVEL="warn"` | 缺 |

### misc（10 个）

| 文件 | 上游新增/新写法 | 复刻现状 |
|---|---|---|
| `flake-modules/commands/update-flake.nix` | `find nixos/home/pkgs -name 'update.*'` 批量执行 | 缺 |
| `home/common-apps/stylix.nix` | `targets.opencode.enable=false` | 缺 |
| `home/client-apps/git.nix` | `.pi` ignore 条目 | 缺 |
| `home/common-apps/tunings.nix` | lfs.enable 用 `LT.this.hasTag LT.tags.client` | 硬编码 true |
| `overlays/00-kde-env-cleanup.nix` | 用 `lndir` 实现共享链接 | 用 `cp -r + chmod`（旧写法） |
| `dns/core/record-handlers.nix` | 新增 SSHFP_RSA/ED25519_SHA1/SHA256 handler（runCommandLocal 实时算指纹） | 复刻删了这组，改 host-options 预计算 |
| `dns/common/host-recs.nix` | SSHFP 直接由 pubkey 生成 | 预计算 sha1/sha256 字段 |
| `helpers/constants/zones.nix` | 新增 NeoNetwork/OpenNIC zones、ip6.arpa 段 | 缺 |
| `flake.nix` | 新增 git-hooks/nixos-hardware/rust-overlay/treefmt-nix inputs + ipv4List/ipv6List helper + hydra 附带 apps | 缺（另有复刻特有 nixpkgs-stable/nix-darwin/opi 内核 cross） |
| `home/client-apps/firefox/default.nix` | 引入 `./homepage.nix` | 缺 |

> 注：`dns` 组 3 处 SSHFP 相关（record-handlers/host-recs/zones）是**同一套上游新机制**，需一起评估是否对齐（涉及 host-options 预计算 vs runCommandLocal 的取舍，可能引入 IFD）。

---

## 分工：B类「复刻刻意优化」——需用户逐项确认是否保留

这些是复刻针对中国网络/硬件/自建服务做的刻意改造，直接覆盖会破坏。**用户要求逐项列出决策。**

| 文件 | 优化内容 | 建议 |
|---|---|---|
| `nixos/minimal-components/nix.nix` | 自建 Attic/镜像缓存优先，官方 cache.nixos.org 殿后 | 保留（大陆加速） |
| `nixos/minimal-components/networking.nix` | CN 主机走国内 DNS（223.5.5.5 等） | 保留 |
| `nixos/client-components/cups.nix` | 仅 x86_64 启私有打印驱动 | 保留 |
| `nixos/minimal-components/smtp.nix` | after/requires sops-install-secrets 排序 | 保留 |
| `nixos/minimal-components/backup/*.nix` | 备份目标改自建 SFTP（opi5p），非 Hetzner storagebox | 保留 |
| `nixos/minimal-components/ssh-harden.nix` | 自建备份 host + volatile root 加固 | 保留 |
| `nixos/minimal-components/zerotier/default.nix` | 自组网 network ID + DNS 下发 | 保留 |
| `nixos/minimal-modules/zerotierone-controller.nix` | 新增 dns option | 保留 |
| `nixos/pve-components/proxmox.nix` | PVE LXC container 支持 | 保留 |
| `nixos/client-apps/google-chrome.nix` | homepage 指向 homepage.rock5c.zhyi.cc | 保留 |
| `nixos/client-apps/firefox.nix` | ShowHomeButton=false | 保留 |
| `nixos/hardware/lvm.nix` | dm-thin-pool 内核模块 | 保留 |
| `nixos/minimal-apps/rsync-server.nix` | systemd 加固 + greencloud 主服务器 | 保留 |
| `nixos/minimal-components/prometheus-exporters.nix` | zerotier==null 监听 127.0.0.1 | 保留 |
| `nixos/common-apps/coredns.nix` | CN 优先 AliDNS 抽象成 option | 保留 |
| `nixos/server-apps/powerdns-recursor.nix` | CN publicResolvers + NTA Cloudflare 域 | 保留（+补 loglevel=4） |
| `nixos/server-apps/coredns.nix` | 无 OpenNIC/NeoNetwork（复刻无对应服务） | 保留 |
| `nixos/server-apps/wg-mesh.nix` | tcpTransportPeers 机制 | 保留 |
| `nixos/server-components/logging.nix` | Axiom 托管替代 Humio | 保留 |
| `nixos/common-apps/nginx/nginx.nix` | tmpfiles 修复 + Server 头 | 保留 |
| `nixos/common-apps/nginx/oauth2-proxy.nix` | 单 sops 文件结构 | 保留 |
| `flake-modules/commands/colmena.nix` | `--no-substitute` | 保留 |
| `flake-modules/commands/dnscontrol.nix` | GOPROXY + 主机 SSH key 探测 | 保留 |
| `flake-modules/nixos-configurations.nix` | darwin 主机过滤 | 保留 |
| `helpers/constants/nix.nix` | 国内 nix 镜像（SJTU/USTC/TUNA） | 保留 |
| `helpers/constants/misc.nix` | 新增 `"macos"` tag | 保留 |
| `helpers/constants/ports.nix` | 大量复刻端口 | 保留 |
| `helpers/cities.json` | 复刻城市 | 保留 |
| `helpers/host-options.nix` | nullOr 放宽 + nixBuilder/ed25519Fingerprints/tcpTransport | 保留（局部） |
| `home/client-apps/ai-coding/default.nix` | 全套 AI/agent 集成 | 保留 |
| `home/client-apps/conda.nix` | USTC 源 | 保留 |
| `home/client-apps/packages.nix` | hostname 条件化 | 保留 |
| `home/common-apps/stylix.nix` | targets.opencode（局部对齐） | 部分对齐 |
| `overlays/50-general.nix` | bazarr 中文化 + pve-container | 保留 |
| `nixos/optional-apps/` 大量服务 | 域/证书/主机硬换（见 C 类） | 保留 |

### B 类最终结论（2026-08-20 复核，用户决策「对齐架构，保留硬性值」）

经 5 组并行 subagent 逐文件 diff 复核，B 类 35 个文件绝大多数为**硬性值替换或复刻核心功能**，对齐会破坏复刻（rsync-server 对齐 eval 必挂、ai-coding 删核心、host-options 断 SSHFP、darwin 过滤泄漏、zerotier 断 LTNET 等）。按用户决策「对齐架构、保留硬性值」，**全部保留**，仅两处纯逻辑差异实际对齐：

| 文件 | 对齐项 | 说明 |
|---|---|---|
| `nixos/server-apps/powerdns-recursor.nix` | 恢复 `logging.loglevel = 4` | 纯日志详细度，非硬性值，上游有 fork 删 |
| `nixos/server-apps/powerdns-recursor.nix` | `rpzFile("${src}")` 去掉多余 `/rpz.delegacy.monostack.org.zone` | src 本身即单个 zone 文件，fork 写法是 `文件/文件` 潜在 bug，对齐上游 |

**复核中排除的误判项**（subagent 曾标 ALIGN/UNKNOWN，实际为复刻核心）：
- `common-apps/coredns.nix` 顶部 `let netns`：fork 实为 `options.lantian.coredns.cnSplit`（CN 适配抽象成 option），非纯结构重构 → 保留
- `common-apps/coredns.nix` zone 列表：fork 显式展开 `(DN42 ++ ... ++ Others)` 刻意排除 NeoNetwork/OpenNIC，对齐 `zones.all` 会引入 fork 不存在的 zone → 保留
- `powerdns-recursor.nix` rpzFile 路径：核实 fork 与上游 delegacy-rpz 源完全相同（同一 URL 指向单个 zone 文件），fork 写法冗余 → 已对齐

---

## C类「硬性值」—— 必须保留，不在对齐范围

全部 218 个差异中，绝大多数是以下硬性值的机械替换，逐字对齐这些会**破坏复刻的硬性偏离规则**：
- 用户名 `zhyi` vs `lantian`
- 域名 `zhyi.xin`/`zhyi.cc`/`moliy.site` vs `lantian.pub`/`xuyh0120.win`/`ltn.pw`
- 时区 `Asia/Shanghai` vs `America/Los_Angeles`
- ASN `3712` vs `2547`、IPv6 前缀 `fdd8:1938:4e88` vs `fdbc:f9dc:67ad`
- 证书名 `lets-encrypt-*` vs `zerossl-*`
- SSH key 指纹 `DAE24FE1...` vs `B50EC319...`
- 用户名 `Magic Flash` vs `Lan Tian`、用户 `zhyi` vs `lantian`
- 复刻自建主机 `hostdare`/`greencloud`/`opi5p`/`ml-builder`/`ml-laptop` vs 上游 `bwg-lax`/`colocrossing`/`alice`/`lt-hp-omen`

**这些必须在最终提交时保留 fork 侧值**，对齐只改 A 类纯逻辑。

---

## 复刻独有文件（103 个）

### 垃圾文件（建议清理）
- `.DS_Store`、`.reasonix`、`.trae/rules/git-commit-message.md`（应 untrack）、`.tmp-pull-rknn.sh`、`.tmp-pull3.sh`、`.vscode`、零字节 `, ready if info.get(ready) else NOT`

### 复刻自有功能（保留，不入对齐）
- `dsh-web`、`deepseek-harness`、`rockchip` 全家、`freshrss`、`home-assistant`、`memos`、`sublinkpro`、`mihomo`、`wg-mesh-wstunnel`、`dreame-vacuum`、`docs`/`reference` 等

### 上游独有（复刻无，21 个）—— 需决策是否补齐

| 上游独有文件 | 判定 |
|---|---|
| `home/client-apps/firefox/homepage.nix` | **真缺，应对齐**（上游 firefox 引入） |
| `home/client-apps/radicle.nix` | **真缺**（作者个人 radicle，复刻可能不需要） |
| `nixos/optional-apps/resin.nix` | **真缺**（作者服务，复刻无对应） |
| `nixos/optional-apps/tranquil-pds.nix` | **真缺**（作者 PDS） |
| `nixos/optional-apps/llama-cpp-qwen3.nix` | 复刻改名 `llama-cpp-qwen3_6.nix`，同模块 |
| `lantian.pub/ltn.pw/xuyh0120.win` 等域名 zone | 硬性域名，不复刻 |
| `lantian.dn42.nix`/`lantian.eu.org.nix`/`lantian.neo.nix`/`3gppnetwork.org.nix`/`56631131.xyz.nix`/`pp.ua.nix`/`误人子弟.pub.nix` | 作者域名 DNS zone，复刻用自己域名 |
| `radicle.nix`（顶层）/`resin.nix`/`sync-uptimerobot-monitors.py`/`tranquil-pds.nix`/`fix-xstatic.patch` | 复刻无此功能，可不补 |

---

## 决策请求（需用户逐项确认）

### A 类（我要主动对齐，用户只需确认 Y/n）
上文 A 类清单 26 个文件，全是上游纯逻辑更新。建议直接对齐，仅有的取舍点是 **dns 的 SSHFP 机制**（record-handlers/host-recs/zones 三个，涉及 IFD 取舍）。

### B 类（复刻优化）
按上文 B 类清单逐个保留，用户如对某一项想对齐，单独指出。

### C 类
全部保留 fork 原文。

### 上游独有文件
- `homepage.nix` → 补齐
- `llama-cpp-qwen3.nix` → 已是 `llama-cpp-qwen3_6.nix`，不改名
- `radicle.nix`/`resin.nix`/`tranquil-pds.nix`/`sync-uttersobot-monitors.py` → 复刻无对应服务，跳过
- 域名 zone 文件 → 不复刻（硬性）

### 垃圾文件 → 清理

---

## 待办（ml-builder 验证）
1. `nix flake check` / `make build`
2. `nix flake lock --update-input stylix`（flake.nix stylix 分支已改）
3. 提交 push（A 类对齐 + 清理 + 补齐）

---

## 附：stylix 对齐引入的无限递归回归（2026-08-20 排查记录）

### 现象
`make build` / `nix flake check` 报 `error: infinite recursion encountered`，
栈顶在 `helpers/default.nix:13:48`（`call = path: builtins.removeAttrs (lib.callPackageWith (pkgs // helpers) path { })`），
经 `_module.args.pkgs` → `config` → 回到 stylix。

### 根因
`nixos/minimal-components/stylix.nix` 第 37 行 `autoEnable = LT.this.hasTag LT.tags.client`
（以及第 47 行 cursor 的 `if LT.this.hasTag ...`）在 fork 环境触发循环：
读取 `LT.this` → `helpers` → `_module.args.pkgs` → `config` → 回到 stylix。

对齐前 fork 刻意用 `autoEnable = lib.mkDefault false` + 在 `nixos/client.nix` 里设
`stylix.autoEnable = true`，并留注释说明「Reading LT.this here causes a cycle with target
defaults in newer Stylix releases」。对齐到上游 `LT.this.hasTag` 写法后，该循环在 fork 复现。

### 二分定位
| commit | 结果 |
|---|---|
| `99b3add6`（stylix 对齐前） | ✅ `All done!` |
| `9591a458`（stylix 对齐前） | ✅ `All done!` |
| `38473a3d`（stylix 对齐） | ❌ 无限递归 |
| 之后所有 | ❌ 无限递归 |

**回归由 `38473a3d`（stylix 对齐）引入。**

### 关键事实
- 上游 `xddxdd/nixos-config` 用完全相同的 `autoEnable = LT.this.hasTag LT.tags.client` 写法，
  `lt-hp-omen` 求值 `stylix.autoEnable` 返回 `true`，**上游构建正常**。
- `helpers/default.nix`、`flake.nix` 的 stylix input、`flake-modules/nixpkgs-options.nix`
  均已逐字核对与上游一致。
- 因此 fork 里必有一个**上游没有的差异**（fork 特有模块/主机配置）让 `_module.args.pkgs`
  在 stylix target default 解析期间被强制求值，从而触发循环。该差异尚未定位。

### 用户决策（2026-08-20）
1. **对齐架构，保留硬性值** —— 架构/写法对齐上游，fork 硬性值（域名/用户名/主机/IP/网络 ID）保留。
2. **不怀疑上游** —— 作者原版是权威，必须能构建；问题一定出在 fork 对齐不足。
3. **还原 fork 特有 hack 注释** —— 为绕开问题而改公共模块加的注释/写法要还原，提高对齐度。
4. **ml-builder 可用作者缓存**（attic.xuyh0120.win/lantian）加速构建。

### 下一步
定位 fork 特有差异（候选：某 fork 特有模块或主机配置强制 `_module.args.pkgs` 求值）。
若循环是 fork 结构固有，则按「对齐架构、保留硬性值」还原对齐前 workaround
（`autoEnable = lib.mkDefault false` + client.nix 设 autoEnable），并作为 fork 偏离登记。
验证：ml-builder `make build`（用作者 attic 缓存加速）。
