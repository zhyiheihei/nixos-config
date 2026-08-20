# 2026-08-20 上游对齐审计：ml-laptop（逐文件 diff 差异清单）

> 本文档汇总 t1（桌面环境层）、t2（公共模块层）、t3（hosts 层）三份 diff 的完整输出，
> 形成一份可执行的「逐文件 diff 差异清单」。所有差异均用 `bash diff` 实际跑取真实内容，
> 非凭记忆编写。
>
> **审计基准**：上游 `nixos-config-exam`（作者 lt-hp-omen）的 `hosts/lt-hp-omen/`
> 与公共模块；**用户已拍板**以 `lt-hp-omen` 为对齐基准（非 lt-dell-wyse）。
> 硬性差异（域名 zhyi↔lantian、用户名、IP、UUID、CPU/硬件能力）按规范排除，文中单独标注。

## 一、审计基准

| 项目 | 值 |
| --- | --- |
| 本仓库主机 | `hosts/ml-laptop`（复刻的物理笔记本） |
| 上游基准主机 | `hosts/lt-hp-omen`（作者主力客户端） |
| 本仓库 HEAD | `9591a458`（2026-08-20） |
| 上游 checkout | `../nixos-config-exam` HEAD `930048e5` |
| 映射文档提示 | fork 自身 `docs/human/learning/knowledge-chain-rollout-plan.md` 将
  `ml-laptop ↔ lt-dell-wyse`（作者物理笔记本），`lt-hp-omen ↔ ml-2700`。基准按用户拍板仍取
  lt-hp-omen，但下文中涉及「ml-laptop 是否该有该项」时会用 lt-dell-wyse 做旁证。 |
| 审计时间 | 2026-08-20 |

---

## 一、桌面环境层（t1）

### 1.1 `nixos/client.nix` — 影响桌面（主题启用）

```diff
 { ... }:
 {
+  stylix.autoEnable = true;
+
   imports =
     let
       ls = dir: builtins.map (f: (dir + "/${f}")) (builtins.attrNames (builtins.readDir dir));
```

- **是否影响桌面**：是（决定 stylix 是否自动启用）。
- **差异实质**：repo 在 `client.nix` 顶层硬编码 `stylix.autoEnable = true`；上游没有这一行，
  autoEnable 由 `minimal-components/stylix.nix` 按 `LT.this.hasTag LT.tags.client` 决定。
- **建议**：**需对齐**（统一启用机制）。推荐回到上游写法（去掉 client.nix 硬编码 true，
  由 stylix.nix 按 client tag 决定），与 stylix.nix 的 `autoEnable` 改动配套，见 1.2。

### 1.2 `nixos/minimal-components/stylix.nix` — 桌面主题生成机制（★核心）

```bash
-    polarity = "dark";
-    palette = {
-      generators.semantic = config.stylix.lib.generators.semantic.matugen {
-        scheme = "vibrant";
-        filter = "lanczos3";
-      };
-      mappingFunction = lib.flip lib.pipe [
-        config.stylix.lib.mappings.semantic2base16
-        ({ polarity, palette }:
-          {
-            inherit polarity;
-            palette = palette // {
-              base16 = palette.base16 // { base01 = palette.base16.base00; };
-            };
-          })
-        config.stylix.lib.mappings.base162base24
-      ];
-    };
+    colorGeneration.scheme = "vibrant";
+    colorGeneration.polarity = "dark";

-    autoEnable = LT.this.hasTag LT.tags.client;
+    # Set by the client role directly...
+    autoEnable = lib.mkDefault false;

-    cursor = if LT.this.hasTag LT.tags.client then {
-      package = pkgs.nur-xddxdd.sam-toki-mouse-cursors;
-      name = "STMC_6_1_Genshin_Furina"; size = 32;
-    } else null;
+    cursor = { package = ...; name = "STMC_6_1_Genshin_Furina"; size = 32; };

+    override = let prev = config.stylix.base16.mkSchemeAttrs ...; in { base01 = prev.base00; };
```

- **作用**：桌面主题/配色生成管线（Stlyx）。
- **差异实质**：本仓库用 Stlyx 新 API `colorGeneration.scheme="vibrant"` + `override.base01=base00`
  （配合 `client.nix` 的 `autoEnable=true`），上游用旧 API `palette.generators.semantic.matugen` +
  mappingFunction（base01=base00 内置于 palette）。**cursor 上游仅在 client tag 时启用（否则 null），
  本仓库无条件启用；autoEnable 行为也不同**。
- **注意（跨层关联）**：两侧 flake 输入的 Stlyx 分支不同 —— 本仓库 `make-42/stylix/matugen`
  @ rev `89d5e0b`，上游 `make-42/stylix/step-2-inputmapping-clean-root` @ rev `590e0ba`。
  两分支是不同 Stlyx 构建，matugen 分支带 `colorGeneration` API，step-2 分支带 `palette.semantic`
  API。**桌面配色差异的最可能根源就是 Stlyx 版本分支不一致**。
- **建议**：**需对齐**（最高优先级）。把本仓库 flake 的 stylix 输入对齐到上游
  `step-2-inputmapping-clean-root @ 590e0ba`（`nix flake lock --update-input stylix` 后核对 rev），
  并把 stylix.nix 从 `colorGeneration/override` 改回 `palette.generators.semantic` 写法；
  cursor 是否随 client tag 也需与上游统一（本仓库当前无条件启用）。

### 1.3 `nixos/client-components/kde.nix` / `xorg.nix` — 会话

- **差异**：仅 `user = "zhyi"` vs `"lantian"`（greetd initial_session、autoLogin、
  users.extraGroups）。—— **硬性用户名差异，排除**。
- 其余（plasma6 会话、greetd command、defaultSession 等）两侧一致。**不影响桌面外观差异**。

### 1.4 `nixos/client-components/grub-theme.nix` — 一致（无 diff）

### 1.5 `nixos/client-components/fonts.nix` / `hidpi.nix` — 一致

### 1.6 `home/client-apps/stylix.nix` — 影响主题（firefox/librewolf 配色）

```bash
-        profileNames = [ "lantian" ];      # firefox
-        profileNames = [ "lantian" ];      # librewolf
+        profileNames = [ "zhyi" ];
```
- **差异实质**：仅 firefox/librewolf 的 profile 名（用户名），**硬性差异，排除**；主题机制本身一致。

### 1.7 `home/common-apps/stylix.nix` — 非外观

```bash
-_ {
-  stylix.enableReleaseChecks = false;
-}
+_: {
+  stylix = {
+    enableReleaseChecks = false;
+    targets.opencode.enable = false;   # 本仓库新增
+  };
+}
```
- **差异实质**：本仓库新增 `targets.opencode.enable = false`（禁用 opencode 主题 target）。
- **建议**：功能微调，**可对齐**（把新增行去掉或确认 opencode 是否在 ml-laptop 使用）。不直接影响桌面外观。

### 1.8 `home/client-apps/plasma.nix` / `gtk-themes.nix` / `fonts.nix` — 一致

---

## 二、公共模块层（t2，影响桌面外观/系统功能）

> 目录清单差异：`minimal-components/firewall.nix`（本仓库单文件） vs 上游 `firewall/`
> 目录（arp/common/default/inet-rules）。**内容实质等价**（本仓库已把 ARP 反欺骗逻辑合入单文件），
> 结构重构、功能不变。

### 2.1 `nixos/client-apps/firefox.nix` — 桌面外观（工具栏）

```bash
-      ShowHomeButton = true;
+      ShowHomeButton = false;
-        Title = "Lan Tian @ Blog";     →  "Magic Flash @ Blog"  (用户名/品牌，排除)
```
- **建议**：**需对齐**（ShowHomeButton false→true）。工具栏外观差异，用户可拍板是否要显示首页按钮。
  homepage title/URL 为品牌域名差异，排除。

### 2.2 `nixos/client-apps/google-chrome.nix` — 桌面外观（首页）

```bash
-      HomepageLocation = "chrome://new-tab-page";
+      # HomepageLocation = "chrome://new-tab-page";
+      HomepageLocation = "https://homepage.rock5c.zhyi.cc";
```
- **建议**：**需用户拍板**（首页设为 fork 的 homepage；如果 ml-laptop 不需要内网 homepage 就改回 new-tab-page）。

### 2.3 系统功能差异（非外观）

| 模块 | 本仓库 | 上游 | 建议 |
| --- | --- | --- | --- |
| `minimal-components/nix.nix` | substituters Attic/国内镜像优先 | 官方缓存优先 | **可对齐/保留**（大陆网络优化，C 类登记） |
| `minimal-components/networking.nix` | backupDNSServers CN 感知（AliDNS 223.5.5.5） | 固定 GoogleDNS | **可对齐/保留**（CN 网络） |
| `minimal-components/kernel.nix` | 移除 emperors-scepter、udev 规则带 adios 条件 | 含 emperors-scepter | **需评估** |
| `minimal-components/cups.nix` | aarch64 不兼容驱动 optionals 门控 | 全量 | **可对齐/保留**（功能性优化） |
| `minimal-components/environment.nix` | timeZone=Asia/Shanghai | America/Los_Angeles | **硬性（时区）保留** |
| `common-apps/coredns.nix` | CN-split 选项走 AliDNS | 固定 GoogleDNS 顺序 | **需拍板**（DNS 转发行为不同） |
| `common-apps/mcp-servers.nix` | 删 exa、mcp<2 锁定、initTimeout=60000、caldav 0.10.0 | uvx、grok-4.3 | **可对齐**（功能） |
| `client-apps/backup` | sftpEndpoint 选项、保留策略 0/7/4/1 | 1/14/8/12 | **需拍板**（保留期下调为有意） |
| `smtp.nix`/`ssh-harden.nix`/`nginx.nix` | sops 依赖、tmpfiles、/var/empty 安装（健壮性增强） | 无 | **可保留**（增强） |
| `zerotier` | ltnet 网络 ID `466270de...` | `91450b...` | **硬性（网络）排除** |

---

## 三、hosts 层 `ml-laptop` vs `lt-hp-omen`（t3 完整 diff）

### 3.1 `hosts/ml-laptop/host.nix`

| 字段 | 上游 lt-hp-omen | 本仓库 ml-laptop | 类别 | 建议 |
| --- | --- | --- | --- | --- |
| index | 100 | 118 | 硬性 | 保留 |
| tags | `[client, #cuda(注释)]` | `[client, lan-access]` | 真实 | **需拍板**：lan-access 是 ml-laptop 需要的（要 LAN 访问）；cuda 注释掉。不误加 firewalled/dn42（ml-laptop 是家内网笔记本）。 |
| cpuThreads | 16 | 18 | 硬性（真实 CPU） | 保留 |
| city | US Bellevue | CN Ningbo | 硬性 | 保留 |
| hostname / IP / zerotier | lantian / 127.0.0.1 / `9dfea6fa27` | ml-laptop.zhyi.cc / 192.168.0.55 / `08d6522fba` | 硬性 | 保留 |
| ssh.ed25519 | lantian 指纹 | zhyi 指纹 + 新增 ed25519Fingerprints | 硬性（密钥） | 保留 |
| dn42/firewalled | 有 | 无 | **需拍板**（家内网不适用） | 保持无 |
| manualDeploy | 无（默认） | true | **需拍板** | 保留（本仓库部署习惯） |

### 3.2 `configuration.nix` — imports 差异

**上游有、本仓库无：**
- `./hp-keyboard-backlight.nix`（HP Omen 键盘背光 systemd service）→ **不应复刻**（非 HP 硬件）
- `./nandsim.nix`（UBI/mtd 内核 + 工具）→ **需拍板**（开发用，无关桌面）
- `./nbfc.nix`（作者已注释）→ **不应复刻**
- `optional-apps/byparr.nix, libvirt, llama-cpp, netns-tnl-buyvm, nix-distributed, obs-studio,
  opencl, virtualbox, vlmcsd, whisper-cpp` → **需评估**（多为 server/开发功能，与桌面无关；
  若严格对齐 lt-hp-omen 才需考虑，否则按 lt-dell-wyse 物理笔记本惯例不引入）

**本仓库有、上游没有：**
- `ncps-client.nix`, `pipewire-combined-sink-alsa`, `pipewire-roc-source`, `pipewire-vban-recv`,
  `pipewire-volume-control`, `sunshine.nix` → **有意差异**（见 3.4 pipewire 结论）

### 3.3 `configuration.nix` — 配置项逐项

| 项 | 上游 lt-hp-omen | 本仓库 ml-laptop | 类别 | 建议 |
| --- | --- | --- | --- | --- |
| boot.kernelParams `cfg80211.ieee80211_regdom=US` | 有 | 无 | **需拍板** | lt-dell-wyse 无此行；regdom 与法规域相关，zhyi 在华，问用户要不要 US |
| hardware.nvidia.open=mkForce false | 有（N 卡） | 无 | **需拍板** | ml-laptop 无 N 卡，不加 |
| lantian.hidpi=1.5 | 一致 | 一致 | — | 无差异 |
| environment.systemPackages comfy-ui-cuda/unigine-* | 有 | 无 | **需拍板** | 无 N 卡不加 |
| hardware.bluetooth enable+powerOnBoot=false | 有 | 有 | 一致 | 无 |
| hardware.xpadneo.enable | 有 | 无 | **需拍板** | Xbox 手柄，问用户 |
| lantian.pipewire.roc-sink-ip | `["192.168.0.207"]` | 导入 combined-sink/roc-source/vban | 真实差异 | 见 3.4 |
| services.samba | 一致（仅 lantian→zhyi） | 硬性 | 保留 |
| services.displayManager.sddm X11 `ServerArguments="-dpi 144"` | 有 | 无 | **需拍板** | lt-dell-wyse 无；高分屏 dpi，ml-laptop 若高分屏建议对齐 |
| services.libinput.touchpad accel/clickfinger/disableWhileTyping | 有 | 无 | **需拍板** | 个人偏好，可选对齐 |
| services.usbmuxd enable+Restart=always | 有 | 无 | **需拍板** | iPhone 相关 |
| virtualisation.waydroid.enable | 有 | 无 | **需拍板** | Android 容器，需用户 |
| services.udev.extraHwdb（HP Omen 键盘重映射块） | 有 | 无 | **不应复刻** | HP 专属 |
| fileSystems bind（13 个媒体挂载） | 一致（仅 lantian→zhyi） | 硬性 | 保留 |
| fileSystems /mnt/share NFS | `lt-home-vm:/storage` | `opi5p:/storage`（fork 自用文件服务器） | **硬性（复刻拓扑）保留** |
| services.yggdrasil.regions=united-states | 有 | 无 | **需拍板** | 家内网可不用 |
| services.sunshine csrf_allowed_origins | 无 | 有 | **本仓库独有** | 保留（fork 功能） |
| services.tlp AC 策略覆盖 | 无 | 有（schedutil/balance_power/balanced） | **本仓库独有** | 保留（笔记本解热优化） |
| networking.hosts 本机互联 | 无 | 有 | **本仓库独有** | 保留 |
| boot.loader.grub | 无（在 hardware 层） | 有（efiSupport/nodev） | 结构差异 | 保留（见 3.5） |

### 3.4 `services.pipewire`（重点，t4 已用 bash 实证）

- 两侧 7 个 pipewire 模块文件内容一致（仅 volume-control 有硬性 zhyi/zhyi.cc 差异）。
- `ml-laptop` 的 combo（combined-sink-alsa + roc-source + vban-recv + volume-control）
  = **作者 `lt-dell-wyse` 的 pipewire imports 逐字一致**。`lt-hp-omen` 用的是 roc-sink（接收端）。
- `ml-2700` 也是同一 combo → 说明这是 fork 的 client 惯例，不是 ml-laptop 独特偏离。
- **结论**：**无需改动**（这是刻意差异、非偏离）。ml-laptop 是物理笔记本（类比 lt-dell-wyse），
  用 roc-source+combined-sink 做音频发送/合并是正确配置；不应改成 lt-hp-omen 的 roc-sink。

### 3.5 `hosts/ml-laptop/hardware-configuration.nix`

| 项 | 上游 lt-hp-omen | 本仓库 ml-laptop | 类别 | 建议 |
| --- | --- | --- | --- | --- |
| imports | crashdump/hdr/nvidia-prime/smart | `scan/not-detected` | **不应复刻** | 无 N 卡/不用那些硬件模块 |
| boot.loader.grub | gfxmode 2560x1440 + useOSProber | efiSupport/nodev（在 configuration） | **需拍板** | osProber 双系统相关；ml-laptop 若 Windows 双系统可对齐 |
| boot.initrd modules | thunderbolt/vmd/sdhci_pci | thunderbolt/nvme/xhci/usb | 真实硬件 | 保留 |
| fileSystems | LUKS+btrfs 子卷(nix/persistent/persistent/home) + /mnt/c NTFS + /mnt/root | UEFI 两分区(/boot+/nix tmpfs /) | **不应机械照抄** | 不同物理机；UUID/分区禁止复制 |
| cpuFreqGovernor | powersave | schedutil | 真实 | 保留 |
| hardware.logitech.wireless | enable+enableGraphical | 无 | **需拍板** | 是否用罗技无线外设 |

---

## 四、分类汇总（对齐 / 需拍板 / 不应复刻）

### A) 建议直接对齐（可执行）
1. **Stylix 版本分支 + stylix.nix API**（1.2 + flake 输入）：对齐到上游 step-2 分支，
   `palette.generators.semantic` 写法。→ 解决「桌面配色不一样」的根本。
2. `nixos/client.nix`：去掉 `stylix.autoEnable=true` 硬编码，回归上游机制（配合 1）。
3. `firefox.nix`：`ShowHomeButton` true/false 取舍（需用户确认要不要恢复首页按钮）。
4. `home/common-apps/stylix.nix`：新增 `targets.opencode.enable=false` 是否去掉。
5. 系统功能差异（nix/nkcoredns/backup 等）按既有 C 类登记或单列评估。

### 需用户拍板
- `boot.kernelParams cfg80211.ieee80211_regdom=US`（无线法规域）
- `sddm ServerArguments="-dpi 144"`（是否高分屏）
- `libinput.touchpad` 触控板手感
- `host.nix tags`：是否保留 `lan-access`（建议保留）、是否误加 firewalled/dn42（不适用）
- hardware 专属：`xpadneo`（手柄）、`usbmuxd`（iPhone）、`waydroid`（Android）、`logitech.wireless`
- `google-chrome` 首页 URL（new-tab vs fork homepage）
- `nandsim`（开发用）、上游大量 optional-apps（llama-cpp/virtualbox/obs/whisper-cpp 等 server 功能）
- `services.yggdrasil.regions`（家内网是否需要）

### 不应复刻 / 机械照抄
- `hp-keyboard-backlight.nix`、`nandsim.nix`、`nbfc.nix`（HP 专属/无关）
- `services.udev.extraHwdb` HP 键盘重映射
- `hardware.nvidia.*`/comfy/unigine/opencl（无 N 卡）
- `hardware-configuration.nix` 磁盘 UUID/LUKS/btrfs 子卷/NTFS/mnt-root（不同物理机）
- NFS `/mnt/share` 目标已改为 fork 自己的 opi5p（复刻拓扑）

---

## 五、后续同步守则（沿用）

- 每次同步先记录上游基准提交，再查看作者自上次审计后的提交列表；
- 公共模块删除、接口变化、安全边界和弃用修复优先跟随作者；
- hosts/硬件/域名/IP/证书/secrets 和生产拓扑禁止机械覆盖；
- 新增公共差异优先设计参数；
- 每项保留差异都要能指出运行需求、目标主机和验证方法。
