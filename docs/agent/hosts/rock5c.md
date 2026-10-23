# rock5c（ROCK 5C，RK3588S2，8 GiB）

家庭媒体主机与本地应用宿主。2026-10-23 起**不再承担家庭 Web 前置**：家庭入站
（公网 8443 / 兼容 4000 / 内网 hairpin 443）统一由 opi5p 终止，详见
[入口结构](../fleet-service-chain.md) 与 [domain-service-layout](../domain-service-layout.md)。
`hosts/rock5c/*.nix` 里不写注释，理由都记在这里。

## 网络

- 板载 GMAC 用永久 MAC（`e2:dc:47:5e:02:24`）匹配成 `lan0`，避免驱动/探测顺序
  变化把静态 LAN 配置挪到别的口；静态地址 `192.168.0.64/24`，默认路由经
  `192.168.0.1`。NetworkManager 在本机被强制关闭，网络由 systemd-networkd 管。
- 全局策略故意 mask 了 `systemd-networkd-wait-online`，但本机 NFS 媒体盘必须在
  物理链路就绪后才能挂，所以单独启用 scoped 的
  `systemd-networkd-wait-online@lan0.service`。
- 本机没有可靠 RTC：日历定时器会在时钟仍落后数月时布防，时间同步一跳就把定时器
  全部点燃；全局 `podman system prune -af` 因此在容器启动前删掉导入的 MetaCubeXD
  与 reDroid 镜像。全局保持作者默认，只在本机关闭 `podman.autoPrune`，镜像清理
  靠人工。
- `kernel.unprivileged_bpf_disabled = 0` 是本机需要的（容器内 BPF 工具链）。

## 存储

- NAS 直接导出媒体库：本机挂同一 NFS 共享（`/mnt/storage`），不经过别的家庭主机
  中转媒体流量。
- 挂载用 `noauto` + automount，写法对齐 exam `lt-hp-omen`（同 opi5p 修法，
  c72df01ca）：裸 mount 在 NAS 未就绪时失败且不重试，还会卷入 ordering cycle。
- `/mnt/storage.mount` 加 drop-in `StartLimitIntervalSec=0`：NAS 掉线窗口里容器
  反复触发 mount，默认 5 次/10s 限流会让 automount 永久 failed；解限后每次访问
  都是一次重试，NAS 恢复即自愈。

## 媒体栈

- **Jellyfin**：2026-10-17 迁往 chromebox（x86 VAAPI 硬解），原因是本机 8 GiB
  内存下转码会话被 earlyoom 绞杀形成循环故障。曾经的 `jellyfin-rockchip`
  模块与它的回滚块已于 2026-10-23 删除（需要时从 git 历史取回）。
- **`jellyfin-api.rock5c.zhyi.xin`** 保留：MoviePilot 容器的 `--add-host` 指名依赖
  这个 HTTP-only 稳定域名，rewrite 把 `/Library/SelectableMediaFolders` 折成
  `/Library/MediaFolders` 供其扫描聚合 radarr/sonarr 目录。
- **`jellyfin.localhost` / `tachidesk.localhost` / `bt|pt|seedbox|vertex|jproxy|
  peerbanhelper|bitmagnet|iyuu.localhost`**：本机与 LAN 客户端的本地访问名。
  `.localhost` 条目只监听 HTTP、`accessibleBy = "localhost"`。
- **`*arr` 四件套（sonarr/radarr/bazarr/prowlarr）与 decluttarr/exportarr** 已被
  MoviePilot 链路完全替代，import 于 2026-09-04 撤除（死链 vhost 一并消失，
  homepage 不再列出）；`/nix/persistent/var/lib` 下各服务数据未删，回滚 = git
  revert 重新加回 import。
- **chinesesubfinder** 已停用（import 与被 `lt.port` 引用都注释掉了）。字幕字体
  回退随 Jellyfin 迁到 chromebox（`chromebox/media-automation.nix` 携带同名 fallback
  字体），本机不再引用：CR WEB-DL 的中文字幕轨样式引用 Trebuchet MS/Arial 等
  拉丁字体，没有 CJK 字形时客户端渲染出方框（胆大党 E13+ 实测）。

### MoviePilot v3

- 升级（2026-08-13）沿用 v2 的 `/config` 与 SQLite DB，volume/env 映射不变，无需
  数据迁移（切换前做了全量备份）；主机级覆盖以保持 `optional-apps` 模块对齐上游。
- **资源自动更新**：v3.0.3 时代下载 `user.sites.v3.bin` / `sites.cpython-*.so` 会在
  本机 SIGSEGV（同一位置 3 次复现，即使内存有余量）。v3.1.3（2026-10-11）复测：
  独立进程下载 3.0.19 资源（834 KB + 3.4 MB）在 5.8 GiB 可用内存下完成无崩溃，
  因此重新开启自动更新，以自动获得站点定义修复（如 PTTime `search_area` 修复，
  上游 issue #6953 只随资源下发）。
- **`/.dockerenv` 补挂**：v3 的 `can_restart()` 要求 `is_docker()` 成立，而 podman
  只创建 `/run/.containerenv`；官方镜像里 supervisord、二进制、套接字都在，缺的
  只是这个标记文件，导致应用内更新被拒（「当前运行环境不支持升级操作」）。补挂
  空文件后 #6953 这类只随站点资源下发的修复才能到达。
- **代理**：容器 PySocks 在 `socks5` 下本地解析域名，用 `socks5h` 让域名交给
  router 代理解析，避开污染。`podman-moviepilot` 的 environment 同时覆盖大小写
  代理变量。
- **watchdog**（`moviepilot-watchdog.nix`）：把两类已实锤的停摆（订阅搜索队列卡死、
  刷流新增/删种停摆）导出为 node_exporter textfile 指标，由 tencent Prometheus
  告警（Alertmanager → Telegram）。窗口内一次运行都没有时：有运行历史视为持续
  停摆（999），无运行历史（插件已移除/尚未运行）视为未知（0，不告警）。
- **插件路由自愈**：BrushFlow/SubtitleAssistant 容器重启后会丢动态 page/API 路由，
  `moviepilot-plugin-health` 只在路由确实缺失时重载，正常时不制造重启噪音。
- **代理环境**同样下发给 handbrake 镜像拉取与 immich RKNN worker 的模型/镜像下载
  （原本在 `media-apps.nix` / `immich-ml.nix`，按模块放置规范移到主配置）。

## Immich 分布式推理

- RK3588S2 NPU 上的 Immich RKNN worker；缓存放本机 eMMC 上的
  `/nix/persistent`，线程数压到 2，把 RSS 控制在 8 GiB 板子内（opi5p 的主 worker
  保持 3 线程）。
- librknnrt 每次加载模型都会打一条无害的 "static shape type" 警告，日志级别设 0，
  保留真正的 `E RKNN` 错误、压掉 `W RKNN` 噪音。

## 内存与 earlyoom

2026-10-11：Jellyfin 全库元数据刷新叠加 rkmpp 硬解转码（DRM GEM 缓冲计入 Shmem）
把 8 GiB 内存和 4 GiB zram swap 一起吃满；`swappiness=180` 下内核只换页不肯杀进程，
01:25→03:10 进入回收风暴，10:50 起整机活锁到断电。earlyoom 在内存与 swap 同时
吃紧时优先杀转码/推理进程，用一次转码换整机存活（做法同 ml-builder）。

## 其他

- `host.nix` 的地域字段即使没有 dn42，server-role 的 BIRD 配置也会读取（不要删）。
- 2026-10-23 清理：本机的 `jellyfin.zhyi.xin`、`tachidesk.zhyi.xin` 公网名副本已
  删除（公网入口只在 opi5p）；`rk-jellyfin.zhyi.xin` 别名、`publicSites` 条目与
  navdash 标签一并撤除，`jellyfin-rockchip.nix` 模块文件删除。
