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
注销后重注册（或宿主重启）。反向切换同理。GPU 渲染已确认硬加速
（容器 Mesa 26 直连 MTL iGPU）；游戏卡顿主因是转译层 CPU 开销。

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
