# Hydra 构建链路与并发约束

本文是当前 Hydra 与 Nix 远程构建链路的权威说明。主机参数仍以
[`hosts/`](../../hosts) 为准；修改 builder 角色、并发或 feature 前必须同时更新
本文并按末尾流程回归。

## 不变量

- **2026-09-17 起 Hydra 跑在 `opi5p`**（2026-09-04 曾自 ml-builder 迁入
  ml-laptop，后为给工作机减负再迁 opi5p），公共 vhost `hydra.zhyi.xin` 在
  greencloud 覆写后端指向 opi5p 的 LTNET 地址。
- `ml-builder` 仍是唯一主构建机（28 vCPU / 58 GiB + 100% zram），也是唯一声明
  `big-parallel` 的主机。自身构建单额 6×16（`max-jobs = 6`、`cores = 16`，
  2026-09-05 定型，取代 2026-08-06 事故前的多任务不限核策略）；远程派发的
  构建同样走 ml-builder 的 nix.conf，单构建 `-j16` 由构建机侧强制。gRPC
  派发并发 3（`hydra-builder.settings.maxJobs = 3`，2026-10-14 从默认 4
  下调：重建波次起点 PSI=0 时四个构建几秒内同时起跑，叠加 bambu-studio
  类大件进入 zram 风暴直接整机冻结——当天 17:23 冻结、无 OOM 日志，内核
  日志止于 17:23:15）。内存兑底由 earlyoom 负责（阈值 8%/5%，swap 2%
  直接 SIGKILL；2026-10-14 收紧，风暴成形前丢一个编译进程换整机存活），
  zram 交换设备同时限为 32G 上限（无上限时风暴不可恢复；到顶后内核 OOM
  立即杀程）。机器水位 `vm.watermark_scale_factor = 500` 仅构建机生效
  （覆盖 kernel.nix 全局 125）。Hydra 迁走后本机回归纯构建机定位
  （archiveteam/clawemail/epic 容器同期迁出）。
- `pve-5700u` 是纯 Proxmox VE 宿主，不再运行 Hydra，也不再作为 Nix 回退 builder。
- **2026-10-14 下午：大包独立车道**。同一天下午的 OOM 冻结之后另建
  `hydra-builder-big`（同机第二个 gRPC builder 实例）：只声明
  `big-parallel`（mandatoryFeatures 闸口，machine.rs
  `get_machine_for_system` 把未携带该 feature 的任务全部拒之门外），
  **1 并发 × -j4 + 64G 磁盘 swapfile**（/nix btrfs mkswapfile 自动建，
  优先级 0 低于 zram），把 chromium/qtwebengine/llvm/rustc/ghc 等 64 个
  上游 `big-parallel` 大件的峰值内存压平——不考虑构建速度，慢但必成。
  主车道 `supportedFeatures` 显式去掉 big-parallel，两个车道互不抢活。
  注意此机制的覆盖范围是 feature 标记：firefox 没有该标记（给它加标记
  会改 drv hash，上游 binary cache 永久 miss，更糟），留在主车道单链
  25-30G 在 RAM 内放得下，风暴时由收紧后的 earlyoom 优先杀 ld.lld 保机。
  同机 swap 层改为双轨：zram 32G 上限（快钱，先吃）+ /nix/swapfile 64G
  （长尾兜底，慢但能成），`vm.page-cluster` 强制 0 防 zram 预读放大。
- **2026-10-12：Hydra 派发改走 gRPC**（跟随上游与新 nixpkgs）。新 nixpkgs 的
  队列器不再读 `/etc/nix/machines`（`services.hydra.buildMachinesFiles` 已移除），
  改由构建机主动连队列器：`opi5p` 跑本机 `services.hydra-builder`（127.0.0.1 级），
  `ml-builder` 跑远程 `services.hydra-builder`，`queueRunnerAddr` 指向
  `opi5p` 的 LTNET 地址与 `LT.portStr.Hydra.QueueRunnerGRPC`（队列器 gRPC 因此
  绑在 LTNET 而非上游默认的 127.0.0.1）。两边的共享凭据是 `hydra.yaml` 的
  `hydra-queue-runner-token`。派发闸口在 builder 侧的 `builder.toml`：
  `maxJobs` 静态并发上限 + PSI 动态回退（`machineFreeFn =
  "DynamicWithMaxJobLimit"` 两者叠加），daemon 的 `max-jobs` 拦不住 gRPC
  构建， opi5p 据此把 gRPC builder 也强制单槽（`maxJobs = 1`，对齐生产
  节点保护）。`/etc/nix/machines*` 仍服务普通 `nix build`
  （nix-distributed），与 Hydra 的队列无关。Hydra 同期还接上了 Dex OIDC 登录
  （client `hydra`，`dex-hydra-secret`）与 `/ws` 实时构建日志。
- `opi5p` 首先是数据库、媒体和 reDroid 生产节点，只作为单任务原生 ARM 回退节点。
- `rock5c`、Router 和其他业务主机不加入 `nix-builder`；`ml-home-vm` 已退役。
- 构建派发图必须是有向无环图：派发表排除 PVE，保留 OPI5P 作为原生 ARM
  下游，QEMU 只作远程构建关闭时的回退。PVE 不参与任何构建派发。
- `maxJobs` 限制同时运行的 derivation 数；`cores` 限制单个 derivation 获得的
  并行度。两者不能互相替代。
- **并发预算按会话独立计算**（2026-09-25 实锤）：每个 nix 客户端会话
  （手动部署、subagent、Hydra evaluator）各自拿到 machines 表里满额的
  `maxJobs`，互相不知道彼此的存在。远程构建的单构建并行度由构建机的
  `nix.conf` 的 `cores` 决定（走 legacy ssh 的 `nix-store --serve`，
  构建机自身设置生效），而非客户端。因此聚合负载 ≈
  并行会话数 × 每会话槽位 × `-jcores`，任何一侧调整都要按这个公式
  估算总量是否超出 ml-builder 的 6×16 稳定包络。
- 多会话叠加的历史事故：2026-09-25 fleet 部署期间主会话 + 2 subagent
  会话 + Hydra 同时派发，聚合 96+ 编译进程触发 zram 回收风暴、ml-builder
  两次冻结失联；对策即上述「每客户端降为 1+1 槽 + earlyoom 兑底」。

## 构建拓扑（2026-09-17 更新，Hydra on opi5p）

- **opi5p 本机单槽**（`nix.settings.max-jobs = 1`）：Hydra 所在机，aarch64
  原生构建走本机 daemon 单槽；生产节点（PostgreSQL/媒体/reDroid）保护
  见下文 2026-08-02 事故。
- **ml-laptop 本机槽与远程派发并存**（2026-09-27 对齐上游 lt-hp-omen：
  移除原 `max-jobs = 0` + `nix.buildMachines mkForce` 覆盖，改回
  nix-distributed 模块生成的机器表 + `machines-with-localhost` 本机兼容槽）：
  本机可承担零碎派生（如 i686 x32 闭包）避免依赖单一构建机连通性；
  ARM 内核交叉构建仍由 ml-builder（aarch64-cross 通告）承接。
- **ml-laptop 不打 `nix-builder` 标签**：不对外通告本机为集群构建机，其他
  主机的分布式构建不派发到这台笔记本。
  走本机单槽，不自派发。
- ml-builder 侧以 `nix.settings.extra-system-features = [ "aarch64-cross" ]`
  声明同款 feature，本地可跑交叉构建；ml-laptop 本地 daemon 不声明该
  feature（四个 ARM 硬件内核包带 requiredSystemFeatures，固定外派
  ml-builder，避免在笔记本上跑 ARM 交叉编译）。
- Hydra 所在机的 hydra-evaluator unit 注入集群出站代理（直连 GitHub 拉
  flake inputs 实测长期卡死；ml-laptop 时期即如此，迁 opi5p 后沿用），
  见 [outbound-proxy](outbound-proxy.md)。
- Hydra 已从 ml-builder 撤除；`secrets/hydra.yaml` 的 `hydra-ssh-privkey` 仍是
  `nix-distributed` 到各构建机的 SSH 凭据，也是 hydra-evaluator 拉私有 flake
  输入的 key（上游同名 secret，fork 的
  `hydra-builder-ssh-privkey` 别名已随对齐取消）；`hydra-queue-runner-token`
  则是 Hydra 队列器与 gRPC 构建机之间的共享凭据。

## 节点表

| 节点 | 地址 | 架构 | 同时任务 | 单任务核心 | speed factor | 声明 feature | 角色 |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| `ml-builder` | `192.168.0.50` | `x86_64-linux` | 1（+ Hydra gRPC 主道 3 / 大包道 1×-j4） | 0（默认全核） | 28 | `aarch64-cross`, `big-parallel`；Hydra localhost 另有 `kvm,nixos-test,benchmark` | 唯一主构建机，大包和交叉构建 |
| `opi5p` | `192.168.0.62` | `aarch64-linux` | 1（含 Hydra gRPC 单槽） | 0（默认全核） | 8 | 无 | Hydra 所在地；必须执行 ARM 目标程序时的原生回退 |
| `ml-laptop` | `192.168.0.55` | `x86_64-linux` | 0 | — | — | `aarch64-cross`（本地 daemon） | 控制机；自身构建全外派，不跑 Hydra，不对外通告 |

`speed factor` 只帮助 Nix 在同架构候选机之间排序，不是资源限制。真正的保护来自
`nixBuilder.maxJobs`、目标机 `nix.settings.max-jobs` 和 `nix.settings.cores`。

## 派发与缓存链路

| 阶段 | 来源 | 去向 | 选择依据 | 结果 |
| --- | --- | --- | --- | --- |
| 求值与排队 | Hydra（`opi5p`） | gRPC 构建机（`services.hydra-builder`） | 构建机注册时上报的 system 与 feature | 选择实际 builder |
| 普通 x86 构建 | Hydra | `ml-builder`（gRPC 远程构建机） | `x86_64-linux` 且有空槽 | 构建输出进入 Nix store |
| ml-builder 本地发起 | ml-builder | x86 留在本机；原生 ARM 到 opi5p，QEMU 回退 | ml-builder 的机器表排除 PVE，保留 OPI5P | 不产生 PVE↔ml-builder 回路 |
| 大型并行构建 | Hydra | `ml-builder`（gRPC） | 构建机上报的 `big-parallel` | 不占用 PVE/OPI 业务资源 |
| ARM 交叉构建 | Hydra 或 ml-builder | `ml-builder` | build platform 仍是 x86，并要求 `aarch64-cross` | 生成 ARM 产物但不执行 ARM 二进制 |
| ARM 原生构建 | Hydra（本机 gRPC 构建机）或 ml-builder | `opi5p` | derivation 的 system 为 `aarch64-linux` | 单任务执行目标架构构建脚本 |
| 构建后上传 | Hydra RunCommand | `https://attic.zhyi.xin/zhyi` | 成功输出路径 | 私有 Attic/S3 缓存 |
| 客户端取缓存 | Nix 客户端 | 先 Attic，再 `opi5p:13851` 的 NCPS | substituter 顺序 | NCPS 只代理公共上游，不反代 Attic |

普通 `nix build` 仍走 `/etc/nix/machines`（模块默认的 `machines-with-localhost`），
Hydra 的队列则完全走 gRPC，两者互不影响：改 `nixBuilder.maxJobs` 只影响前者，
Hydra 的并发由构建机上报的槽位与队列器调度决定。不要把 localhost 写入机器表，
否则 Nix daemon 可能在持有输出锁时把任务递归派回自己。

2026-08-02 的实际故障中，Hydra 从 PVE 把 derivation 交给 ml-builder 后，ml-builder
又把同一任务交回 PVE；两边各自持有输出锁并等待对方，表现为构建永久停在
`waiting for lock`。因此 `ml-builder` 通过
`lantian.nix-distributed.excludeHosts = [ "pve-5700u" ];` 切断回边，并且 pve-5700u
不再声明 `nix-builder` 标签。这是拓扑约束，不是临时性能调优。

## 为什么必须这样限制

2026-08-02，OPI5P 曾同时被 ml-builder 与 PVE 上的 Hydra 当作 `maxJobs = 8`、
`big-parallel` 的 ARM builder。该机还在运行 PostgreSQL、媒体服务和 reDroid，结果：

- load average 峰值超过 140；
- `MemAvailable` 最低约 109 MiB；
- 内核在一次启动中记录 6 次 OOM；
- Java、PostgreSQL exporter、Samba、`nix-daemon` 和 `cc1plus` 被杀；
- 业务服务与 SSH 一并表现为“整机下线”。

问题不是 ARM 架构本身，也不是网线，而是同时 derivation 数与单 derivation 编译线程
叠乘。OPI5P 和 PVE 都承载常驻业务，因此宁可排队，也不能靠交换空间掩盖错误并发。

2026-08-06，ml-builder（28 vCPU / 58 GiB RAM）在 `maxJobs = 28`、`cores = 0` 下运行
Hydra 与本地构建，`nix-daemon` cgroup 内的多个 `cc1plus`/`cp` 触发全局 OOM，29 GiB
swap 一度用掉 16 GiB。ml-builder 专用于构建，但仍需要限制同时 derivation 数；
当前声明与本地并发统一为 1，单任务不限核数（`cores = 0`）。将来上调并发前，
先观察 `free -h`、swap 用量与 `journalctl -k | grep -i oom`。

## 变更与验收流程

1. 先停止 Hydra 派发：

   ```bash
   systemctl stop hydra-queue-runner.service
   ```

2. 修改目标主机的 `nixBuilder.maxJobs`；若该机也会本地构建，同时修改
   `nix.settings.max-jobs` 和 `nix.settings.cores`。
3. 先部署所有派发端（当前为 `ml-builder`），再读取运行态文件：

   ```bash
   grep -E 'ml-builder|pve-5700u|opi5p' /etc/nix/machines
   grep -E 'ml-builder|pve-5700u|opi5p|localhost' /etc/nix/machines-with-localhost
   ```

   ml-builder 的两条命令都必须看不到 `pve-5700u`；`machines-with-localhost` 应同时
   看到 `opi5p` 与 `localhost`。PVE 上不应再存在 `/etc/nix/machines*` 构建派发表。
   这一条只适用于普通 `nix build`；Hydra 的队列改看 gRPC 构建机：

   ```bash
   # opi5p（队列器 + 本机构建机）
   systemctl status hydra-queue-runner.service hydra-builder.service
   # ml-builder（远程构建机）
   systemctl status hydra-builder.service
   journalctl -u hydra-builder.service -n 30
   ```

   队列器日志与 Hydra Web UI 的 Machines 页应同时列出 opi5p 与 ml-builder。

4. 用一个受控构建验证 OPI5P；期间检查：

   ```bash
   free -h
   cat /proc/loadavg
   journalctl -k -b --no-pager | grep -E 'Out of memory|Killed process'
   ```

   OPI5P 的可用内存低于 2 GiB、OOM 计数增加或出现多个并行编译 derivation 时立即停止
   派发并回滚配置。
5. 验证无误后恢复 `hydra-queue-runner`，再次确认实际机器表未回到高并发。

ml-builder 与 OPI5P 的配置内还有 assertion：声明并发与本地并发必须同时保持为 1。
因此将来上游合并若只改动其中一个值，求值会直接失败，而不是静默把生产节点重新变成
高并发 builder。
