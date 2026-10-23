# ml-builder（远程构建机，x86_64，强机器/VM）

集群的 x86 编译主力：接管 `big-parallel` 与 aarch64 交叉内核构建。空闲时人工关机，
所以大更新（`flake.lock` / `nvfetcher.toml` 有改动，或新增大体积包）前要先物理开机；
部署前的确认门槛见 [deployment](../deployment.md)。`hosts/ml-builder/*.nix` 不写注释，
理由记录在本文件。

## 出口与缓存

- **FOD 直连清单**（`fetchDirectHosts`）：这些域名从本机直连稳定，经出站代理反而被
  上游 403/502 拒绝或降速到 KB/s（2026-09-05 对构建日志里全部 65 个拉取域名逐一
  实测；github、`*.googlesource.com`、discord、torarchive 等被墙域名不在其列，仍走
  代理）。清单维护方法见 [outbound-proxy](../outbound-proxy.md)。
- 客户端与 nix-daemon 两侧共用同一代理（flake lock 拉取在客户端侧，FOD fetch 走
  daemon）。
- 下载集中在本机：远程构建机通过 Nix store 连接拿到所需输入，不再各自走不一致的网络
  去够外部 substituter。
- substituter 超时放宽到 5 秒以上：GitHub archive 的重定向从本网络回来经常超 5 秒，
  即使代理正常。
- **构建目录落磁盘**：仓库级 tmpfs 构建目录在大构建下引发 swap 风暴（见
  [outbound-proxy](../outbound-proxy.md) 的 2026-09-05 soft lockup）。
- **并发**：`max-jobs=auto`(28) × `cores=0`（每个构建内部不限线程）会让内核 LTO、
  wine、qtwebengine 等大件同时全速开跑，2026-09-05 构建 ml-2700 时连续触发三轮 OOM
  （单轮 96 个派生被连环杀）。根因是 tmpfs 构建目录 + zram 回收风暴（已迁磁盘）；
  6×16 全天稳定。
- **zram swap** 保持启用（通用 nix-builder 策略把它设为 0，会让 swap 在分配已经失败
  前一直闲置）。Firefox 的单次 `ld.lld` 链接需要 25–30 GiB RSS，默认 50% zram
  （约 29 GiB）在 2026-08-07 即使限并发也被 OOM 杀两次，所以用满内存的 zram swap 让
  单个链接器能活下来。
- **磁盘 swap + zram 双开**：`hardening.nix` 在 `swapDevices` 非空时会关 zram，所以
  两者都要显式配；设计依据见 [hydra-build-chain](../hydra-build-chain.md)。

## 内存保护

2026-09-25：多客户端（ml-laptop / opi5p 的并行部署会话）预算叠加时，聚合内存峰值
仍会超出 58 GiB + zram 包络，进入回收风暴后整机冻结（当天两次失联）。earlyoom 在
内存吃紧时杀掉最大的单个编译进程——丢一个构建换整机存活，优先杀编译器/链接器、
保护 nix 基础设施。阈值收紧依据见 [hydra-build-chain](../hydra-build-chain.md)。

## 平台能力

- 只有本机对外通告原生 x86_64 工具链（`requiredSystemFeatures`），用于 aarch64 交叉
  构建；普通 x86_64 派生仍可分发到其他构建机。
- 按作者的 `qemu-user-static-binfmt` 配置，这台 x86_64 机器也能在本地用 QEMU 构建
  aarch64 派生。

## 备份与主机元数据

- 摘除 `server` 标签后 backup 默认关闭，显式启用（同 ml-laptop 惯例）；本机只在有
  构建任务时开机，备份随之间歇运行。
- `host.nix` 声明本机是强机器/VM 远程构建机；`buildCores` 按实际分配 vCPU 数调整，
  影响远程构建并发；`colmena`/`deploy-rs` 这类远程部署工具优先用这里的连接信息。
- SSH host public key 重装后从固定局域网地址重新读取：
  `ssh-keyscan -p 2222 192.168.0.50 | grep ssh-ed25519`。

## 硬件文件

作者这套 impermanence 配置会把 `/` 变成 tmpfs，所以真正持久的系统数据必须放
`/nix`，`/boot` 也要单独持久化。目标布局是 `/dev/sda1 → /boot`（ext4）、
`/dev/sda2 → /nix`（btrfs）；实际分区号或 UUID 不同时用 `lsblk -f` 查出来后改。
