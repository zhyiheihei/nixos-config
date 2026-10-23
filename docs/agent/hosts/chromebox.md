# chromebox（Intel i7-8550U 小主机）

媒体自动化与 Jellyfin 宿主（2026-10-16 起 Jellyfin 自 rock5c 迁入，UHD 620 走
VAAPI 硬解/硬编 H.264/HEVC 10bit，多会话轻转码不再受 rock5c 8 GiB 天花板约束）。
`hosts/chromebox/*.nix` 不写注释，理由记录在本文件。

## Jellyfin 与媒体链路

- `forceEncodingConfig` 用本机 VAAPI 覆盖随状态 rsync 带来的 rkmpp 编码配置，让
  NixOS 配置成为 `encoding.xml` 的唯一真源。UHD 620 的 QSV 需要已被 nixpkgs 标记为
  不安全的旧 Media SDK，所以直接用 iHD 驱动的 VAAPI 后端，避免引入该运行时
  （Intel 驱动写法见 `nixos/client-components/xorg.nix`）。
- `.NET` 应用不认 socks5，元数据走 router v2ray 的 HTTP CONNECT 入站拉
  TMDB/图片等外网内容；媒体库挂在 QNAP NFS 上，NAS 就绪前不扫盘。硬化与 chroot 由
  原版 jellyfin 模块提供，主机侧只补依赖。
- **chroot 里的 VA-API 驱动**：libva 运行期 dlopen `/run/opengl-driver` 下的 iHD
  驱动，其 gmmlib 依赖不在 `ExecStart` 闭包里，confinement chroot 看不到，
  ffmpeg 会报 "Failed to initialise VAAPI connection"；驱动闭包要显式补进 chroot。
- 媒体库由 MoviePilot 刮削写回，Jellyfin 在 chroot 中只读访问。
- **8096 回源 vhost**（`jellyfin-backend.chromebox.zhyi.xin`）：上游 `jellyfin.nix`
  只开 netns 内 unix socket（假设 nginx 同机），跨机后端必须有 TCP 监听。用模块同款
  vhost 机制开 8096 HTTP 回源 socket，命名同 rock5c `jellyfin-api` 的
  `<name>.<host>.zhyi.xin` 形态。`accessibleBy = "private"` 的放行集是 LTNET + lo，
  不含家庭 LAN 段，所以上游主机必须经本机 LTNET 地址回源；这属拓扑环境事实偏移，
  共享模块保持原文。当前消费者是 opi5p 的 `jellyfin.zhyi.xin` 公网前沿
  （`ltnet.IPv4:8096`）。
- **网页字幕 CJK 回退字体**（与 rock5c `media-apps.nix` 同款）：Jellyfin 只收
  ttf/otf/woff 且总量限 20MB，用单区 SC OTF；烧录路径走系统 fontconfig。
  CR WEB-DL 中文字幕轨样式引用 Trebuchet MS/Arial 等无 CJK 字形的字体，不补字体
  客户端会渲染成方框。
- 仿真/游戏服务器常驻高负载，CPU `powersave` 降频会造成顿卡（2026-10-14 排查），
  本机保持性能档。

## Palworld

- 2026-10-21 随上游停用，用户指示在本机重新启用（上游没有 palworld 消费主机，属
  fork 偏移）：公网 UDP 8211 由 router DNAT 到本机，hairpin 同样规则。
- `palworld-exporter` 1.3.1 的存档自动发现与新版 Palworld 的 `backup/` 子目录布局
  不兼容（glob 到两个 `Level.sav` 后报 `No GameUserSettings.ini` 退出），且 9877 没有
  Prometheus 抓取方，禁用避免崩溃重启循环；服务器本体不受影响。
- 上游 treewide `RestartSec`（b1383d16）会让 ensure-service-restart 断言拒绝
  `RestartSec < 3s` 或缺 `Restart` 的服务；palworld 只在 chromebox 导入，上游没有
  消费主机故不在其列，主机级补齐 `Restart`/`RestartSec`，避免偏离共享模块。

## 网络与存储

- 通用策略禁用全局 wait-online；NFS 挂载依赖按接口实例等待。
- 媒体库挂 QNAP NFS（`/mnt/storage`），`noauto` + automount 写法对齐 opi5p
  （`c72df01ca`）。
- `bitmagnet` 在本机停用：缺重新生成的 `tmdb.yaml` secret。

## 硬件文件

UEFI 两分区布局（512M ESP + Btrfs 三子卷 `nix`/`persistent`/`persistent-home`，
tmpfs `/`）。UUID 是 2026-09-21 安装现场 `blkid` 实测值（KIOXIA EXCERIA 465.8G，
S/N `51IA21S3K2Q2`）。Intel 平台微码 + 自由固件（i7-8550U）。
`host.nix` 的地域字段即使没有 dn42，server-role 的 BIRD 配置也会读取。
