# ml-laptop 主机适配注记

HP 笔记本（Meteor Lake，18 线程），对齐作者 `lt-hp-omen`。eGPU 相关内容
（RTX 2080 Ti via TBT3 dock）单独成篇，见
[ml-laptop-egpu.md](ml-laptop-egpu.md)；本文记录 eGPU 之外的主机级适配。

## 角色

- `client` 主力机，`manualDeploy`；自 2026-09-04 起运行 Hydra（CI 自
  ml-builder 迁入）。构建拓扑（本机 1 槽、不对外通告、aarch64-cross）见
  [hydra-build-chain](../../agent/hydra-build-chain.md)。
- Moonlight 远程控制的目标设备：Sunshine 串流服务端必须常驻。

## CPU 调频与散热（TLP AC 策略，2026-09-04）

| 项 | 值 | 原因 |
| --- | --- | --- |
| `CPU_SCALING_GOVERNOR_ON_AC` | `powersave` | intel_pstate active 模式下 `powersave` 即 HWP 自动调频；`performance` 恒定最高频（负载 0.65 也 4.3GHz/70°C），`schedutil` 在 active 模式下不存在（TLP 报 governor not available 后整段配置失效） |
| `CPU_ENERGY_PERF_POLICY_ON_AC` | `performance` | EPP 拉满：重载最大 boost、轻载自动回落 |
| `PLATFORM_PROFILE_ON_AC` | `performance` | 平台档拉满后风扇由 BIOS/EC 曲线控制（`pwm1_enable=2`）；`balanced` 档高温也不拉满，这是 Linux 侧唯一有效的风扇入口 |

电池模式保持默认 powersave。

## 显示

- `lantian.hidpi = 1.6`（grub/console 字体缩放）：与 KWin Wayland 输出缩放
  （kscreen 里的 1.6）一致，让 X11 应用（`Xft.dpi = hidpi × 96`）与
  Wayland 原生应用视觉大小统一（2026-09-03 自 1.5 上调）。

## Steam 启动包装（条件注入 PRIME 变量）

`nixos/hardware/nvidia/prime.nix` 在本机的覆写把 steam wrapper 改为运行时
条件注入：`/proc/driver/nvidia/version` 存在（⇔ eGPU 在位，模块由 udev 按设备
加载）时注入 PRIME offload 变量，不在位时退回核显。拔掉 eGPU 后若强制
`__GLX_VENDOR_LIBRARY_NAME=nvidia`，Steam bootstrap 的更新 UI 会在 Xwayland
上创建 GLX context 失败（BadValue / X_GLXCreateContext）而卡死自更新——
2026-09-02 拔 eGPU 后 Steam 打不开的根因。注入脚本每次运行时判定，重建
系统后自动跟随 eGPU 状态，无需热插后再 rebuild。

## waydroid 音频 socket

waydroid 硬编码挂载 `$XDG_RUNTIME_DIR/pulse/native`，而本机 PipeWire 跑在
系统级（socket 在 `/var/run/pulse/native`），缺这个用户级 tmpfiles 链接时
lxc 挂载失败、容器无法启动。

## waydroid 系统镜像持久化

根分区是 tmpfs，而 waydroid.cfg（在持久的 /var/lib/waydroid）写死
`images_path = /etc/waydroid-extra/images`（waydroid init 的本地镜像模式，
`system_ota = None`）。镜像放 /etc 的话重启即丢：2026-09-01 init 后当天
可用，09-25 重启后容器 mount system.img 失败，应用即开即闪退。
2026-10-08 修复：镜像（lineage 20.0-20260927 system+vendor，OTA sha256
校验）落 `/nix/persistent/waydroid/images`，主机级 tmpfiles 规则
`L+ /etc/waydroid-extra/images` 软链回去。镜像升级需手动重下该目录两个
img（waydroid 本地镜像模式不走 OTA）。

## waydroid ARM 兼容（libndk，2026-10-08 自 libhoudini 切换）

原生镜像仅 x86_64/x86（abilist 无 ARM）。ARM 转译层经 waydroid_script
（casualsnek，官方文档推荐）装在 /var/lib/waydroid/overlay/system
（持久卷）。现为 libndk（Google ndk_translation，Android 13 分支
@68734c5），对纯 ARM64 游戏比 houdini 快；已用 ARM64 busybox 实测转译
执行成功。切换/重装注意：binfmt_misc 注册表是内核全局状态，跨容器重启
持久存在——卸载 houdini 换 libndk 后，残留条目仍指向已删的 houdini
runner 导致 ARM exec 报 ENOENT、ndk 同名条目注册不进去；需在容器内
`echo -1 > /proc/sys/fs/binfmt_misc/{arm_exe,arm_dyn,arm64_exe,arm64_dyn}`
注销后重注册（或宿主重启）。反向切换同理。

## waydroid 国内网络：captive portal 探测点

GPU 渲染已确认硬加速（容器 Mesa 26 直连 MTL iGPU）；游戏卡顿主因是
转译层 CPU 开销。另一坑：纯净镜像默认探测 google，GFW 环境下校验必
败，网络带 PARTIAL_CONNECTIVITY 标记，腾讯系登录 SDK 检查网络有效性，
表现为扫码登录/加载卡住。2026-10-08 修复（设置存 data 分区持久）：
```
waydroid shell -- settings put global captive_portal_http_url \
  http://connect.rom.miui.com/generate_204
waydroid shell -- settings put global captive_portal_https_url \
  https://connect.rom.miui.com/generate_204
waydroid shell -- settings put global captive_portal_fallback_url \
  http://connect.rom.miui.com/generate_204
```
改完需重启容器重校验；验收标准 = dumpsys connectivity 无
PARTIAL_CONNECTIVITY、logcat isCaptivePortal isSuccessful()=true。

## 已知问题：surfaceflinger 重 GPU 负载下崩溃

上游已知不稳定性（waydroid issue #1647 同签名，open 无修复）：重 GPU
负载（游戏类应用）下 surfaceflinger 崩在 HWC2 present 路径，Android
init 自动拉起 SF 并重启 zygote，前台应用被连带杀掉、表现为黑窗。
2026-09-01（composer HAL 空指针 + SF abort）与 2026-10-08（SF SEGV）
tombstone 同族，非本地配置/ARM 转译引入；宿主 GPU（Intel iGPU
renderD128）无异常。低频（五周三例），重新打开应用即可恢复；镜像更新
时留意上游修复。

## Sunshine

- 全栈固定核显（Intel）：eGPU 不驱任何显示器，而该版 Sunshine 的 nvenc
  初始化要求编码 GPU 自带 monitor，每轮探测报 "Couldn't find monitor [0]"
  （约 0.4s/轮）再回落 vulkan→vaapi。显式钉死 `encoder=vaapi` /
  `capture=kms` 跳过探测循环；KMS 命中的就是核显侧 HDMI-A-1 输出。
- `csrf_allowed_origins` 在主机层放行 LAN/LTNET 地址（公共模块
  sunshine.nix 不动）：否则 CSRF 防护挡住配对页。

## 作为 Mac 副屏（AirPlay 接收端）

MacBook Air（`molishanguangs-MacBook-Air-89.local`）不用装任何软件：本机跑
UxPlay 当 AirPlay 接收端，Mac 在「控制中心 → 屏幕镜像」里选 `ml-laptop@ml-laptop`
（macOS 26 也可在「系统设置 → 显示器」里看到它，点显示器名按「用作」选扩展/镜像），
然后选「扩展」而不是镜像。两边只需在同一 LAN（mDNS 多播可达）。

本机启动（KDE Wayland）：

```bash
mac-display    # = uxplay -n ml-laptop -vs xvimagesink -vsync no，余下参数透传
```

- 包在 `home/client-apps/packages.nix`（launcher `mac-display` +
  `uxplay-with-plugins`，只装 ml-laptop）。会话里的
  `GST_PLUGIN_SYSTEM_PATH_1_0` 只有 core/base/good，缺 h264/h265 解析解码、
  libav 与显示 sink，裸跑会黑屏；wrapper 把 uxplay 自身引用的六个插件闭包
  钉进启动环境（2026-10-09 实测 `waylandsink`/`xvimagesink`/`avdec_h264`/
  `vah264dec`/`h264parse`/`avdec_aac` 均可见）。
- **sink 不能用 waylandsink**（2026-10-09 定型）：本机 Intel 核显 +
  GStreamer 1.28 + KWin Wayland 上它把画面渲染成彩色横条纹（AirPlay 连接、
  解码、取包全部正常，坏在最后一跳）。用 uxplay 同一条管线、源换 1080p
  SMPTE 彩条本地复现：waylandsink 花屏，xvimagesink 正常；上游 issue #541
  （Intel HD 620 + GStreamer 1.28「Video Output is messy」）同因同解。
  本机 sink 排名 xvimagesink(256) > glimagesink(128) > waylandsink(64)，
  launcher 显式钉死不依赖排名。要试其它 sink：`mac-display -vs glimagesink`。
- 默认向客户端请求 1920x1080@60；要更清晰可 `-s 2560x1600@60`（超 1080p
  走 h265，必要时加 `-h265`；`vah265dec`/`h265parse` 已验证可用）。`-fs`
  直接全屏，运行时 F11 / Alt+Enter 也可切。
- 日志判读：正常启动会打印两条 audio pipeline、h264 video pipeline、
  `Initialized GStreamer video renderer` 和 `advertised AirPlay service with
  Features code = 0x...`；之后没有任何输出 = 客户端根本没连上来，问题在
  发现/入口，不在本机。Mac 真的连上时会继续出现 `raop_rtp_mirror starting
  mirroring` 以及 bus message。
- 音频默认从本机放（PipeWire 的 pulse 兼容口）。断开在 Mac 侧停止镜像。
- Mac 侧看不到设备时，在 Mac 的终端跑 `dns-sd -B _airplay._tcp`（系统自带）
  看它到底收没收到 Bonjour 广播：列得出 `ml-laptop@ml-laptop` 而菜单/显示器
  设置里没有 = macOS 侧的问题；列不出 = mDNS 未到达 Mac（先查两台是否同网段）。
- 上游不旧也不停维（2026-10-09 查）：最新 release v1.73.7（2026-09-04）就是
  nixpkgs 里这个版本，master 到 2026-10-05 还有提交，维护者 fduncanh 在
  issue #458 实测 macOS 26 Tahoe（M4 Mac mini）能正常镜像到 UxPlay。
- AirPlay 串流适合文档/终端/参考窗口，不适合游戏。要低延迟高画质走下面的备选。

### 备选：Sunshine(macOS) + Moonlight + BetterDisplay

Mac 侧装 sunshine（`brew tap LizardByte/homebrew && brew install sunshine`）与
BetterDisplay；用 BetterDisplay 建虚拟显示器，把它的 `CGDirectDisplayID` 填进
Sunshine 配置的 `output_name_unix`；本机已装 `moonlight-qt`，连上 Mac 后选
Desktop。延迟与画质优于 AirPlay（走 VideoToolbox 硬编），代价是 Mac 侧要装两个
第三方件并手工建虚拟显示器。
