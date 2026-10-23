# opi03（Orange Pi 3，bring-up 阶段）

首启阶段的主机：不计入批量部署，直到 SD 启动、以太网、持久主机身份与调试串口都验证
通过。`hosts/opi03/*.nix` 不写注释，理由记录在本文件。

## 网络

- bring-up 期间只用 DHCP。上游 mainline 的 Allwinner DT 别名通常产生 `end0`，这里保留
  `eth0` 是为兼容旧的命名策略版本。
- 本机还没有最终 LAN 身份：ADB 只监听 loopback，通过 SSH 端口转发访问；**绝不在 WAN
  上暴露无认证的 adb daemon**。

## Android / 加速器

- Android 的 `bpfloader` 需要相应 sysctl 可写且开启；仓库级 hardening 默认把它设成
  「重启前不可逆」，所以在第一次启动 reDroid 之前就用声明式配置覆盖，而不是运行时修补。
- 本地构建的 Android rootfs 以 `.tar.zst` 传输，解压留在本机、所有编译都在 ml-builder。
- 加速器首启阶段放宽限制，避免 SELinux 策略噪音掩盖 GPU/VPU 的 ABI 错误；收紧策略是
  Mali 与 `c2.allwinner` 都通过之后的独立验收步骤。
- 全新 NixOS 镜像必须在本地 Android rootfs 导入之前保持可启动：显式 marker 把相关
  unit 变成 skipped，而不是激活失败或意外去拉镜像仓库。
