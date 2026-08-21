# 上游覆盖后重新对齐规则（2026-08-20）

> 背景：为绝对对齐上游，用户对 `nixos-config` 做了一次上游覆盖（308 文件变更，
> 2614 插入 / 48150 删除，未提交）。覆盖后公共模块与上游逐字一致，但：
> 1. `hosts/` 目录保留（我的 17 台主机），未覆盖。
> 2. 公共模块引用了作者主机名（`LT.hosts."colocrossing"` 等），我的 `hosts/` 里没有。
> 3. `dns/domains/` 被替换成作者域（lantian.pub/xuyh0120.win/ltn.pw），我的
>    zhyi.cc/zhyi.xin/moliy.site 被删。
> 4. 我的主机配置仍 import 已被删的 optional-apps/hardware/pkgs 文件。
> 5. 用户名/路径仍是作者（Lantian/lantian），需替换为 MagicFlash/zhyi。
>
> 本文档是本次重新对齐的**唯一规则来源**。所有改动必须符合本文档，冲突以本文档为准。

## 0. 铁律（覆盖前逐条过）

- **总原则：all in 上游。** 覆盖对齐是第一目标，遇到任何冲突优先跟随作者（上游）
  的结构与逻辑，只保留两类硬性偏离（域名、用户名），其余差异都按上游来。
  **不要用「恢复 HEAD 旧版」来躲开对齐**——HEAD 旧版可能是未对齐上游的写法，
  直接恢复会再次脱轨（踩坑例：firewall 上游拆成 `firewall/` 目录，HEAD 是扁平
  `firewall.nix`，应删扁平文件对齐目录，而非恢复 HEAD）。
- 本地只做编辑与 git；nix 求值/构建/部署只在 ml-builder。
- 同步只许 `git pull --ff-only`；禁止 reset --hard / clean -fd。
- 绝不提交明文 secrets；recipient 用 native age。
- 上游 = `../nixos-config-exam`，每次查看前先 `git pull`。
- 硬性偏离只有两类：域名（zhyi.xin）与硬编码用户名（zhyi）。
- 不动 `flake-modules/` 与公共 `nixos/optional-apps/*.nix` 的**上游逻辑**；
  差异通过主机级覆盖/独立模块/本文档登记解决。
- 构建只压 ml-builder。

## 1. 域名映射（唯一硬性偏离）

> 用户拍板：域名体系统一为单一 **zhyi.xin**（t31），不再有 zhyi.cc/moliy.site 双域。

| 作者域 | 我的域 | 职责 |
| --- | --- | --- |
| `lantian.pub` | `zhyi.xin` | 公开服务域 |
| `xuyh0120.win` | `zhyi.xin` | 主机/私有服务域（并入 zhyi.xin） |
| `ltn.pw` | `zhyi.xin` | 附属公开入口 |
| `ltnet.xuyh0120.win` / `ltnet.lantian.pub` | `ltnet.zhyi.xin` | 主机地址记录域 |
| `lantian.dn42` | `zhyi.dn42` | DN42 域 |
| `lantian.neo` | **置空**（用户无 NeoNetwork） | NeoNetwork 域（不启用，`fd10:127:10` 及 `zhyi.neo` 相关配置全部移除） |
| `误人子弟.pub` / `xn--gmqs02au1c935d.pub` | `zhyi.xin` | 个人附属（并入 zhyi.xin） |
| `lantian.eu.org` / `pp.ua` / `3gppnetwork.org` / `56631131.xyz` | 保留（非作者自有域，不映射） | 外部域 |

### 子域映射规则

- `<svc>.lantian.pub` → `<svc>.zhyi.xin`（公开服务）
- `<svc>.xuyh0120.win` → `<svc>.zhyi.xin`（主机/私有）
- `<host>.xuyh0120.win` → `<host>.zhyi.xin`（主机地址）
- `<svc>.<host>.xuyh0120.win` → `<svc>.<host>.zhyi.xin`（私有服务）
- `<svc>.ltn.pw` → `<svc>.zhyi.xin`
- 作者域内嵌在字符串/注释/脚本里的，同样替换。

### 判定公开/私有

先查作者原版：作者的独立公开应用 = `<svc>.lantian.pub` → `<svc>.zhyi.xin`；
作者的主机私有服务 = `<svc>.<host>.xuyh0120.win` → `<svc>.<host>.zhyi.xin`。
带自身认证的服务（Gitea 等）仍是公开服务。

## 2. 主机映射（作者主机 → 我的主机）

### 2.1 用户拍板的 4 个映射

| 作者主机 | 我的主机 | 角色 |
| --- | --- | --- |
| `lt-hp-omen` | `ml-laptop` | 主力客户端（物理笔记本） |
| `lt-home-rdp` | `ml-builder` | 家庭 RDP/构建机 |
| `pve-epyc` | `pve-5700u` | PVE 宿主 |
| `lt-home-router` | `router` | 家庭路由器 |

### 2.2 由配置推导的映射（用户授权「自己看配置找对应」）

| 作者主机 | 我的主机 | 推导依据 |
| --- | --- | --- |
| `lt-home-vm` | `rock5c` | 家庭服务 VM 已退役，应用迁至 ROCK5C/OPI5P/PVE |
| `lt-dell-wyse` | `ml-2700` | 作者物理笔记本（旁证：ml-laptop 对齐 lt-hp-omen，ml-2700 对齐 lt-dell-wyse） |
| `lt-dell-wyse-thin` | `opi03` | 瘦客户端/实验设备 |
| `lt-rpi4` | `lubancat1` | 低功耗 ARM 板 |
| `lt-home-lte` | `h28k` | 异地/备用路由器 |
| `pve-c3758` | `taishanpi` | 暂停维护的 ARM 板 |
| `pve-hp-z220-sff` | `opi5p` | 家庭服务/媒体 |
| `alice` | `volcengine` | CN 香港/宁波 VPS，公网入口 |
| `buyvm` | `google` | 海外 VPS |
| `bwg-lax` | `hostdare` | 美西 VPS，公网入口 |
| `colocrossing` | `greencloud` | 海外 VPS，公共服务 |
| `terrahost` | `tencent` | 海外 VPS，监控/服务 |
| `v-ps-sea` | `tencent` | 海外 VPS |
| `virmach-ny1g` | `hostdare` | 美东 VPS |
| `virmach-ny6g` | `hostdare` | 美东 VPS |
| `zgocloud` | `volcengine` | CN VPS |
| `oracle-vm1` | `google` | 海外 VPS |
| `oracle-vm2` | `google` | 海外 VPS |
| `oracle-vm-arm1` | `rock5c` | ARM VPS |
| `azure-vm1` | `tencent` | CN VPS |
| `azure-vm2` | `tencent` | CN VPS |
| `azure-vm3` | `tencent` | CN VPS |

> 注：作者 VPS 数量（约 15 台）远多于我的 VPS（5 台：hostdare/volcengine/
> greencloud/google/tencent）。多对一映射时，以**角色/地域最接近**为准。
> 若某作者主机在公共模块里只被引用为「某服务的承载者」，而我的对应主机
> 不承载该服务，则**删除该引用**（见 §4），不强行映射。

### 2.3 实现方式

`helpers/fn/hosts.nix` 恢复上游原版（**无别名**）。公共模块里所有 `LT.hosts.<作者主机>`
引用**直接替换成我的真实主机名**（映射见 §2.1/§2.2），例如
`LT.hosts."colocrossing"` → `LT.hosts."greencloud"`、`LT.hosts.pve-epyc` →
`LT.hosts.pve-5700u`、`LT.publicIPv4For "bwg-lax"` → `LT.publicIPv4For "hostdare"`。

> 教训：**别名是绕开对齐的做法**（t29 移除）。应直接替换引用，让公共模块与上游
> 逐字一致（除域名/用户名/主机映射）。

## 3. 用户名 / 路径映射

| 作者 | 我的 |
| --- | --- |
| 用户名 `Lantian` | `MagicFlash` |
| 用户名 `lantian`（小写） | `zhyi` |
| 路径/目录 `lantian` | `zhyi` |
| `lantian1998`（GitHub 等） | `zhyiheihei` |

- 替换范围：所有 `.nix`、`.sh`、`.py`、`.yml`、`.json`、`.md`、`.toml`、`.rs`、`.c`、`.h`、`.lua` 文件。
- 注意：`lantian` 作为**域名子串**（如 `lantian.pub`）时按 §1 域名规则处理，
  不按用户名规则处理。先做域名替换，再做用户名/路径替换。
- 作者域名 `lantian.dn42`/`lantian.neo` 里的 `lantian` 是域名，不是用户名。
- **时区**：`nixos/minimal-components/environment.nix` 的 `time.timeZone` 是**硬性值**
  `Asia/Shanghai`（HEAD 原值，我的主机在中国）。上游是 `America/Los_Angeles`（作者
  时区），**不要对齐**。每次覆盖后检查此处是否被改回上游时区。

- **`.rs` 等源码文件也要替换**（踩坑例：`pkgs/e164-verify/src/naptr.rs` 的
  `lantian.dn42` 测试字符串，HEAD 已是 zhyi.dn42 但覆盖后回归，需同样替换）。

## 4. 未映射作者主机的引用清理

- 若某作者主机在公共模块里被引用，但 §2 没有对应到我的主机（或对应主机
  不承载该服务），则**删除该引用**（该服务/记录/依赖一并删除）。
- 删除前先确认：该引用是否影响我的主机 eval。若影响，必须删；若只是
  DNS 记录/可选服务，删掉即可。
- 删除后登记到本文档「已清理引用」清单。

## 5. 被删文件的恢复规则

- 我的主机配置仍 import 的、但被覆盖删掉的文件，**从 git HEAD 恢复**。
- 恢复后按本文档做域名/用户名/路径替换。
- 若某被删文件**没有任何我的主机引用**，则不恢复（用户拍板）。
- 已确认需恢复的文件清单（由 agent 执行时核对）：

| 文件 | 引用它的主机 |
| --- | --- |
| `nixos/optional-apps/sublinkpro-nix.nix` | greencloud |
| `nixos/optional-apps/jellyfin-apple.nix` | macmini |
| `home/macos.nix` | macmini |
| `flake-modules/darwin-configurations.nix` | flake.nix |
| `nixos/optional-apps/llama-cpp-qwen3_6.nix` | ml-builder |
| `nixos/hardware/rockchip/accelerator-metrics.nix` | opi5p, rock5c |
| `nixos/optional-apps/frigate-rockchip.nix` | opi5p |
| `nixos/optional-apps/filecodebox-nix.nix` | opi5p |
| `nixos/optional-apps/home-assistant.nix` | opi5p |
| `nixos/optional-apps/ignis.nix` | opi5p |
| `nixos/optional-apps/immich-rockchip.nix` | opi5p |
| `nixos/optional-apps/memos-nix.nix` | opi5p |
| `nixos/optional-apps/resilio-sync.nix` | opi5p |
| `nixos/optional-apps/sun-panel-nix.nix` | opi5p |
| `nixos/optional-apps/wallos.nix` | opi5p |
| `nixos/optional-apps/qbittorrent-seedbox.nix` | opi5p |
| `nixos/optional-apps/metacubexd.nix` | rock5c |
| `nixos/optional-apps/immich-rknn-worker.nix` | rock5c |
| `nixos/optional-apps/chinesesubfinder.nix` | rock5c |
| `nixos/optional-apps/handbrake-rockchip.nix` | rock5c |
| `nixos/optional-apps/jellyfin-rockchip.nix` | rock5c |
| `nixos/optional-apps/moviepilot.nix` | rock5c |
| `nixos/optional-apps/hubproxy.nix` | tencent |
| `nixos/optional-apps/navdash.nix` | tencent |
| `nixos/optional-apps/halo.nix` | volcengine |
| `pkgs/opi03-redroid-kernel/` | flake.nix |
| `pkgs/opi5p-kernel/` | flake.nix |
| `pkgs/rock5c-kernel/` | flake.nix |
| `pkgs/opi03-mali-kbase/` | flake.nix |

> 注意：`nixos/optional-apps/` 里被删的**上游没有的文件**（如 `uni-api.nix`、
> `dsh-web/`、`metapi.nix`、`grafana.nix`、`searxng.nix`、`dex.nix`、`glauth.nix`、
> `pocket-id.nix`、`vaultwarden.nix`、`homepage.nix`、`ncps-client.nix`、`samba.nix`、
> `sunshine.nix`、`syncthing/`、`llama-cpp.nix`、`opencl.nix`、`nix-distributed.nix`、
> `archiveteam.nix`、`clawemail.nix`、`picoclaw.nix` 等）**不在上面的删除清单里**，
> 说明它们**没被删**（仍存在），无需恢复。恢复清单只列**确实被删且被引用**的。

## 6. 执行顺序（agent 分工）

1. **恢复被删文件**：从 git HEAD 恢复 §5 清单里的文件（含 flake.nix 引用的 pkgs）。
2. **域名替换**：在恢复的文件 + 我的 hosts/ 里做 §1 域名映射（统一 zhyi.xin）。
3. **用户名/路径替换**：做 §3 映射。
4. **主机引用直换**：公共模块 `LT.hosts.<作者主机>` 直接替换成真实主机（无别名，见 §2.3）。
5. **清理未映射引用**：§4。
6. **追上游机制演进**：host-options 对齐上游（删 nixBuilder/ed25519Fingerprints/tcpTransport/wg-zhyi）、SSHFP 运行时计算、wg 改名 wg-lantian、删 wg-mesh-wstunnel、补 OpenNIC（见 §8 第八轮）。
7. **私有基础设施保留**：日志 Axiom、备份 opi5p、DN42（fdd8 ULA+ASN 3712）、attic、分区域 DNS、networking CN DNS、zerotier 网络ID（见 §9 J 类）。
8. **加作者 attic**：`helpers/constants/nix.nix` 加 `authorAttic`（`inputs.nur-xddxdd.meta.atticUrl`）。
9. **域名统一 zhyi.xin**：zhyi.cc/moliy.site 并入 zhyi.xin（见 §8 第十一轮）。
10. **验证**：`make build`（ml-builder）通过。
11. **提交**：conventional commits，中文说明「为什么」。

## 7. 验证标准

- `make build` 在 ml-builder 通过（所有主机可 eval）。
- `git diff` 无明文 secrets。
- 域名/用户名替换无遗漏（grep 检查 lantian.pub/xuyh0120.win/ltn.pw/Lantian/lantian）。
- 提交信息用 conventional commits，中文说明「为什么」。

## 8. 已清理引用登记（执行时追加）

### 执行结果（2026-08-20，队长接管 t1-t4）

**已从 git HEAD 恢复（被覆盖删掉且被引用）**：§5 清单 29 项 + 补充恢复：
- `nixos/hardware/hinlink-h28k/`、`lubancat-1/`、`orangepi-zero3/`、`orangepi-5-plus/`、
  `rock-5c/`、`nanopi-r5c/`、`taishanpi/`、`rockchip/default.nix`、`make-nix-btrfs-fs.nix`
- `nixos/optional-apps/dsh-web/`、`filecodebox.nix`、`memos.nix`、`sublinkpro/`、
  `sun-panel.nix`、`vertex.nix`、`grafana/dashboards.nix`
- `nixos/server-apps/mihomo.nix`、`wg-mesh-wstunnel.nix`
- `nixos/minimal-components/firewall.nix`
- `overlays/55-rockchip-media.nix`、`56-immich-rknn.nix`、`57-dreame-vacuum.nix`、
  `58-frigate-hass.nix`、`61-deepseek-harness.nix`
- `pkgs/deepseek-harness/`、`dreame-vacuum/`、`frigate-hass/`、`hass-web-proxy-lib/`、
  `libmali-rockchip-g610/`、`librga/`、`rknn-toolkit-lite2/`、`rockchip-mpp/`
- `patches/attic-s3-connect-timeout.patch`

**hostName 功能判断映射（作者→我的）**：autostart/packages `lt-hp-omen→ml-laptop`、
mpv `lt-dell-wyse→ml-2700`、smart-check `pve-c3758→taishanpi`、firewall `buyvm→google`、
uni-api `v-ps-sea→tencent`。

**rsync-server**：`primaryServer` colocrossing→greencloud。

**backup.nix**：补回被上游覆盖删掉的 `sftpEndpoint` option（默认 opi5p.zhyi.cc）。

**保留删除（无引用）**：`freshrss.nix`、`linkwarden.nix`、`overlays/49/53/54`、
`patches/bazarr-*`、`pkgs/taishanpi-kernel/*`、`tools/knowledge-chain/`、`tools/memos/`、
`tools/subvol-migrate.sh`、`generate-rockchip-kernel-config.sh`。

**说明**：作者域名/用户名/路径已全清（`lantian.pub`/`xuyh0120.win`/`ltn.pw`/
`dc=lantian`/`/home/lantian`/`lantian1998` 全树 0 残留，排除模块命名空间前缀）。

### 第二轮核验（t5 验证后）发现并修复

1. **用户名回归**：`glauthUsers.lantian` / `users.users.lantian` / `user = "lantian"`
   等 16+ 处（kernel/smtp/podman/xorg/pipewire/network-manager/adb/gui-apps/libvirt/
   obs-studio/ups/location-options/acme/asterisk/matrix-synapse）t3 未覆盖，已全部
   改回 `zhyi`。含 location-options.nix 的 htpasswd basic-auth 用户名 `lantian:`→`zhyi:`。
2. **taishanpi-kernel 被删仍被引用**：`pkgs/taishanpi-kernel/{patch-st7701.py,
   rk3566-taishanpi-dsi31-overlay.dts, st7701-panel-lckfb-31inch.patch}` 被覆盖删掉但
   `nixos/hardware/taishanpi/default.nix:79,174` 仍引用 → 已从 HEAD 恢复。
3. **作者主机名子串域名残留**：`attic.colocrossing.zhyi.cc`（attic-watch-store/hydra/
   public-sites）、`sftp.lt-home-vm.ltnet.zhyi.cc`（ssh-harden）待映射（见 t6）。
4. **源码文件 `.rs` 域名回归**：`pkgs/e164-verify/src/naptr.rs` 的 `lantian.dn42`
   （测试函数名 + 3 处字符串）覆盖后回归，HEAD 已是 `zhyi.dn42`，已修复。
   教训：**替换范围必须含 `.rs`/`.c`/`.h`/`.lua` 等源码文件**（见 §3）。
5. **overlay 49/53/54 恢复**：`49-linphone-zxing2.nix`（linphone 需 zxing-cpp-2）、
   `53-pve-storage-lvm.nix`、`54-pve-container.nix`（pve-5700u 用 pve-manager/
   proxmox-ve）被覆盖删掉但对应功能仍在使用 → 已从 HEAD 恢复。
   教训：判断「被删文件是否需恢复」时，**功能仍在使用的私有 overlay 也要恢复**，
   不能只凭「是否被 import」判断（overlay 是隐式全局生效，无 import 引用）。
6. **私有基础设施保持私有语义**（用户指出「日志/备份没法复刻」）：
   - `nixos/server-components/logging.nix` → 恢复 HEAD 的 **Axiom** 版（filebeat7 +
     api.axiom.co + filebeat-axiom-token secret），不是上游 Humio（filebeat8 +
     cloud.community.humio.com）。结构对齐上游，值私有。
   - `nixos/minimal-components/backup/common.nix` → SFTP 到 `opi5p`/`google`
     （`config.lantian.backup.sftpEndpoint`），不是上游 storagebox。私有 secrets
     `filebeat-axiom-token`/`uni-api-admin-api-key` 在 nixos-secrets 已存在。
   教训：**私有基础设施（日志/备份/自组网/UniAPI）被覆盖后，光做域名替换不够，
   它们依赖私有 secrets 与拓扑，必须保持私有语义**。见 §9 J 类。
7. **firewall 结构对齐**：上游把 `minimal-components/firewall` 拆成目录
   `firewall/{default,arp,common,inet-rules}.nix`，HEAD 是扁平 `firewall.nix`。
   覆盖后两者并存导致 minimal.nix readDir 重复加载冲突 → 删扁平 `firewall.nix`
   对齐上游目录结构（all in 上游，不恢复 HEAD 旧结构）。

### 第四轮核验（t8，域名+用户名全量）

- **attic 常量恢复**：`helpers/constants/nix.nix` 被覆盖删掉 `attic = { cacheName/
  url/publicKey }` 及 SJTU/USTC/TUNA 国内镜像 substituters，但
  `hosts/macmini/darwin-configuration.nix:31,33` 仍引用 `LT.nix.attic.url/publicKey`
  → 恢复 HEAD（私有 attic 缓存 + 国内镜像加速，属私有基础设施 J 类）。
  cacheName `lantian` 是 attic 缓存名（URL 已 zhyi.xin），非用户名，保留。
- **nginx Server header**：`nginx.nix:102` `Server: lantian/` → `Server: zhyi/`（HEAD 值）。
- **Matrix admin localpart**：`mautrix-gmessages.nix:19` `@lantian:zhyi.xin` →
  `@zhyi:zhyi.xin`（glauth 用户是 zhyi）。教训：**`@<user>:` 的 Matrix/DN 用户
  localpart 也是用户名形态，要一并查**（§9 B 类补一条）。

### 第五轮核验（t12，K 类逐文件 diff 审计 block3）

> 这是真正的防漏核验（§9 K 节）：对每个「工作树 vs 上游」差异文件逐一 `diff`，
> 发现「私有逻辑被覆盖丢失」和「结构脱轨」。之前的 grep 只查域名/用户名，
> 查不出这些。**本轮发现并修复了最严重的私有基础设施回归**。

- **`helpers/host-options.nix`（最高优先，eval 必挂）**：HEAD 的私有 options
  （`nixBuilder`、`ssh.ed25519Fingerprints.{sha1,sha256}`、`ltnet.tcpTransportDomain/
  tcpTransportPeers`、私有 LTNET 网段 `fdd8:1938:4e88`、`wg-zhyi`）被上游版覆盖删除，
  但 4/9/15 台 hosts 仍设置、`dns/host-recs.nix:273`（缺则 throw）、`wg-mesh-wstunnel`
  仍引用 → 恢复 HEAD。同时全树统一私有命名：`fdbc:f9dc:67ad→fdd8:1938:4e88`、
  `wg-lantian→wg-zhyi`、`WGLanTian→WGZhyi`（生产网段是 fdd8）。
- **`home/client-apps/ai-coding/default.nix`**：HEAD 的 codexWrapper/claude-code/
  codex/deepseek-harness 全套被上游覆盖成仅 pi-coding-agent（B 类文档记录保留）→ 恢复。
- **`nixos/common-apps/nginx/oauth2-proxy.nix`**：HEAD 单 sops 文件结构被上游改为
  dex 双 secret+template（B 类记录保留）→ 恢复。
- **私有 CN 逻辑**：`networking.nix`（CN 国内 DNS）、`smtp.nix`（sops 排序）、
  `powerdns-recursor.nix`（CN resolvers+NTA）、`kernel.nix`（io 调度器 udev）→ 恢复。

**教训**：`all in 上游` 指「公共逻辑/结构对齐上游」，但**私有基础设施
（日志/备份/网段/UniAPI/CN 加速/自组网）必须保留私有语义**——它们依赖私有 secrets
与拓扑，覆盖后光做域名替换不够，必须逐文件 `diff <(git show HEAD:文件) 文件` 核对。

### 第六轮核验（t11，J 类私有基础设施）

- **ssh-harden.nix 恢复**：工作树是上游版（`User lantian`、缺 `/var/empty` volatile-root
  加固、含上游 storagebox knownHosts 段），恢复 HEAD 私有版（`User zhyi`、`/var/empty`
  ExecStartPre、sftp.opi5p 私有映射）。
- **zerotier 网络 ID**：`nixos/minimal-components/zerotier/default.nix` 指向作者 ZT 网络
  `91450bd87b000001`/ztje7axwd2，改回私有 `466270de75000001`/zttalxbxtu（14 台主机持
  私有 node ID + 私有 LTNET IPv6 前缀 fdd8，拓扑自洽）。

### 第七轮核验（t13，K 审计 block1）+（t14，K 审计 block2）

> t13 审计 optional-apps block1 发现 12 个「私有逻辑被覆盖丢失」文件 + 全局 DN42 身份回归；
> t14 审计 block2 50 文件全部通过（合法硬变量/私有保留）。

- **DN42 身份回归（全局，跨 17 文件）**：权威 ASN `4242423712` / ULA 子网 `:3712`
  （docs/human/network/dn42.md + dns/domains/zhyi.dn42.nix 权威）被覆盖成作者 `4242422547`/
  `:2547` → 已全量替换回 3712（`4242422547→4242423712`、`:2547→:3712`）。
- **12 个私有服务文件恢复 HEAD**：acme/base-domains（zhyi.xin 证书去重+moliy.site 基础域）、
  acme/default（gcore DNS provider + nginx reload postRun 等私有）、asf（私有 vhost + net=host）、
  attic（vaults3.zhyi.xin 私有 S3）、bitmagnet（TMDB placeholder 守卫）、calibre-cops（私有健康
  检查 + Magic Flash）、dex（5 个私有 OAuth client）、elasticsearch（es-ingest vhost）、
  grafana（dashboards + 中文 UI）、gitea（oauth2 自动注册 + vaults3 MINIO）、hydra（builder
  SSH key + GIT_SSH_COMMAND + attic repush）、iyuuplus（git-init 兜底）。
- **DN42 电话前缀统一**：`asterisk/extensions.nix` 入站 `04243712`（HEAD 正确）、
  `asterisk/dialplan/default.nix` 出站 `dn42Prefix` 被覆盖成 `+04242547` → 统一为
  `+04243712`（extensions 与 dialplan 需一致，否则 DN42 电话拨号不匹配）。
- **bird/config/common.nix**：`LT_ROA_*`/`LT_FLAP_*` 里的 `, 2547` 漏替换 → 恢复 HEAD
  `3712`（grep 2547 要多形态查：`:2547`/`4242422547`/`, 2547`/`04242547`）。
- **分区域 DNS 保留（用户明确要求）**：`nixos/server-apps/coredns.nix`、
  `nixos/common-apps/coredns.nix`、`nixos/server-apps/powerdns-recursor.nix`、
  `helpers/constants/zones.nix` 恢复 HEAD 私有分区域版：
  - coredns 用我的 DN42 zone（zhyi.dn42、172.20.46.x 反解、Magic Flash VoLTE）
  - 国内 AliDNS（tls://223.5.5.5）分区域转发
  - powerdns-recursor 用我的 publicResolvers + zhyi.cc/xin NTA
  - zones.nix 的 Ltnet 反解区（18.198/19.198 in-addr、zhyi.dn42）
  不含上游 OpenNIC/NeoNetwork/lantian.eu.org 等作者 zone。

### 第八轮迁移（追上游机制演进，用户拍板全部迁移）

用户点破：「我守着的私有偏移，多数是没跟进上游演进」。本轮把旧写法/旧字段迁移到上游新机制（用户 4 项决策全部选「迁移到上游」）：

1. **host-options 对齐上游**：删 `nixBuilder`/`ed25519Fingerprints`/`tcpTransport`/`wg-zhyi` 私有 option，改用上游：nix-distributed(cpuThreads)/SSHFP 运行时计算(wg-lantian)。保留私有 ULA `fdd8:1938:4e88`（我的 DN42 身份）。
2. **hosts 迁移**：ml-builder/opi5p 删 nixBuilder 字段+assertion，改 `cpuThreads`+`nix-builder` tag；15 台 host 删 `ssh.ed25519Fingerprints` 块（上游弃用，改 runtime）；ml-builder 删 `nix-distributed.excludeHosts` 私有 option。
3. **wg 改名**：`wg-zhyi→wg-lantian`、`WGZhyi→WGLanTian`（纯改名，ports/host-options/firewall/qbittorrent×3 同步）。
4. **删 wg-mesh-wstunnel**：私有 WSS 隧道删除，改上游 wg-mesh 直连 UDP+Endpoint。
5. **SSHFP runtime**：dns/host-recs 弃用离线预计算，改上游 `SSHFP_ED25519_SHA1/SHA256`（record-handlers 用 `runCommandLocal` 现算）；record-handlers 补 SSHFP_RSA/ED25519 handler。
6. **OpenNIC 补回**：zones.nix 补 NeoNetwork/OpenNIC zone，coredns 补 OpenNIC Authoritative 段（保留 DN42 私有段）。
7. **nix-distributed**：buildMachine hostName 域改 `zhyi.cc`（主机域），sshKeyPath `/home/zhyi`。

保留私有（用户划定）：日志 Axiom、备份 opi5p、DN42（fdd8 ULA+ASN 3712）、attic、分区域 DNS、networking CN DNS、zerotier 网络ID。

### 第九轮（作者 attic + Lan Tian 显示名 + ASN）

- **加作者 attic 到 substituters**：`helpers/constants/nix.nix` 在自家 attic 后加
  `authorAttic`（`inputs.nur-xddxdd.meta.atticUrl`=`https://attic.xuyh0120.win/lantian`、
  `meta.atticPublicKey`）。t28 核实：xddxdd/nur-packages 用 flake `meta` 输出（非 `_meta`），
  本项目走 `inputs.nur-xddxdd` 直接输入 → `.meta.` 正确（非 NUR 聚合的 `._meta.`）。
- **Lan Tian 显示名→Magic Flash**（11 处 .nix + 3 处非 .nix：pyison/template.html×2、
  open5gs/mme.yaml）。教训：**grep 不能只限 .nix**，assets/.html/.yaml/.rs 都要扫。
- **ASN 回归修复**：`nixos/server-components/dn42/default.nix` `myASNAbbr = 2547`→`3712`。
- **username 残留修复**：mcp-servers CALDAV_USERNAME、picoclaw per-user 路径、
  AGENTS.md 标题 → zhyi/Zhyi。

### 第十轮（移除别名 + 主机引用直换 + host 字段核验）

- **移除别名机制**：`helpers/fn/hosts.nix` 恢复上游原版（无别名），公共模块所有
  `LT.hosts.<作者主机>` 引用直接替换成真实主机（11 处/7 文件：colocrossing→greencloud、
  pve-epyc→pve-5700u、buyvm→google、lt-home-vm→rock5c、zgocloud→volcengine、
  bwg-lax→hostdare 等）。host-recs GEO handler `k=="zgocloud"`→`k=="volcengine"`。
  教训：**别名是绕开对齐，应直接替换引用**。
- **host 字段核验（t30）**：17 台 host 必备字段（index/tags/cpuThreads/city）齐全，
  aarch64 有 system。**google/hostdare/volcengine 公网 VPS 仅 public.IPv4 无 IPv6**——
  因设备物理无 IPv6（GCP/JP/国内 VPS 不提供），非配置缺失，保留。interconnect
  IPv4-only、dn42 仅 tag 路由器有 IPv4，均合理。

### 第十一轮（域名统一为单一 zhyi.xin，用户拍板）

用户拍板「单一域名避免混乱，主域名 zhyi.xin」：`zhyi.cc` 和 `moliy.site` 全部并入
`zhyi.xin`。约 123 文件批量替换。DNS 合并：删 `dns/domains/zhyi.cc.nix`、`moliy.site.nix`
并入 `zhyi.xin.nix`（含全部 internalServices + AhaSend MX/TXT + LTNet/DN42 +
enableWildcard=true，apex A @ 用 volcengine）。证书 baseDomains=[zhyi.xin] 三域合一。
hostname 默认 `${config.name}.zhyi.xin`。保留 `zhyi.dn42`/`zhyi.neo`（DN42/NeoNetwork
层级域）。批量替换后修复了 vhosts/oauth2-proxy/autoconfig/public-sites/navdash 等的
重复键/过滤。

**教训**：域名体系统一为单一 zhyi.xin 后，后续新增服务一律用 `<svc>.zhyi.xin`，
主机地址用 `<host>.zhyi.xin`，不再有 zhyi.cc/moliy.site 双域。











### 第三轮核验（t6，作者主机名子串域名引用）已修复

> 目标：`grep -rnE '\.(colocrossing|bwg-lax|buyvm|alice|terrahost|zgocloud|v-ps-sea|lt-home-vm|lt-hp-omen|lt-dell-wyse|pve-epyc|oracle|azure|lt-home-rdp|lt-home-router|lt-rpi4|lt-home-lte|lt-dell-wyse-thin|pve-c3758|pve-hp-z220-sff|virmach-ny1g|virmach-ny6g)[a-z0-9.-]*\.zhyi'` → 代码树 0 残留。

| 位置 | 原值 | 现值 | 依据 |
| --- | --- | --- | --- |
| `helpers/constants/public-sites.nix:43` | `attic.colocrossing.zhyi.cc` | `attic.greencloud.zhyi.cc` | colocrossing→greencloud（§2.2） |
| `nixos/optional-apps/attic-watch-store.nix:19` | `https://attic.colocrossing.zhyi.cc` | `https://attic.greencloud.zhyi.cc` | 同上 |
| `nixos/optional-apps/hydra/default.nix:89` | `https://attic.colocrossing.zhyi.cc` | `https://attic.greencloud.zhyi.cc` | 同上 |
| `nixos/minimal-components/ssh-harden.nix:143-144` | `sftp.lt-home-vm.ltnet.zhyi.cc` | `sftp.opi5p.ltnet.zhyi.cc` | SFTP 实载 opi5p（见 fleet-service-chain.md） |
| `nixos/minimal-components/ssh-harden.nix:165` | `lt-home-rdp.ltnet.zhyi.cc` | `ml-builder.ltnet.zhyi.cc` | lt-home-rdp→ml-builder（§2.1） |
| `nixos/optional-apps/prometheus/scrape-configs.nix:271` | `sakura-llm.lt-home-rdp.zhyi.cc` | `sakura-llm.ml-builder.zhyi.cc` | lt-home-rdp→ml-builder（§2.1） |
| `dns/common/records.nix:219` | `SIPTarget = "v-ps-sea"` | `SIPTarget = "tencent"` | v-ps-sea→tencent（§2.2） |

**保留不动**（别名机制解析，非域名子串）：
- `LT.hosts.pve-epyc`（vhost-hydra-proxy）、`LT.hosts.buyvm`（netns-tnl-buyvm）、
  `LT.hosts.zgocloud`（dae）、`LT.hosts."colocrossing"`（vhosts/bird）→ hosts.nix 别名表。
- `pkgs/e164-verify/src/naptr.rs` 的 `v-ps-sea.zhyi.dn42` → Rust 解析器**测试夹具**，
  非活动配置，保留原样（不参与实际路由）。

### 第九轮核验（t24，Lan Tian/全名形态残留）已修复

> 规则：`Lantian→Magic Flash`（全名显示形态）、`lantian→zhyi`（小写用户名）、
> `lantian1998→zhyiheihei`。扫描 `Lan Tian|LanTian|lantian|Lantian|@lantian|dc=lantian`
> 全树（排除 ../nixos-config-exam、docs/、helpers/fn/hosts.nix 别名表、模块命名空间
> 前缀 `lantian.*`/`config.lantian`/NUR `lantianCustomized`/常量 `WGLanTian`/`wg-lantian`/
> Lua 函数 `lantian_nginx`/`lantian_whois`/attic 缓存名 `lantian`）。

修复 3 处真实用户名/全名残留（→zhyi/Zhyi）：

| 位置 | 原值 | 现值 | 依据 |
| --- | --- | --- | --- |
| `nixos/client-apps/mcp-servers.nix:175` | `CALDAV_USERNAME=lantian` | `CALDAV_USERNAME=zhyi` | 系统用户 zhyi（users.nix）；HEAD 即 zhyi，被覆盖回归 |
| `nixos/optional-apps/picoclaw.nix:55` | `/etc/profiles/per-user/lantian/` | `/etc/profiles/per-user/zhyi/` | picoclaw service `User="zhyi"`，profile 路径必须随用户名 |
| `AGENTS.md:1` | `# Lan Tian's NixOS Configuration` | `# Zhyi's NixOS Configuration` | 全名显示形态（HEAD 是 Zhyi's，覆盖回归） |

**保留不动**（非用户名/基础设施标识，按 §1/§3/D1/§8）：
- `config.lantian.*`/`lantian.nginxVhosts`/`lantian.netns`/`lantian.backup` 等**模块命名空间前缀**（D1 绝不改）。
- `nur-xddxdd.lantianCustomized.*`（NUR 包名，外部）。
- `WGLanTian`/`wg-lantian`（常量名，t21 已对齐上游）。
- `lantian_nginx`/`lantian_whois`/`lantian-prepend`/`lantian_arp`（Lua/nft 内部函数/表名，上游同构）。
- attic 缓存名 `lantian`（`cacheName`/`publicKey`/`url …/lantian`/`attic push lantian`）：是 attic 缓存+签名密钥标识，跨 secrets 一致，**不是用户名**，保留。
- `README.md:4` 的 "Lan Tian's"（上游作者归属声明，非本仓库身份，保留）。

**补充核验（t24 追加，含 assets/非 .nix 文件）**：新增修复 3 处显示名形态（`Lan Tian→Magic Flash`）：

| 位置 | 原值 | 现值 |
| --- | --- | --- |
| `nixos/optional-apps/pyison/assets/template.html:9` | `<title>… - Lan Tian @ Posts</title>` | `- Magic Flash @ Posts` |
| `nixos/optional-apps/pyison/assets/template.html:19` | `<a …>Lan Tian @ Posts</a>` | `Magic Flash @ Posts` |
| `nixos/optional-apps/open5gs/config/mme.yaml:57` | `full: Lan Tian Mobile` | `full: Magic Flash Mobile` |

**保留不动（功能标识/上游同构，非显示名）**：
- `template.html` 的 `class="lantian"`/`id="lantian-navbar"`（CSS/HTML 标识，非显示文本）。
- `mme.yaml:58` `short: LTMobile`（LTE 运营商短名缩写，同上游）。
- `SERVER_SOFTWARE lantian`（nginx banner，功能标识）。
- `BIRDLG_TELEGRAM_BOT_NAME=lantian_lg_bot`（telegram bot 名）。
- `radicle node.alias = "lantian-${hostName}"`（git 节点别名，功能标识）。
- `imapfilter-lantian`/`imapfilter/lantian.lua`/`attic login … lantian`/`attic watch-store lantian`（secrets/缓存功能标识，改会破坏 secret 解析）。
- 无 `@lantian:`/`lantian1998`/`dc=lantian` 残留。

### 第十轮迁移（t29，移除别名机制，替换作者主机引用）

用户指出：`helpers/fn/hosts.nix` 的「作者主机名→我的主机名」别名是绕开对齐的做法，不需要。hosts.nix 已恢复上游原版（无别名），公共模块所有 `LT.hosts.<author>` 引用直接替换成我的真实主机名。

替换 11 处（7 个文件）：

| 文件 | 作者引用 | 现值 |
| --- | --- | --- |
| `nixos/common-apps/nginx/vhosts.nix:40,47` | `LT.hosts."colocrossing"` | `LT.hosts."greencloud"`（Plausible index + Waline proxyPass） |
| `nixos/common-apps/nginx/vhost-hydra-proxy.nix:7` | `LT.hosts.pve-epyc` | `LT.hosts.pve-5700u` |
| `nixos/server-apps/bird/config/sys.nix:351` | `LT.hosts."colocrossing"` | `LT.hosts."greencloud"` |
| `nixos/optional-apps/netns-tnl-buyvm.nix:13` | `LT.hosts.buyvm.index` | `LT.hosts.google.index` |
| `nixos/optional-apps/zerotierone-controller.nix:3` | `LT.hosts.lt-home-vm` | `LT.hosts.rock5c` |
| `nixos/optional-apps/dae.nix:64` | `LT.hosts.zgocloud` | `LT.hosts.volcengine` |
| `nixos/client-apps/v2ray.nix:53,88` | `LT.publicIPv4For "bwg-lax"` | `LT.publicIPv4For "hostdare"` |
| `dns/common/host-recs.nix:26-27` | `LT.hosts ? buyvm` / `virtono = LT.hosts."buyvm"` | `LT.hosts ? google` / `virtono = LT.hosts."google"` |

**保留不动**（非 LT.hosts 引用/功能标识）：
- dae `node { zgocloud }` / `filter: name(zgocloud)`（dae 路由节点标签，非主机引用）。
- `netns/tnl-buyvm`（网络命名空间名）、`tnl-buyvm`（netns 名）。
- sublinkpro jq `LinkName=="colocrossing"`（清理旧节点记录）。
- host-recs `k == "zgocloud"`（geodns 国别标记）。

验证：`grep -rnE 'LT\.hosts\.(colocrossing|buyvm|…) | LT\.hosts\."(…)" | publicIPv4For "(…)"'` 在代码树 0 残留（仅 docs 历史记录）。

### 第十一轮迁移（t31，域名统一为 zhyi.xin）

用户拍板：避免 zhyi.cc/zhyi.xin 双域混乱，主域名 **zhyi.xin**，zhyi.cc 和 moliy.site 全部并入。

**全局替换**（`zhyi.cc`→`zhyi.xin`、`moliy.site`→并入 zhyi.xin）：全树 .nix/.rs/.py/.yaml/.toml 约 123 个文件批量替换。保留 `zhyi.dn42`/`zhyi.neo`（特殊层级域独立）及 2547/3712 ASN 不变。

**DNS 合并**：
- 删 `dns/domains/zhyi.cc.nix`、`dns/domains/moliy.site.nix`（并入 `zhyi.xin.nix`）。
- `zhyi.xin.nix` 承载全部：保留原 xin 的 internalServices + 合并 zhyi.cc 独有的 `um/lg/rsync-ci/halo.volcengine/searx.tencent/metapi.tencent/hub.tencent/prometheus.tencent/n8n-bridge.greencloud`；顶层 records 合并 AhaSend MX/TXT、LTNet/DN42、home-ddns/wg-home IGNORE、enableWildcard=true（来自 zhyi.cc）。apex A @ 用 volcengine（zhyi.xin 原有）。
- `dns/default.nix` import 删两文件，留 zhyi.xin/dn42-reverse/tel.dn42。

**证书**：`acme/base-domains.nix` `baseDomains=[zhyi.xin]`（原 zhyi.xin/zhyi.cc/moliy.site 三域合并为一），hostSubdomains 用 `${n}.zhyi.xin`。

**关键文件修复**（bulk 替换造成的重复键/重复串）：
- `vhosts.nix` 去重 vhost 键（zhyi.xin/www 各仅 1 个，删 zhyi.cc 键）。
- `oauth2-proxy.nix` whitelist-domain 去重（zhyi.xin/*.zhyi.xin）。
- `autoconfig.nix` domains 去重为 `[zhyi.xin]`。
- `public-sites.nix` 去重（autoconfig/zhyi.xin/lab/www 等，删 zhyi.cc/moliy.site 项）。
- `powerdns-recursor.nix` `[m-team.cc zhyi.xin]` 去重。
- `homepage.nix` pattern/过滤去重（去 moliy.site）。
- `hosts/rock5c/app-edge.nix` sslCertificate 统一 `lets-encrypt-zhyi.xin`。
- `hosts/rock5c/opi5p/ml-builder/configuration.nix`、`frigate-rockchip.nix` proxyBypass/NO_PROXY 去重 `.zhyi.xin,.zhyi.xin`。
- `navdash.nix` pattern 去 moliy.site（已统一 zhyi.xin）。

验证：全树 `zhyi.cc`/`moliy.site` 0 残留（仅 docs 历史记录）；`zhyi.dn42`/`zhyi.neo` 保留（20 文件）。

### 第十二轮（t4，NeoNetwork 置空）

用户明确「我没有 NeoNetwork，直接置空」。NeoNetwork 前缀 `fd10:127:10`（NEO_AS=4201270010）全树移除，保留 DN42 `fdd8:1938:4e88`。

改动文件（10 个）：
- `helpers/host-options.nix`：`neonetwork` option 的 IPv4/IPv6/IPv6Prefix 默认从 `10.127.10.${index}`/`fd10:127:10:${index}::1`/`fd10:127:10:${index}` 改为 `null`（type 改 `nullOr str`），使所有 `!= null` 守卫禁用 NeoNetwork 代码路径。
- `nixos/server-apps/bird/config/sys.nix`：`commonStaticRoutesIPv6` 删 `fd10:127:10::/48`；`LTNET_IPv6` 删 `fd10:127:10::/48+`。
- `nixos/server-apps/bird/config/dn42.nix`：`dn42_export_filter_ipv6` 删 `if net ~ [ fd10:127:10::/48+ ] then bgp_path.prepend(${NEO_AS});`。
- `nixos/server-apps/powerdns-recursor.nix`：`announcedIPv6` 删 `fd10:127:10:2547::53`。
- `nixos/minimal-apps/nginx-proxy.nix`：`announcedIPv6` 删 `fd10:127:10:3712::43`。
- `nixos/optional-apps/vlmcsd.nix`：`announcedIPv6` 删 `fd10:127:10:3712::1688`。
- `nixos/optional-apps/glauth.nix`：`announcedIPv6` 删 `fd10:127:10:3712::389`。
- `nixos/server-components/route-chain.nix`：`routes` 删 `fd10:127:10:6d61:6e6f:7361:6261::/120`。
- `nixos/common-apps/nginx/nginx.nix`：`map $server_addr $gopher_addr` 删 `"~*^fd10:127:10:" gopher.zhyi.neo;`。
- `flake.nix`：`dn42-geofeed` `allowedPrefixes` 删 `"fd10:127:10:"`。

验证：全树 `fd10:127:10` 0 残留（仅 docs 历史记录）；DN42 `fdd8:1938:4e88` 保留（55 处）。所有改动文件 `nix-instantiate --parse` 通过。

### 第三轮核查（t4，清理 zhyi.neo 域名残留）

> t1 全量残留扫描发现 7 处 `zhyi.neo`（NeoNetwork TLD）残留——它们是上游 `lantian.neo`
> 的域名替换结果，但用户无 NeoNetwork，应删除而非替换。本轮删除全部 7 处 + zones.nix
> NeoNetwork zone 定义。

改动文件（6 个）：
- `nixos/common-apps/nginx/vhosts.nix`：删 `"zhyi.neo" = addConfLantianPub {...}` 整个 vhost 块；gopher/gemini serverAliases 删 `"gopher.zhyi.neo"`/`"gemini.zhyi.neo"` 条目。
- `nixos/common-apps/nginx/nginx.nix`：`map $server_addr $gopher_addr` 删 `"~*^10\.127\." gopher.zhyi.neo;` 行。
- `nixos/common-apps/nginx/whois-server.nix`：serverAliases 删 `"whois.zhyi.neo"` 条目。
- `nixos/optional-apps/maddy.nix`：localDomains 删 `"zhyi.neo"` 条目。
- `nixos/optional-apps/bird-lg-go.nix`：serverAliases 删 `"lg.zhyi.neo"`（留空 `[ ]`）。
- `helpers/constants/zones.nix`：删 `NeoNetwork = [ "neo" ]` 定义及注释。

**保留不动**（NeoNetwork 基础设施，§12 已置空，与上游逐字一致，非域名引用）：
- `neonetwork` option（host-options.nix，默认 null，`!= null` 守卫禁用代码路径）。
- `LT.constants.neonetwork.IPv4/IPv6`（networks.nix，10.127.0.0/16 + fd10:127::/32）。
- firewall `NEONETWORK_IPV4/IPV6` set、bird `NEONETWORK_NET_*`、zerotierone-controller/matrix-synapse 的 `neonetwork.IPv4/IPv6` 拼接、gitea `/backup/neonetwork-registry/`。
- `dn42/default.nix` 的 `network` enum `"neo"`、`interface-prefixes.nix` DN42 前缀 `"neo"`（上游同构，模块结构）。
- IPv4 `10.127.0.0/16` 11 处（bird sys.nix/dn42.nix、powerdns-recursor、nginx-proxy、vlmcsd、glauth、flake.nix、networks.nix）——与上游逐字一致，§12 只删了 IPv6 `fd10:127:10`，IPv4 保留（NeoNetwork 置空后这些 IPv4 引用因 option 为 null 而失效，不参与实际路由）。

验证：全树 `zhyi.neo` 0 残留（仅 docs 历史记录）；`zhyi.dn42` 保留（59 处）；6 个改动文件 `nix-instantiate --parse` 通过。

---

## 9. 完整对齐核对清单（每轮核验逐条过，防止漏项）

> 这是**防漏清单**：覆盖对齐后，必须逐条执行 grep + 检查，缺一不可。
> 每轮核验（修复后再核验）都从本节重新过一遍。所有 grep 在
> `nixos/`、`home/`、`helpers/`、`dns/`、`hosts/`、`flake-modules/`、`pkgs/`、
> `overlays/` 全树执行（排除 `../nixos-config-exam`、`docs/archive`、`helpers/fn/hosts.nix`）。

### A. 域名替换检查（§1）

| # | 检查 | 命令（应无命中或已映射） |
| --- | --- | --- |
| A1 | 作者公开域 | `grep -rnE 'lantian\.pub'` → 应 0（排除 `helpers/fn/hosts.nix`） |
| A2 | 作者私有域 | `grep -rnE 'xuyh0120\.win'` → 应 0 |
| A3 | 作者附属域 | `grep -rnE 'ltn\.pw'` → 应 0 |
| A4 | DN42/Neo 域 | `grep -rnE 'lantian\.dn42|lantian\.neo'` → 应 0 |
| A5 | **域名内嵌主机名子串** | `grep -rnE '\.(colocrossing|bwg-lax|buyvm|alice|terrahost|zgocloud|v-ps-sea|lt-home-vm|lt-hp-omen|lt-dell-wyse|pve-epyc|oracle|azure)[a-z0-9.-]*\.zhyi\.xin'` → 应 0（如 `attic.colocrossing.zhyi.xin` 要改 `attic.greencloud.zhyi.xin`） |
| A6 | LDAP 基 DN | `grep -rnE 'dc=lantian'` → 应 0（目标 `dc=zhyi,dc=xin`） |
| A7 | **旧双域残留** | `grep -rnE 'zhyi\.cc|moliy\.site'` → 应 0（域名已统一 zhyi.xin，仅 docs 历史记录除外） |
| A8 | **NeoNetwork 置空** | `grep -rnE 'fd10:127:10|zhyi\.neo|NeoNetwork'` → 应 0（用户无 NeoNetwork，`fd10:127:10` 前缀 + `zhyi.neo` 域名 + zones.nix NeoNetwork 定义全部移除；仅 docs 历史记录除外） |

### B. 用户名/路径检查（§3）

- [ ] B1 `grep -rnE 'glauthUsers\.lantian'` → 应 0（目标 `glauthUsers.zhyi`；secrets 只认 zhyi 键，认不到会 eval 失败）
- [ ] B2 `grep -rnE 'users\.users\.lantian'` → 应 0（目标 `users.users.zhyi`）
- [ ] B3 `grep -rnE '(user|username|group|User|Group)\s*=\s*"lantian"'` → 应 0（含 `lib.mkForce "lantian"`）
- [ ] B4 `grep -rnE 'htpasswd|lantian:'`（basic-auth 用户名）→ 应 0（`lantian:`→`zhyi:`）
- [ ] B5 `grep -rnE '/home/lantian'` → 应 0（→`/home/zhyi`）
- [ ] B6 `grep -rnE 'profileNames = \["lantian"\]|"valid users" = "lantian"|DOWNLOADER = "lantian"|USERNAME = "lantian"|submissionNick = "lantian"|wsrep_cluster_name = "lantian"'` → 应 0（目标 `wsrep_cluster_name = "zhyi"`）
- [ ] B7 `grep -rnE '\bLantian\b|lantian1998'` → 应 0（→MagicFlash/zhyiheihei）
- [ ] B8 **显示名/全名形态**：`grep -rnE 'Lan Tian|LanTian'` → 应 0（→Magic Flash；含 assets/.html/.yaml/.rs 等非 .nix 文件）
- [ ] B9 **@user localpart**：`grep -rnE '@lantian:'` → 应 0（Matrix/DN 用户 localpart，→@zhyi:）

### C. 作者主机引用检查（§2/§4）

- [ ] C1 `LT.hosts.<author>`（如 `LT.hosts."colocrossing"`）→ **直接替换为真实主机**（`LT.hosts."greencloud"`，无别名，见 §2.3）
- [ ] C2 `hostName == "author"` 功能判断 → 映射为我的主机（`lt-hp-omen→ml-laptop` 等，见 §2）
- [ ] C3 `primaryServer = "author"` / `sftpEndpoint` / `maintenanceHosts` 裸主机名 → 映射为我的主机
- [ ] C4 `ssh-host <host> <author>.<域>`（SSH config 主机段）→ 映射为我的主机
- [ ] C5 `LT.publicIPv4For "author"` / `LT.publicIPv6For "author"` → 直接替换为真实主机（`LT.publicIPv4For "hostdare"`）

### D. 模块命名空间（绝不能动）

- [ ] D1 保留 `lantian.nginxVhosts`/`lantian.backup`/`lantian.netns`/`lantian.netns.coredns-client`/`lantian.kernel`/`lantian.conf`/`lantian.hostType`/`lantian.qemu`/`lantian.vfio` 等**模块选项前缀**（xddxdd 模块系统约定）。**不要把 prefix `lantian` 当用户名替换**。

### E. 被删文件恢复检查（§5）

- [ ] E1 所有 `hosts/*/` import 的本地路径都存在（`for f in $(git ls-files '*.nix'); do grep -oE '\./\./\./[a-zA-Z0-9/_.-]+' "$f" | 逐个 [ -e ]`）
- [ ] E2 `flake.nix` 引用的 `pkgs/*` 目录都在（`grep -oE '\./pkgs/[a-z0-9-]+' flake.nix`）
- [ ] E3 被删文件若被 `nixos/hardware/*/default.nix` 等仍引用 → 从 HEAD 恢复（taishanpi-kernel 踩坑例）
- [ ] E4 `overlays/` 被删的 overlay 若被 flake/pkgs 引用 → 恢复
- [ ] E5 恢复的文件里再做 A/B 替换检查（恢复源是 HEAD，可能不含作者域名，但要复查）

### F. dns 单一域结构（用户拍板统一 zhyi.xin）

- [ ] F1 `dns/domains/` 应为 `zhyi.xin.nix`/`zhyi.dn42.nix`/`dn42-reverse.nix`/`tel.dn42.nix`/`public-reverse.nix`（无 zhyi.cc/moliy.site/lantian.pub）
- [ ] F2 `dns/default.nix` 显式 import 以上文件
- [ ] F3 dns 域文件内 target 引用我的主机（`greencloud.zhyi.xin` 等）

### G. 硬性值保留（不替换）

- [ ] G1 `ssh.ed25519` 公钥、fingerprint、端口 2222 保留
- [ ] G2 sops secrets 只保留引用（`config.sops.secrets.*`、`_secret`），无明文
- [ ] G3 恢复的文件（uni-api 等）保留我的私有逻辑（如 `uni-api-admin-api-key`、`PYTHONPATH msgspec`）
- [ ] G4 **时区**：`nixos/minimal-components/environment.nix` `time.timeZone` 应为 `Asia/Shanghai`（HEAD 原值，我的主机在中国；上游是 America/Los_Angeles，不要对齐）
- [ ] G5 **DN42 ASN**：`4242423712`（docs/human/network/dn42.md 权威），非作者 `4242422547`；ULA 子网 `:3712` 非 `:2547`
- [ ] G6 **作者 attic**：`helpers/constants/nix.nix` 应含 `authorAttic`（`inputs.nur-xddxdd.meta.atticUrl`/`atticPublicKey`）

### H. 最终验证

- [ ] H1 `git diff HEAD` 无明文 secrets
- [ ] H2 提交前 `git status` 分类：D（预期删除）/ M（域名替换）/ ??（新文档）
- [ ] H3 提交信息 conventional commits，中文说明「为什么」

### I. 结构对齐检查（all in 上游）

> 覆盖后公共模块应与上游逐字一致（除域名/用户名/主机映射）。**结构也要对齐**，
> 不能因为「HEAD 旧版长这样」就保留 HEAD 的旧结构。检查方法是 `diff -rq` 对比
> 工作树 vs 上游，找出「同名文件内容不同」和「结构不同」的。

- [ ] I1 `diff -rq . ../nixos-config-exam --exclude=.git --exclude=hosts --exclude=docs`
      应只剩 `.DS_Store`/`.github`/`.gitignore` 等非关键差异；其余应逐字一致（除域名/用户名）
- [ ] I2 同名文件结构一致：如 `firewall` 上游是目录 `firewall/`，工作树必须是目录
      （不能保留 HEAD 的扁平 `firewall.nix`，否则 minimal.nix 的 readDir 会重复加载冲突）
- [ ] I3 `flake-modules/`、`helpers/`、`nixos/minimal-apps/` 等公共模块与上游一致
- [ ] I4 上游拆分的模块，工作树也要拆（`dir/file.nix` 而非 `dir.nix`）

### J. 私有基础设施（不能恢复 HEAD 覆盖，要保留私有语义）

> 这些文件是**私有配置**，被覆盖成上游版后，光做域名/用户名替换不够——它们
> 依赖私有 secrets 与拓扑，必须保持私有语义（但结构仍对齐上游，只改私有值）。
> 核验时逐文件对比 HEAD，确认私有语义未丢。

- [ ] J1 **日志链**：`nixos/server-components/logging.nix` → Axiom（filebeat7 + `api.axiom.co`），
      不是上游 Humio（filebeat8 + cloud.community.humio.com）。HEAD 是 Axiom 版。
- [ ] J2 **备份链**：`nixos/minimal-components/backup/common.nix` → SFTP 到 `opi5p`/`google`，
   `sftpEndpoint` option；不是上游的 storagebox。HEAD 是私有 SFTP 版。
- [ ] J3 **ssh-harden**：私有备份 host + volatile root 加固（HEAD 私有版）。
- [ ] J4 **UniAPI 网关**：`nixos/optional-apps/uni-api.nix` 私有逻辑（`uni-api-admin-api-key`、
      `PYTHONPATH msgspec`、hostdare/tencent 承载），绝不能恢复成上游或丢私有字段。
- [ ] J5 **Axiom 日志 / opi5p 备份 / 自组网**：networking/zerotier/backup 的私有拓扑保留。

### K. 逐文件 diff 审计（核心，防漏根本）

> **前提**：A-I 的 grep 只查「域名/用户名/主机名」字面量，**发现不了「私有逻辑被
> 覆盖丢失」和「结构脱轨」**（踩坑例：logging.nix 被覆盖成上游 Humio、firewall
> 扁平文件 vs 目录结构）。**真正的防漏是逐文件 `diff -rq` 审计**。

- [ ] K1 **先跑全量 diff**：`diff -rq . ../nixos-config-exam --exclude=.git --exclude=hosts --exclude=docs --exclude=.DS_Store`
      列出所有「工作树 vs 上游」不同的文件，存成清单。
- [ ] K2 对每个差异文件 `diff <(git show HEAD:文件) 文件`，判断差异类型：
      - **合法硬变量**（域名/用户名/主机映射）→ 保留，登记
      - **私有基础设施**（logging/backup/ssh-harden/uni-api/自组网）→ 确认私有语义保留
      - **脱轨**（逻辑被覆盖错/结构不齐）→ 修复
- [ ] K3 关注这些「私有 → 公共服务被覆盖」的信号：Humio→Axiom 日志、storagebox→SFTP 备份、
      public-VPS→私有 VPS、公共 DNS→自组网 DNS。
- [ ] K4 结构对齐：上游拆成目录的文件（如 `firewall/`），工作区也应是目录，不能保留 HEAD 扁平文件。
